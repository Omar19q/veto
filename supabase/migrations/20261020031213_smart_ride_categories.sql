begin;
-- FIRST INSTALL ONLY. Not for rerunning on the current Staging schema.
-- Creates DISABLED categories and NO price rows. Production activation needs approval.
do $$ begin
 if to_regclass('public.ride_categories_v3') is not null then raise exception 'V3 objects already exist; inspect deployed state before applying SQL'; end if;
 if to_regprocedure('public.create_trip_from_quote_v4(uuid,jsonb,text,numeric)') is null
 or to_regprocedure('public.create_trip_growth_v2(uuid,jsonb,text,numeric)') is null
 or to_regprocedure('public.v25_session_is_current()') is null then raise exception 'Compatible V4/Growth/V25 baseline required'; end if;
end $$;
-- Source step: categories.sql
-- VETO 3 additive category layer. Deploy Staging first. No Production prices seeded.

create schema if not exists veto_category_private;
revoke all on schema veto_category_private from public,anon,authenticated;
create table public.ride_categories_v3 (
 id text primary key check(id ~ '^veto_[a-z_]+$'), base_service public.service_type not null,
 name_ar text not null, name_en text not null, description_ar text not null default '', description_en text not null default '',
 enabled boolean not null default false, sort_order integer not null default 0,
 asset text not null, accent text not null check(accent ~ '^#[0-9A-Fa-f]{6}$'),
 tier integer not null default 0 check(tier between 0 and 3), inherit_lower boolean not null default true,
 safety_required boolean not null default false, updated_at timestamptz not null default now()
);
create table public.ride_category_prices_v3 (
 id uuid primary key default gen_random_uuid(), category_id text not null references public.ride_categories_v3,
 zone_id uuid references public.pricing_zones, opening numeric(10,2) not null check(opening>=0),
 per_km numeric(10,2) not null check(per_km>0), minimum numeric(10,2) not null check(minimum>=0),
 waiting numeric(10,2) not null check(waiting>=0), free_wait integer not null default 4 check(free_wait between 0 and 60),
 enabled boolean not null default true, updated_at timestamptz not null default now(), unique nulls not distinct(category_id,zone_id)
);
create table public.captain_category_approvals_v3 (
 captain_id uuid primary key references public.captains, highest_tier integer not null default 0 check(highest_tier between 0 and 3),
 female_verified boolean not null default false, ladies_approved boolean not null default false,
 documents_approved boolean not null default false, insurance_approved boolean not null default false,
 child_seat_approved boolean not null default false,
 allowed text[] not null default '{}', blocked text[] not null default '{}',
 reason text not null check(length(trim(reason)) between 3 and 1000), updated_at timestamptz not null default now()
);
create table public.trip_promise_options_v3 (
 id text primary key, name_ar text not null,name_en text not null, enabled boolean not null default true,
 equipment_required boolean not null default false, sort_order integer not null default 0
);
create table public.category_audit_v3 (
 id bigint generated always as identity primary key, actor uuid, entity text not null,
 old_value jsonb,new_value jsonb,created_at timestamptz not null default now()
);
create table veto_category_private.trip_codes (
 trip_id uuid primary key references public.trips, pin text not null check(pin ~ '^[0-9]{6}$'),
 failed integer not null default 0, expires_at timestamptz not null,verified_at timestamptz,verified_captain uuid
);
alter table veto_category_private.trip_codes enable row level security;
alter table public.trips add column ride_category_id_v3 text references public.ride_categories_v3;
alter table public.trips add column trip_promises_v3 text[] not null default '{}';
create index on public.trips(ride_category_id_v3) where ride_category_id_v3 is not null;
insert into public.ride_categories_v3(id,base_service,name_ar,name_en,description_ar,description_en,sort_order,asset,accent,tier,safety_required) values
 ('veto_economy','car_ride','فيتو اقتصادي','VETO Economy','مشوارك اليومي بسعر مناسب','Your everyday ride',1,'veto_economy.webp','#FFC247',1,true),
 ('veto_comfort','car_ride','فيتو راحة','VETO Comfort','عربيات أحدث وراحة أكتر','More room, more comfort',2,'veto_comfort.webp','#7BAED6',2,true),
 ('veto_premium','car_ride','فيتو بريميوم','VETO Premium','مشوار أرقى وعربيات مميزة','An elevated ride',3,'veto_premium.webp','#D7B878',3,true),
 ('veto_ladies','car_ride','فيتو سيدات','VETO Ladies','مشوارك مع سائقة معتمدة','Ride with an approved woman driver',4,'veto_ladies.webp','#9A86B8',0,true),
 ('veto_moto','motorcycle_ride','فيتو موتو','VETO Moto','أسرع وسط الزحمة','Move through the city',5,'veto_moto.webp','#39A99B',0,false),
 ('veto_parcel','package','فيتو توصيل','VETO Parcel','ابعت طردك بسهولة','Send your parcel',6,'veto_parcel.webp','#E99B55',0,false),
 ('veto_market','vito_market','فيتو ماركت','VETO Market','اطلب احتياجاتك بسهولة','Shop your essentials',7,'veto_market.webp','#AA83CC',0,false);
insert into public.trip_promise_options_v3 values
 ('quiet','مشوار هادي','Quiet ride',true,false,1),('no_music','بدون أغاني','No music',true,false,2),
 ('ac','تكييف','Air conditioning',true,false,3),('child','معايا طفل','Accompanying a child',true,false,4),
 ('baggage','محتاج مساعدة في الشنط','Help with baggage',true,false,5),('child_seat','كرسي أطفال عند التأكيد','Child seat upon confirmation',false,true,6);
create function veto_category_private.audit() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 insert into public.category_audit_v3(actor,entity,old_value,new_value) values(auth.uid(),TG_TABLE_NAME,case when TG_OP<>'INSERT' then to_jsonb(OLD) end,case when TG_OP<>'DELETE' then to_jsonb(NEW) end);
 return case when TG_OP='DELETE' then OLD else NEW end;
end $$;
create function veto_category_private.can_serve(p_captain uuid,p_category text,p_promises text[] default '{}') returns boolean
language sql stable security definer set search_path=pg_catalog as $$
 select exists(select 1 from public.captains c join public.captain_category_approvals_v3 a on a.captain_id=c.id
 join public.ride_categories_v3 r on r.id=p_category
 where c.id=p_captain and c.captain_status::text='active' and c.identity_verified_v10 and c.vehicle_verified_v10
 and a.documents_approved and a.insurance_approved and (c.banned_until is null or c.banned_until<=now())
 and not (p_category=any(a.blocked)) and (not ('child_seat'=any(p_promises)) or a.child_seat_approved)
 and case r.base_service::text when 'car_ride' then c.can_do_car_ride and c.vehicle_type::text='car'
 when 'motorcycle_ride' then c.can_do_motorcycle_ride and c.vehicle_type::text='motorcycle'
 when 'package' then c.can_do_package when 'vito_market' then c.can_do_vito_market else false end
 and case when p_category='veto_ladies' then a.female_verified and a.ladies_approved
 when r.tier>0 then (a.highest_tier>=r.tier and (r.inherit_lower or a.highest_tier=r.tier)) or p_category=any(a.allowed)
 else p_category=any(a.allowed) end)
