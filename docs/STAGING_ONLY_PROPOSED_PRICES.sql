-- STAGING ONLY: proposed prices supplied in the brief, never approved Production pricing.
begin;
insert into public.ride_category_prices_v3(category_id,opening,per_km,minimum,waiting,free_wait) values
('veto_economy',22,7,35,2,4),('veto_comfort',28,8.5,45,2.5,4),('veto_premium',40,11,65,3.5,4),
('veto_ladies',28,8.5,45,2.5,4),('veto_moto',15,5.5,25,1.5,4),('veto_parcel',20,6.5,35,2,4);
update public.ride_categories_v3 set enabled=true where id<>'veto_market';
commit;