$$;
create function veto_category_private.guard_trip() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare q public.route_pricing_quotes; cat public.ride_categories_v3; requested text; opts text[];
begin
 if TG_OP='INSERT' then
  select * into q from public.route_pricing_quotes where id=nullif(current_setting('veto.zone_quote',true),'')::uuid;
  requested:=q.pricing_snapshot->>'ride_category_id_v3';
  if requested is not null then
   select * into cat from public.ride_categories_v3 where id=requested for share;
   if not found or not cat.enabled or cat.base_service<>NEW.service_type then raise exception 'category_unavailable'; end if;
   if requested='veto_ladies' and q.pricing_snapshot->>'ladies_terms_accepted_v3' is distinct from 'true' then raise exception 'ladies_terms_required'; end if;
   NEW.ride_category_id_v3:=requested;
   select coalesce(array_agg(v),'{}') into opts from jsonb_array_elements_text(coalesce(q.pricing_snapshot->'trip_promises_v3','[]')) v;
   NEW.trip_promises_v3:=opts;
  elsif NEW.ride_category_id_v3 is not null then raise exception 'category_quote_required'; end if;
 elsif NEW.ride_category_id_v3 is distinct from OLD.ride_category_id_v3 or NEW.trip_promises_v3 is distinct from OLD.trip_promises_v3 then
  raise exception 'category_snapshot_immutable';
 end if;
 if NEW.ride_category_id_v3 is not null and NEW.captain_id is not null and (TG_OP='INSERT' or NEW.captain_id is distinct from OLD.captain_id) then
  perform 1 from public.captain_category_approvals_v3 where captain_id=NEW.captain_id for share;
  if not veto_category_private.can_serve(NEW.captain_id,NEW.ride_category_id_v3,NEW.trip_promises_v3) then raise exception 'category_not_authorized'; end if;
 end if;
 if TG_OP='UPDATE' and NEW.ride_category_id_v3 is not null and NEW.trip_status::text='started' and OLD.trip_status::text<>'started'
 and coalesce((OLD.pricing_snapshot->'category_config_v3'->>'safety_required')::boolean,false)
 and not exists(select 1 from veto_category_private.trip_codes where trip_id=NEW.id and verified_at is not null and verified_captain=NEW.captain_id) then
  raise exception 'trip_safety_code_required';
 end if;
 return NEW;
end $$;
create trigger a_veto3_category_guard before insert or update on public.trips for each row execute function veto_category_private.guard_trip();
create function veto_category_private.guard_offer() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare t public.trips;
begin
 select * into t from public.trips where id=NEW.trip_id;
 if t.ride_category_id_v3 is not null and not veto_category_private.can_serve(NEW.captain_id,t.ride_category_id_v3,t.trip_promises_v3) then
  if TG_OP='INSERT' then return null; end if;
  if NEW.offer_status::text='accepted_by_customer' then raise exception 'category_not_authorized'; end if;
 end if;
 return NEW;
end $$;
create trigger a_veto3_offer_guard before insert or update of offer_status on public.trip_offers for each row execute function veto_category_private.guard_offer();
create function veto_category_private.issue_code() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if NEW.ride_category_id_v3 is not null and NEW.trip_status::text='accepted' and OLD.trip_status::text<>'accepted'
 and coalesce((NEW.pricing_snapshot->'category_config_v3'->>'safety_required')::boolean,false) then
  insert into veto_category_private.trip_codes(trip_id,pin,expires_at) values(NEW.id,
   lpad((('x'||encode(extensions.gen_random_bytes(4),'hex'))::bit(32)::bigint % 1000000)::text,6,'0'),now()+interval '24 hours') on conflict do nothing;
 end if;
 return NEW;
end $$;
create trigger veto3_issue_safety_code after update of trip_status on public.trips for each row execute function veto_category_private.issue_code();
create function public.v3_customer_trip_code(p_trip uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.trips t join public.customers c on c.id=t.customer_id where t.id=p_trip and c.user_id=auth.uid()) then raise exception 'not_authorized' using errcode='42501'; end if;
 select jsonb_build_object('pin',case when p.verified_at is null then p.pin end,'verified',p.verified_at is not null,'locked',p.failed>=5,'expires_at',p.expires_at)
 into result from veto_category_private.trip_codes p join public.trips t on t.id=p.trip_id where p.trip_id=p_trip and t.trip_status::text in ('accepted','arriving','arrived','started') and p.expires_at>now();
 return coalesce(result,'{}'::jsonb);
end $$;
create function public.v3_verify_trip_code(p_trip uuid,p_code text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare t public.trips; c veto_category_private.trip_codes;
begin
 select * into t from public.trips where id=p_trip for update;
 if auth.uid() is null or not exists(select 1 from public.captains where id=t.captain_id and user_id=auth.uid()) then raise exception 'not_authorized' using errcode='42501'; end if;
 select * into c from veto_category_private.trip_codes where trip_id=t.id for update;
 if not found or t.trip_status::text<>'arrived' or c.expires_at<=now() or c.failed>=5 then return jsonb_build_object('success',false,'error','code_unavailable'); end if;
 if c.verified_at is not null then return jsonb_build_object('success',true); end if;
 if p_code is null or p_code !~ '^[0-9]{6}$' or p_code<>c.pin then
  update veto_category_private.trip_codes set failed=failed+1 where trip_id=t.id;
  return jsonb_build_object('success',false,'error','invalid_code','attempts_left',4-c.failed);
 end if;
 update veto_category_private.trip_codes set verified_at=now(),verified_captain=t.captain_id where trip_id=t.id;
 return jsonb_build_object('success',true);
end $$;
create function public.v3_category_catalog() returns jsonb language sql stable security definer set search_path=pg_catalog as $$
 select jsonb_build_object('categories',coalesce((select jsonb_agg(to_jsonb(r) order by sort_order) from public.ride_categories_v3 r),'[]'::jsonb),
 'promises',coalesce((select jsonb_agg(to_jsonb(p) order by sort_order) from public.trip_promise_options_v3 p where enabled),'[]'::jsonb)) where auth.uid() is not null
$$;
create function public.v3_my_categories() returns jsonb language sql stable security definer set search_path=pg_catalog as $$
 select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('authorized',veto_category_private.can_serve(c.id,r.id),'reason',case when a.captain_id is null then 'pending_review' else 'reviewed' end) order by r.sort_order),'[]'::jsonb)
 from public.captains c cross join public.ride_categories_v3 r left join public.captain_category_approvals_v3 a on a.captain_id=c.id where c.user_id=auth.uid()
$$;
create function public.v3_issue_category_quote(p_user uuid,p_category text,p_service text,p_from_lat numeric,p_from_lng numeric,p_to_lat numeric,p_to_lng numeric,p_km numeric,p_minutes integer) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r public.ride_categories_v3; price public.ride_category_prices_v3; q public.route_pricing_quotes; legacy jsonb; amount numeric;
begin
 if coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb->>'role' is distinct from 'service_role'
 and current_setting('request.jwt.claim.role',true) is distinct from 'service_role' and session_user not in ('postgres','supabase_admin') then raise exception 'server_only' using errcode='42501'; end if;
 select * into r from public.ride_categories_v3 where id=p_category and enabled and base_service::text=p_service and id<>'veto_market' for share;
 if not found then raise exception 'category_unavailable'; end if;
 legacy:=public.issue_route_pricing_quote(p_user,p_service,p_from_lat,p_from_lng,p_to_lat,p_to_lng,p_km,p_minutes);
 select * into q from public.route_pricing_quotes where id=(legacy->>'id')::uuid for update;
 select * into price from public.ride_category_prices_v3 where category_id=r.id and enabled and (zone_id=q.zone_id or zone_id is null) order by zone_id nulls last limit 1 for share;
 if not found then raise exception 'category_price_unavailable'; end if;
 amount:=round(greatest(price.minimum,price.opening+price.per_km*q.distance_km)*least(q.multiplier,1.30),2);
 update public.route_pricing_quotes set base_fare=amount,waiting_rate=round(price.waiting*least(q.multiplier,1.30),2),free_wait_minutes=price.free_wait,
 multiplier=least(q.multiplier,1.30),pricing_snapshot=q.pricing_snapshot||jsonb_build_object('ride_category_id_v3',r.id,'category_config_v3',to_jsonb(r),'category_price_v3',to_jsonb(price),
 'zone_opening_fee',price.opening,'zone_per_km',price.per_km,'surge_multiplier',least(q.multiplier,1.30)) where id=q.id returning * into q;
 return to_jsonb(q)-'customer_id'-'used_trip_id';
end $$;
create function public.v3_book_category(p_quote_id uuid,p_payload jsonb,p_extra_requests text default null,p_extra_expected_amount numeric default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare q public.route_pricing_quotes; opts text[]; v text; result jsonb;
begin
 select * into q from public.route_pricing_quotes where id=p_quote_id for update;
 if auth.uid() is null or not found or not exists(select 1 from public.customers where id=q.customer_id and user_id=auth.uid() and is_active) then raise exception 'quote_not_owned' using errcode='42501'; end if;
 if q.used_trip_id is not null then return jsonb_build_object('success',true,'replayed',true,'trip',(select to_jsonb(t) from public.trips t where id=q.used_trip_id)); end if;
 if q.pricing_snapshot->>'ride_category_id_v3' is null then raise exception 'category_quote_required'; end if;
 if jsonb_typeof(coalesce(p_payload->'trip_promises_v3','[]'))<>'array' or jsonb_array_length(coalesce(p_payload->'trip_promises_v3','[]'))>6 then raise exception 'invalid_preferences'; end if;
 select coalesce(array_agg(distinct x),'{}') into opts from jsonb_array_elements_text(coalesce(p_payload->'trip_promises_v3','[]')) x;
 foreach v in array opts loop if not exists(select 1 from public.trip_promise_options_v3 where id=v and enabled) then raise exception 'preference_unavailable'; end if; end loop;
 if q.pricing_snapshot->>'ride_category_id_v3'='veto_ladies' and p_payload->>'ladies_terms_accepted' is distinct from 'true' then raise exception 'ladies_terms_required'; end if;
 update public.route_pricing_quotes set pricing_snapshot=pricing_snapshot||jsonb_build_object('trip_promises_v3',to_jsonb(opts),'ladies_terms_accepted_v3',coalesce((p_payload->>'ladies_terms_accepted')::boolean,false)) where id=q.id;
 if coalesce((p_payload->>'skip_growth_v3')::boolean,false) then result:=public.create_trip_from_quote_v4(p_quote_id,p_payload,p_extra_requests,p_extra_expected_amount);
 else result:=public.create_trip_growth_v2(p_quote_id,p_payload,p_extra_requests,p_extra_expected_amount); end if;
 return result;
end $$;
create function public.v3_admin_category_data() returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
begin
 if auth.uid() is null or not public.is_admin_safe() then raise exception 'admin_required' using errcode='42501'; end if;
 return public.v3_category_catalog()||jsonb_build_object('promises',(select coalesce(jsonb_agg(to_jsonb(p) order by sort_order),'[]') from public.trip_promise_options_v3 p),'prices',(select coalesce(jsonb_agg(to_jsonb(p)),'[]') from public.ride_category_prices_v3 p),
 'approvals',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from public.captain_category_approvals_v3 a),
 'captains',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.full_name,'vehicle',c.vehicle_type,'identity_verified',c.identity_verified_v10,'vehicle_verified',c.vehicle_verified_v10)),'[]') from public.captains c),
 'audit',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from (select * from public.category_audit_v3 order by id desc limit 100) a));
end $$;
create function public.v3_admin_save(p_entity text,p_value jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r public.ride_categories_v3; price public.ride_category_prices_v3; a public.captain_category_approvals_v3; v text;
begin
 if auth.uid() is null or not public.is_admin_safe() then raise exception 'admin_required' using errcode='42501'; end if;
 if p_entity='category' then
  select * into r from jsonb_populate_record(null::public.ride_categories_v3,p_value);
  if r.id not in ('veto_economy','veto_comfort','veto_premium','veto_ladies','veto_moto','veto_parcel','veto_market') or length(trim(r.name_ar))<2 or length(trim(r.name_en))<2 or r.asset<>r.id||'.webp' then raise exception 'invalid_category'; end if;
  update public.ride_categories_v3 set name_ar=r.name_ar,name_en=r.name_en,description_ar=r.description_ar,description_en=r.description_en,enabled=r.enabled,sort_order=r.sort_order,accent=r.accent,inherit_lower=r.inherit_lower,updated_at=now() where id=r.id;
 elsif p_entity='price' then
  select * into price from jsonb_populate_record(null::public.ride_category_prices_v3,p_value);
  if price.category_id='veto_market' then raise exception 'market_pricing_separate'; end if;
  insert into public.ride_category_prices_v3(category_id,zone_id,opening,per_km,minimum,waiting,free_wait,enabled) values(price.category_id,price.zone_id,price.opening,price.per_km,price.minimum,price.waiting,price.free_wait,price.enabled)
  on conflict(category_id,zone_id) do update set opening=excluded.opening,per_km=excluded.per_km,minimum=excluded.minimum,waiting=excluded.waiting,free_wait=excluded.free_wait,enabled=excluded.enabled,updated_at=now();
 elsif p_entity='approval' then
  select * into a from jsonb_populate_record(null::public.captain_category_approvals_v3,p_value);
  foreach v in array (coalesce(a.allowed,'{}')||coalesce(a.blocked,'{}')) loop if not exists(select 1 from public.ride_categories_v3 where id=v) then raise exception 'invalid_category'; end if; end loop;
  if a.ladies_approved and not (a.female_verified and a.documents_approved and a.insurance_approved) then raise exception 'ladies_verification_required'; end if;
  perform 1 from public.captains where id=a.captain_id for update;
  insert into public.captain_category_approvals_v3 values(a.captain_id,a.highest_tier,a.female_verified,a.ladies_approved,a.documents_approved,a.insurance_approved,a.child_seat_approved,coalesce(a.allowed,'{}'),coalesce(a.blocked,'{}'),a.reason,now())
  on conflict(captain_id) do update set highest_tier=excluded.highest_tier,female_verified=excluded.female_verified,ladies_approved=excluded.ladies_approved,documents_approved=excluded.documents_approved,insurance_approved=excluded.insurance_approved,child_seat_approved=excluded.child_seat_approved,allowed=excluded.allowed,blocked=excluded.blocked,reason=excluded.reason,updated_at=now();
 elsif p_entity='promise' then
  update public.trip_promise_options_v3 set enabled=(p_value->>'enabled')::boolean where id=p_value->>'id';
 else raise exception 'invalid_entity'; end if;
 return jsonb_build_object('success',true);
end $$;
do $$ declare t text; begin
 foreach t in array array['ride_categories_v3','ride_category_prices_v3','captain_category_approvals_v3','trip_promise_options_v3','category_audit_v3'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  if t<>'category_audit_v3' then execute format('create trigger veto3_audit after insert or update or delete on public.%I for each row execute function veto_category_private.audit()',t); end if;
 end loop;
end $$;
revoke all on all functions in schema veto_category_private from public,anon,authenticated;
revoke all on function public.v3_issue_category_quote(uuid,text,text,numeric,numeric,numeric,numeric,numeric,integer) from public,anon,authenticated;
grant execute on function public.v3_issue_category_quote(uuid,text,text,numeric,numeric,numeric,numeric,numeric,integer) to service_role;
do $$ declare r record; begin for r in select oid::regprocedure sig from pg_proc where pronamespace='public'::regnamespace and proname in ('v3_customer_trip_code','v3_verify_trip_code','v3_category_catalog','v3_my_categories','v3_book_category','v3_admin_category_data','v3_admin_save') loop
 execute format('revoke all on function %s from public,anon',r.sig);execute format('grant execute on function %s to authenticated',r.sig);end loop;end $$;

-- Source step: harden.sql

alter table public.ride_category_prices_v3 add constraint v3_finite_prices check(opening::text not in ('NaN','Infinity','-Infinity') and per_km::text not in ('NaN','Infinity','-Infinity') and minimum::text not in ('NaN','Infinity','-Infinity') and waiting::text not in ('NaN','Infinity','-Infinity'));
alter table public.ride_categories_v3 add constraint v3_category_copy_length check(length(name_ar) between 2 and 100 and length(name_en) between 2 and 100 and length(description_ar)<=500 and length(description_en)<=500 and sort_order between 0 and 1000);
create or replace function veto_category_private.guard_trip() returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare q public.route_pricing_quotes; cat public.ride_categories_v3; requested text; opts text[];
begin
 if TG_OP='INSERT' then
  select * into q from public.route_pricing_quotes where id=nullif(current_setting('veto.zone_quote',true),'')::uuid;
  requested:=q.pricing_snapshot->>'ride_category_id_v3';
  if requested is not null then
   select * into cat from public.ride_categories_v3 where id=requested for share;
   if not found or not cat.enabled or cat.base_service<>NEW.service_type then raise exception 'category_unavailable'; end if;
   if requested='veto_ladies' and q.pricing_snapshot->>'ladies_terms_accepted_v3' is distinct from 'true' then raise exception 'ladies_terms_required'; end if;
   NEW.ride_category_id_v3:=requested;
   select coalesce(array_agg(v),'{}') into opts from jsonb_array_elements_text(coalesce(q.pricing_snapshot->'trip_promises_v3','[]')) v;
   NEW.trip_promises_v3:=opts;
  elsif NEW.ride_category_id_v3 is not null then raise exception 'category_quote_required'; end if;
 elsif NEW.ride_category_id_v3 is distinct from OLD.ride_category_id_v3 or NEW.trip_promises_v3 is distinct from OLD.trip_promises_v3 then
  raise exception 'category_snapshot_immutable';
 end if;
 if NEW.ride_category_id_v3 is not null and NEW.captain_id is not null and (TG_OP='INSERT' or NEW.captain_id is distinct from OLD.captain_id) then
  perform 1 from public.captain_category_approvals_v3 where captain_id=NEW.captain_id for share;
  if not veto_category_private.can_serve(NEW.captain_id,NEW.ride_category_id_v3,NEW.trip_promises_v3) then raise exception 'category_not_authorized'; end if;
 end if;
 if TG_OP='UPDATE' and NEW.ride_category_id_v3 is not null and NEW.trip_status::text='started' and OLD.trip_status::text<>'started'
 and coalesce((OLD.pricing_snapshot->'category_config_v3'->>'safety_required')::boolean,false)
 and not exists(select 1 from veto_category_private.trip_codes where trip_id=NEW.id and verified_at is not null and verified_captain=NEW.captain_id) then
  raise exception 'trip_safety_code_required';
 end if;
 return NEW;
end $$;
create or replace function public.v3_book_category(p_quote_id uuid,p_payload jsonb,p_extra_requests text default null,p_extra_expected_amount numeric default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare q public.route_pricing_quotes; opts text[]; v text; result jsonb;
begin
 select * into q from public.route_pricing_quotes where id=p_quote_id for update;
 if auth.uid() is null or not found or not exists(select 1 from public.customers where id=q.customer_id and user_id=auth.uid() and is_active) then raise exception 'quote_not_owned' using errcode='42501'; end if;
 if q.used_trip_id is not null then return jsonb_build_object('success',true,'replayed',true,'trip',(select to_jsonb(t) from public.trips t where id=q.used_trip_id)); end if;
 if q.pricing_snapshot->>'ride_category_id_v3' is null then raise exception 'category_quote_required'; end if;
 if jsonb_typeof(coalesce(p_payload->'trip_promises_v3','[]'))<>'array' or jsonb_array_length(coalesce(p_payload->'trip_promises_v3','[]'))>6 then raise exception 'invalid_preferences'; end if;
 select coalesce(array_agg(distinct x),'{}') into opts from jsonb_array_elements_text(coalesce(p_payload->'trip_promises_v3','[]')) x;
 foreach v in array opts loop if not exists(select 1 from public.trip_promise_options_v3 where id=v and enabled) then raise exception 'preference_unavailable'; end if; end loop;
 if q.pricing_snapshot->>'ride_category_id_v3'='veto_ladies' and p_payload->>'ladies_terms_accepted' is distinct from 'true' then raise exception 'ladies_terms_required'; end if;
 update public.route_pricing_quotes set pricing_snapshot=pricing_snapshot||jsonb_build_object('trip_promises_v3',to_jsonb(opts),'ladies_terms_accepted_v3',coalesce((p_payload->>'ladies_terms_accepted')::boolean,false)) where id=q.id;
 if coalesce((p_payload->>'skip_growth_v3')::boolean,false) then result:=public.create_trip_from_quote_v4(p_quote_id,p_payload,p_extra_requests,p_extra_expected_amount);
 else result:=public.create_trip_growth_v2(p_quote_id,p_payload,p_extra_requests,p_extra_expected_amount); end if;
 return result;
end $$;
create or replace function public.v3_admin_category_data() returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
begin
 if auth.uid() is null or not public.is_admin_safe() then raise exception 'admin_required' using errcode='42501'; end if;
 return public.v3_category_catalog()||jsonb_build_object('promises',(select coalesce(jsonb_agg(to_jsonb(p) order by sort_order),'[]') from public.trip_promise_options_v3 p),'prices',(select coalesce(jsonb_agg(to_jsonb(p)),'[]') from public.ride_category_prices_v3 p),
 'approvals',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from public.captain_category_approvals_v3 a),
 'captains',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.full_name,'vehicle',c.vehicle_type,'identity_verified',c.identity_verified_v10,'vehicle_verified',c.vehicle_verified_v10)),'[]') from public.captains c),
 'audit',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from (select * from public.category_audit_v3 order by id desc limit 100) a));
end $$;
CREATE OR REPLACE FUNCTION public.process_dispatch_waves(p_only_trip uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$

DECLARE job_id uuid; t public.trips%ROWTYPE; j public.trip_dispatches%ROWTYPE;

 step integer; radius integer; c record; locked_cap public.captains%ROWTYPE; offer_id uuid; sent integer:=0; count_sent integer; selected_count integer; old_flag text;

BEGIN

 FOR job_id IN SELECT trip_id FROM public.trip_dispatches WHERE status IN('pending','waiting')

  AND (p_only_trip IS NULL OR trip_id=p_only_trip) AND (next_wave_at<=clock_timestamp() OR expires_at<=clock_timestamp())

  ORDER BY next_wave_at LIMIT 100 LOOP

  -- Lock order: trip, dispatch, captain UUID order. Acceptance uses trip first too.

  SELECT * INTO t FROM public.trips WHERE id=job_id FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN CONTINUE; END IF;

  SELECT * INTO j FROM public.trip_dispatches WHERE trip_id=job_id FOR UPDATE;

  IF j.status NOT IN('pending','waiting') THEN CONTINUE; END IF;

  IF t.captain_id IS NOT NULL OR t.trip_status::text NOT IN('requested','offer_received') THEN

   UPDATE public.trip_dispatches SET status='stopped' WHERE trip_id=job_id; CONTINUE;

  END IF;

  IF j.expires_at<=clock_timestamp() THEN

   UPDATE public.trip_dispatches SET status='expired' WHERE trip_id=job_id;

   UPDATE public.trip_offers SET offer_status='expired',responded_at=now() WHERE trip_id=job_id AND offer_status::text='sent'; CONTINUE;

  END IF;

  IF j.status='waiting' OR j.next_wave_at>clock_timestamp() THEN CONTINUE; END IF;

  /* V34_PROGRESSIVE_DISPATCH */

  step:=CASE WHEN clock_timestamp()>=j.started_at+interval '40 seconds' THEN 3

    WHEN clock_timestamp()>=j.started_at+interval '20 seconds' THEN 2 ELSE 1 END;

  radius:=CASE WHEN clock_timestamp()>=j.started_at+interval '60 seconds' THEN 10000

    WHEN clock_timestamp()>=j.started_at+interval '50 seconds' THEN 8000

    WHEN clock_timestamp()>=j.started_at+interval '40 seconds' THEN 6000

    WHEN clock_timestamp()>=j.started_at+interval '30 seconds' THEN 4000

    WHEN clock_timestamp()>=j.started_at+interval '20 seconds' THEN 2500

    ELSE 1000 END;

  old_flag:=coalesce(current_setting('veto.wave_dispatch',true),'');

  PERFORM set_config('veto.wave_dispatch',job_id::text,true);

  count_sent:=0; selected_count:=0;

  FOR c IN SELECT * FROM (

   SELECT cap.id,cap.user_id,extensions.ST_Distance(

    extensions.ST_SetSRID(extensions.ST_MakePoint(cap.current_longitude::double precision,cap.current_latitude::double precision),4326)::extensions.geography,

    extensions.ST_SetSRID(extensions.ST_MakePoint(t.pickup_longitude::double precision,t.pickup_latitude::double precision),4326)::extensions.geography) AS meters

   FROM public.captains cap WHERE cap.captain_status::text='active' AND cap.is_online AND cap.is_available

    AND (coalesce(cap.debt_threshold,0)<=0 OR cap.settlement_debt>-abs(cap.debt_threshold)) AND (cap.banned_until IS NULL OR cap.banned_until<=now())

    AND cap.location_updated_at>now()-interval '2 minutes' AND cap.location_updated_at<=now()+interval '5 seconds'

    AND cap.current_latitude IS NOT NULL AND cap.current_longitude IS NOT NULL

    AND ((t.service_type::text='car_ride' AND cap.can_do_car_ride AND cap.vehicle_type::text='car')

      OR (t.service_type::text='motorcycle_ride' AND cap.can_do_motorcycle_ride AND cap.vehicle_type::text='motorcycle')

      OR (t.service_type::text='package' AND cap.can_do_package) OR (t.service_type::text='vito_market' AND cap.can_do_vito_market))

    AND (t.ride_category_id_v3 IS NULL OR veto_category_private.can_serve(cap.id,t.ride_category_id_v3,t.trip_promises_v3))
    AND NOT EXISTS(SELECT 1 FROM public.trips busy WHERE busy.captain_id=cap.id AND busy.trip_status::text IN('accepted','arriving','arrived','started'))

    AND NOT EXISTS(SELECT 1 FROM public.market_orders busy WHERE busy.captain_id=cap.id AND busy.order_status::text IN('captain_assigned','picked_up','on_the_way'))

    AND NOT EXISTS(SELECT 1 FROM public.captain_customer_blocks_v34 b WHERE b.captain_id=cap.id AND b.customer_id=t.customer_id)
    AND NOT EXISTS(SELECT 1 FROM public.trip_wave_recipients r WHERE r.trip_id=job_id AND r.captain_id=cap.id)

    AND extensions.ST_DWithin(

     extensions.ST_SetSRID(extensions.ST_MakePoint(cap.current_longitude::double precision,cap.current_latitude::double precision),4326)::extensions.geography,

     extensions.ST_SetSRID(extensions.ST_MakePoint(t.pickup_longitude::double precision,t.pickup_latitude::double precision),4326)::extensions.geography,radius)

   ORDER BY meters,cap.id LIMIT 200) candidates ORDER BY id LOOP

   selected_count:=selected_count+1;

   -- Ban/assignment can change after selection. A stale candidate must not abort the entire wave.

   BEGIN

    SELECT * INTO locked_cap FROM public.captains WHERE id=c.id FOR UPDATE;

    IF NOT FOUND OR NOT locked_cap.is_online OR NOT locked_cap.is_available OR locked_cap.captain_status::text<>'active'

     OR locked_cap.banned_until>now() OR (coalesce(locked_cap.debt_threshold,0)>0 AND locked_cap.settlement_debt<=-abs(locked_cap.debt_threshold))

     OR EXISTS(SELECT 1 FROM public.trips WHERE captain_id=c.id AND trip_status::text IN('accepted','arriving','arrived','started'))

     OR EXISTS(SELECT 1 FROM public.market_captain_assignments WHERE captain_id=c.id AND status IN('pending','accepted')) THEN CONTINUE; END IF;

    INSERT INTO public.trip_wave_recipients(trip_id,captain_id,wave,radius_m) VALUES(job_id,c.id,step,radius)

      ON CONFLICT DO NOTHING;

    IF NOT FOUND THEN CONTINUE; END IF;

    INSERT INTO public.trip_offers(trip_id,captain_id,offer_status,captain_distance_km,eta_minutes)

      VALUES(job_id,c.id,'sent',round(c.meters::numeric/1000,3),greatest(1,ceil(c.meters/400)::integer)) RETURNING id INTO offer_id;

    INSERT INTO public.notifications(user_id,notification_type,title,body,data)

      VALUES(c.user_id,'offer','طلب قريب منك',CASE WHEN nullif(trim(t.extra_requests),'') IS NOT NULL THEN 'رحلة هاتلي معاك — راجع الطلبات قبل القبول' ELSE 'رحلة جديدة داخل نطاقك' END,

        jsonb_build_object('trip_id',job_id,'offer_id',offer_id,'wave',step));

    count_sent:=count_sent+1;

   EXCEPTION WHEN SQLSTATE '42501' THEN

    -- The candidate may have been banned concurrently; its receipt and offer roll back together.

    NULL;

   END;

  END LOOP;

  PERFORM set_config('veto.wave_dispatch',old_flag,true);

  UPDATE public.trip_dispatches SET wave=step,status='pending',

    next_wave_at=CASE WHEN selected_count>=200 THEN least(clock_timestamp()+interval '1 second',j.expires_at)

      WHEN clock_timestamp()>=j.started_at+interval '60 seconds' THEN least(clock_timestamp()+interval '10 seconds',j.expires_at)

      WHEN clock_timestamp()>=j.started_at+interval '50 seconds' THEN j.started_at+interval '60 seconds'

      WHEN clock_timestamp()>=j.started_at+interval '40 seconds' THEN j.started_at+interval '50 seconds'

      WHEN clock_timestamp()>=j.started_at+interval '30 seconds' THEN j.started_at+interval '40 seconds'

      WHEN clock_timestamp()>=j.started_at+interval '20 seconds' THEN j.started_at+interval '30 seconds'

      ELSE j.started_at+interval '20 seconds' END
    WHERE trip_id=job_id;

  IF count_sent>0 AND t.trip_status::text='requested' THEN UPDATE public.trips SET trip_status='offer_received' WHERE id=job_id; END IF;

  sent:=sent+count_sent;

 END LOOP;

 RETURN sent;

END;

$function$;

-- The same ownership/atomic booking guard applies even if an old RPC is called.
CREATE OR REPLACE FUNCTION public.get_captain_pending_offers_v4(p_captain_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$

BEGIN

 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.captains WHERE id=p_captain_id AND user_id=auth.uid()) THEN RAISE EXCEPTION 'captain_required' USING ERRCODE='42501'; END IF;

 RETURN (SELECT coalesce(jsonb_agg(to_jsonb(o)||jsonb_build_object('trips',jsonb_build_object(

  'id',t.id,'service_type',t.service_type,'pickup_address',t.pickup_address,'destination_address',t.destination_address,

  'distance_km',t.distance_km,'customer_note',t.customer_note,'incentive_amount',t.incentive_amount,

  'extra_requests',t.extra_requests,'extra_expected_amount',t.extra_expected_amount,

  'base_fare',t.base_fare,'total_fare',t.total_fare,'ride_category_id_v3',t.ride_category_id_v3,'category_config_v3',t.pricing_snapshot->'category_config_v3','trip_promises_v3',t.trip_promises_v3)) ORDER BY o.created_at DESC),'[]')

 FROM public.trip_offers o JOIN public.trips t ON t.id=o.trip_id

 WHERE (t.ride_category_id_v3 is null or veto_category_private.can_serve(p_captain_id,t.ride_category_id_v3,t.trip_promises_v3)) AND o.captain_id=p_captain_id AND o.offer_status::text='sent' AND t.captain_id IS NULL

  AND t.trip_status::text IN('requested','offer_received') AND (t.zone_pricing_version=4 OR o.created_at>now()-interval '10 minutes')

  AND (t.zone_pricing_version IS DISTINCT FROM 4 OR EXISTS(SELECT 1 FROM public.trip_dispatches d WHERE d.trip_id=t.id AND d.status IN('pending','waiting') AND d.expires_at>clock_timestamp())));

END;

$function$;

-- Source step: availability.sql

create function veto_category_private.available(p_category text,p_lat numeric,p_lng numeric,p_child_seat boolean default false) returns boolean language sql stable security definer set search_path=pg_catalog as $$
 select exists(select 1 from public.captains c where c.is_online and c.is_available
 and c.location_updated_at>now()-interval '2 minutes' and c.location_updated_at<=now()+interval '5 seconds'
 and (coalesce(c.debt_threshold,0)<=0 or c.settlement_debt>-abs(c.debt_threshold))
 and veto_category_private.can_serve(c.id,p_category,case when p_child_seat then array['child_seat'] else '{}'::text[] end)
 and not exists(select 1 from public.trips t where t.captain_id=c.id and t.trip_status::text in ('accepted','arriving','arrived','started'))
 and not exists(select 1 from public.market_captain_assignments m where m.captain_id=c.id and m.status in ('pending','accepted'))
 and extensions.ST_DWithin(extensions.ST_SetSRID(extensions.ST_MakePoint(c.current_longitude::double precision,c.current_latitude::double precision),4326)::extensions.geography,
 extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng::double precision,p_lat::double precision),4326)::extensions.geography,10000))
$$;
revoke all on function veto_category_private.available(text,numeric,numeric,boolean) from public,anon,authenticated;

create or replace function public.v3_category_estimates(p_quote uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare q public.route_pricing_quotes;
begin
 select * into q from public.route_pricing_quotes where id=p_quote;
 if auth.uid() is null or not found or not exists(select 1 from public.customers where id=q.customer_id and user_id=auth.uid() and is_active) then raise exception 'quote_not_owned' using errcode='42501'; end if;
 if q.expires_at<=now() then raise exception 'quote_expired'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'available',veto_category_private.available(r.id,q.pickup_lat,q.pickup_lng),'child_seat_available',veto_category_private.available(r.id,q.pickup_lat,q.pickup_lng,true),'estimated_fare',round(greatest(p.minimum,p.opening+p.per_km*q.distance_km)*least(q.multiplier,1.30),2)) order by r.sort_order),'[]')
 from public.ride_categories_v3 r cross join lateral (select * from public.ride_category_prices_v3 p where p.category_id=r.id and p.enabled and (p.zone_id=q.zone_id or p.zone_id is null) order by p.zone_id nulls last limit 1) p where r.enabled and r.id<>'veto_market');
end $$;
revoke all on function public.v3_category_estimates(uuid) from public,anon;
grant execute on function public.v3_category_estimates(uuid) to authenticated;



-- Source step: promises.sql

create table veto_category_private.promise_confirmations(trip_id uuid primary key references public.trips,captain_id uuid not null references public.captains,confirmed text[] not null,updated_at timestamptz not null default now());
alter table veto_category_private.promise_confirmations enable row level security;
revoke all on veto_category_private.promise_confirmations from public,anon,authenticated;
create function public.v3_trip_promise_status(p_trip uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare t public.trips;
begin
 select * into t from public.trips where id=p_trip;
 if auth.uid() is null or not found or not (exists(select 1 from public.customers where id=t.customer_id and user_id=auth.uid()) or exists(select 1 from public.captains where id=t.captain_id and user_id=auth.uid())) then raise exception 'not_authorized' using errcode='42501'; end if;
 return jsonb_build_object('requested',to_jsonb(t.trip_promises_v3),'confirmed',coalesce((select to_jsonb(c.confirmed) from veto_category_private.promise_confirmations c where c.trip_id=t.id and c.captain_id=t.captain_id),'[]'),'can_confirm',t.trip_status::text in ('accepted','arriving','arrived'));
end $$;
create function public.v3_confirm_trip_promises(p_trip uuid,p_confirmed text[]) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare t public.trips;
begin
 select * into t from public.trips where id=p_trip for update;
 if auth.uid() is null or not found or not public.v25_session_is_current() or not exists(select 1 from public.captains where id=t.captain_id and user_id=auth.uid()) then raise exception 'not_authorized' using errcode='42501'; end if;
 if t.trip_status::text not in ('accepted','arriving','arrived') or p_confirmed is null or not (p_confirmed<@t.trip_promises_v3) then raise exception 'invalid_confirmation'; end if;
 if 'child_seat'=any(p_confirmed) and not veto_category_private.can_serve(t.captain_id,t.ride_category_id_v3,array['child_seat']) then raise exception 'equipment_not_approved'; end if;
 insert into veto_category_private.promise_confirmations values(t.id,t.captain_id,p_confirmed,now()) on conflict(trip_id) do update set captain_id=excluded.captain_id,confirmed=excluded.confirmed,updated_at=now();
 return jsonb_build_object('success',true);
end $$;
revoke all on function public.v3_trip_promise_status(uuid),public.v3_confirm_trip_promises(uuid,text[]) from public,anon;
grant execute on function public.v3_trip_promise_status(uuid),public.v3_confirm_trip_promises(uuid,text[]) to authenticated;

-- Source step: final_guards.sql

create or replace function public.v3_admin_category_data() returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
begin
 if auth.uid() is null or not public.v25_session_is_current() or not public.is_admin_safe() then raise exception 'admin_required' using errcode='42501'; end if;
 return public.v3_category_catalog()||jsonb_build_object('promises',(select coalesce(jsonb_agg(to_jsonb(p) order by sort_order),'[]') from public.trip_promise_options_v3 p),'zones',(select coalesce(jsonb_agg(jsonb_build_object('id',z.id,'name',z.name)),'[]') from public.pricing_zones z where z.is_active),'prices',(select coalesce(jsonb_agg(to_jsonb(p)),'[]') from public.ride_category_prices_v3 p),
 'approvals',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from public.captain_category_approvals_v3 a),
 'captains',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.full_name,'vehicle',c.vehicle_type,'identity_verified',c.identity_verified_v10,'vehicle_verified',c.vehicle_verified_v10)),'[]') from public.captains c),
 'audit',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from (select * from public.category_audit_v3 order by id desc limit 100) a));
end $$;
create or replace function public.v3_customer_trip_code(p_trip uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare result jsonb;
begin
 if auth.uid() is null or not public.v25_session_is_current() or not exists(select 1 from public.trips t join public.customers c on c.id=t.customer_id where t.id=p_trip and c.user_id=auth.uid()) then raise exception 'not_authorized' using errcode='42501'; end if;
 select jsonb_build_object('pin',case when p.verified_at is null then p.pin end,'verified',p.verified_at is not null,'locked',p.failed>=5,'expires_at',p.expires_at)
 into result from veto_category_private.trip_codes p join public.trips t on t.id=p.trip_id where p.trip_id=p_trip and t.trip_status::text in ('accepted','arriving','arrived','started') and p.expires_at>now();
 return coalesce(result,'{}'::jsonb);
end $$;
create or replace function public.v3_verify_trip_code(p_trip uuid,p_code text) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare t public.trips; c veto_category_private.trip_codes;
begin
 select * into t from public.trips where id=p_trip for update;
 if auth.uid() is null or not public.v25_session_is_current() or not exists(select 1 from public.captains where id=t.captain_id and user_id=auth.uid()) then raise exception 'not_authorized' using errcode='42501'; end if;
 select * into c from veto_category_private.trip_codes where trip_id=t.id for update;
 if not found or t.trip_status::text<>'arrived' or c.expires_at<=now() or c.failed>=5 then return jsonb_build_object('success',false,'error','code_unavailable'); end if;
 if c.verified_at is not null then return jsonb_build_object('success',true); end if;
 p_code:=translate(trim(p_code),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789');
 if p_code is null or p_code !~ '^[0-9]{6}$' or p_code<>c.pin then
  update veto_category_private.trip_codes set failed=failed+1 where trip_id=t.id;
  return jsonb_build_object('success',false,'error','invalid_code','attempts_left',4-c.failed);
 end if;
 update veto_category_private.trip_codes set verified_at=now(),verified_captain=t.captain_id where trip_id=t.id;
 return jsonb_build_object('success',true);
end $$;
create or replace function public.v3_admin_save(p_entity text,p_value jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare r public.ride_categories_v3; price public.ride_category_prices_v3; a public.captain_category_approvals_v3; v text;
begin
 if auth.uid() is null or not public.v25_session_is_current() or not public.is_admin_safe() then raise exception 'admin_required' using errcode='42501'; end if;
 if p_entity='category' then
  select * into r from jsonb_populate_record(null::public.ride_categories_v3,p_value);
  if r.id not in ('veto_economy','veto_comfort','veto_premium','veto_ladies','veto_moto','veto_parcel','veto_market') or length(trim(r.name_ar))<2 or length(trim(r.name_en))<2 or r.asset<>r.id||'.webp' then raise exception 'invalid_category'; end if;
  if r.id='veto_market' and r.enabled is distinct from (select enabled from public.ride_categories_v3 where id=r.id) then raise exception 'market_managed_separately'; end if;
  update public.ride_categories_v3 set name_ar=r.name_ar,name_en=r.name_en,description_ar=r.description_ar,description_en=r.description_en,enabled=r.enabled,sort_order=r.sort_order,accent=r.accent,inherit_lower=r.inherit_lower,updated_at=now() where id=r.id;
 elsif p_entity='price' then
  select * into price from jsonb_populate_record(null::public.ride_category_prices_v3,p_value);
  if price.category_id='veto_market' then raise exception 'market_pricing_separate'; end if;
  insert into public.ride_category_prices_v3(category_id,zone_id,opening,per_km,minimum,waiting,free_wait,enabled) values(price.category_id,price.zone_id,price.opening,price.per_km,price.minimum,price.waiting,price.free_wait,price.enabled)
  on conflict(category_id,zone_id) do update set opening=excluded.opening,per_km=excluded.per_km,minimum=excluded.minimum,waiting=excluded.waiting,free_wait=excluded.free_wait,enabled=excluded.enabled,updated_at=now();
 elsif p_entity='approval' then
  select * into a from jsonb_populate_record(null::public.captain_category_approvals_v3,p_value);
  foreach v in array (coalesce(a.allowed,'{}')||coalesce(a.blocked,'{}')) loop if not exists(select 1 from public.ride_categories_v3 where id=v) then raise exception 'invalid_category'; end if; end loop;
  if a.ladies_approved and not (a.female_verified and a.documents_approved and a.insurance_approved) then raise exception 'ladies_verification_required'; end if;
  perform 1 from public.captains where id=a.captain_id for update;
  insert into public.captain_category_approvals_v3 values(a.captain_id,a.highest_tier,a.female_verified,a.ladies_approved,a.documents_approved,a.insurance_approved,a.child_seat_approved,coalesce(a.allowed,'{}'),coalesce(a.blocked,'{}'),a.reason,now())
  on conflict(captain_id) do update set highest_tier=excluded.highest_tier,female_verified=excluded.female_verified,ladies_approved=excluded.ladies_approved,documents_approved=excluded.documents_approved,insurance_approved=excluded.insurance_approved,child_seat_approved=excluded.child_seat_approved,allowed=excluded.allowed,blocked=excluded.blocked,reason=excluded.reason,updated_at=now();
 elsif p_entity='promise' then
  update public.trip_promise_options_v3 set enabled=(p_value->>'enabled')::boolean where id=p_value->>'id';
 else raise exception 'invalid_entity'; end if;
 return jsonb_build_object('success',true);
end $$;

-- Additive category guard; original V28 retry calculations and eligibility unchanged.
CREATE OR REPLACE FUNCTION public.v28_apply_search_retry_quote(p_quote_id uuid, p_trip_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$

DECLARE q public.route_pricing_quotes%ROWTYPE;

        t public.trips%ROWTYPE;

        root_time timestamptz;

        root_id uuid;

BEGIN

  IF current_setting('request.jwt.claim.role',true) IS DISTINCT FROM 'service_role'

     AND coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb->>'role' IS DISTINCT FROM 'service_role'

     AND session_user NOT IN ('postgres','supabase_admin') THEN

    RAISE EXCEPTION 'server_only' USING ERRCODE='42501';

  END IF;

  IF p_user_id IS NULL OR p_quote_id IS NULL OR p_trip_id IS NULL THEN

    RAISE EXCEPTION 'invalid_retry_request';

  END IF;

  SELECT * INTO q FROM public.route_pricing_quotes WHERE id=p_quote_id FOR UPDATE;

  IF NOT FOUND OR q.expires_at<=clock_timestamp() OR q.used_trip_id IS NOT NULL OR

    q.created_at < clock_timestamp()-interval '3 minutes' THEN

    RAISE EXCEPTION 'quote_not_available';

  END IF;

  SELECT * INTO t FROM public.trips WHERE id=p_trip_id;

  IF NOT FOUND OR t.customer_id IS DISTINCT FROM q.customer_id OR

      t.trip_status::text <> 'cancelled' OR

      t.cancellation_reason IS DISTINCT FROM 'search_timeout_10m' OR

      t.captain_id IS NOT NULL OR t.service_type IS DISTINCT FROM q.service_type OR

      NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.id=t.customer_id AND c.user_id=p_user_id AND c.is_active) THEN

    RAISE EXCEPTION 'retry_not_eligible';

  END IF;

  IF (q.pricing_snapshot->>'ride_category_id_v3') IS DISTINCT FROM t.ride_category_id_v3 THEN
    RAISE EXCEPTION 'retry_category_mismatch';
  END IF;
  root_time := coalesce(t.v28_retry_root_created_at,t.created_at);

  root_id := coalesce(t.v28_retry_root_trip_id,t.id);

  IF clock_timestamp() >= root_time+interval '1 hour' OR

     clock_timestamp() < t.created_at+interval '10 minutes' OR

     t.pickup_latitude IS NULL OR t.pickup_longitude IS NULL OR

     t.destination_latitude IS NULL OR t.destination_longitude IS NULL OR

     abs(q.pickup_lat-t.pickup_latitude)>0.00001 OR

     abs(q.pickup_lng-t.pickup_longitude)>0.00001 OR

     abs(q.destination_lat-t.destination_latitude)>0.00001 OR

     abs(q.destination_lng-t.destination_longitude)>0.00001 OR

     EXISTS (SELECT 1 FROM public.trips x WHERE x.customer_id=t.customer_id AND

       x.trip_status::text IN ('requested','offer_received','accepted','arriving','arrived','started')) THEN

    RAISE EXCEPTION 'retry_expired_or_mismatch';

  END IF;

  IF q.v28_retry_source_trip_id IS NULL THEN

    UPDATE public.route_pricing_quotes

       SET base_fare=round(q.base_fare*1.10,2),

           pricing_snapshot=q.pricing_snapshot || jsonb_build_object('v28_retry_multiplier',1.10,

                 'v28_retry_root_created_at',root_time,'v28_retry_root_trip_id',root_id),

           v28_retry_source_trip_id=t.id,

           v28_retry_root_created_at=root_time,

           v28_retry_root_trip_id=root_id

    WHERE id=q.id;

  ELSIF q.v28_retry_source_trip_id IS DISTINCT FROM t.id THEN

    RAISE EXCEPTION 'quote_already_used_for_different_retry';

  END IF;

  RETURN (SELECT to_jsonb(r)-'customer_id'-'used_trip_id'

          FROM public.route_pricing_quotes r WHERE id=q.id);

END;

$function$

commit;
