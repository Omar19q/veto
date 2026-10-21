-- VETO 2: service-only atomic OTP consumption and removal of automatic test OTP.
-- No wallet, trip, pricing, entitlement or role policy changes.
BEGIN;
SET LOCAL lock_timeout='8s';
SET LOCAL statement_timeout='60s';
CREATE OR REPLACE FUNCTION public.auto_verify_test_phones()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $fn$
BEGIN
 -- Every phone requires the authorized staff verification lifecycle.
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.auto_verify_test_phones() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.veto2_consume_otp(p_phone text,p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $fn$
DECLARE r public.verification_requests%ROWTYPE; maximum integer;
BEGIN
 IF p_phone IS NULL OR p_phone !~ '^([+]?[1-9][0-9]{6,14}|01[0125][0-9]{8})$'
 OR p_code IS NULL OR p_code !~ '^[0-9]{4}$' THEN
  RETURN jsonb_build_object('success',false,'error','verification_invalid');
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('product_otp:'||p_phone,0));
 SELECT * INTO r FROM public.verification_requests WHERE phone=p_phone
 AND status IN('pending','code_sent') ORDER BY created_at DESC,id DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','verification_invalid'); END IF;
 IF r.expires_at IS NULL OR r.expires_at<=clock_timestamp() THEN
  UPDATE public.verification_requests SET status='expired' WHERE id=r.id;
  RETURN jsonb_build_object('success',false,'error','verification_expired');
 END IF;
 IF r.status::text<>'code_sent' OR r.code IS NULL THEN
  RETURN jsonb_build_object('success',false,'error','verification_pending');
 END IF;
 maximum:=least(greatest(coalesce(r.max_attempts,5),1),5);
 IF coalesce(r.attempts,0)>=maximum THEN
  UPDATE public.verification_requests SET status='expired' WHERE id=r.id;
  RETURN jsonb_build_object('success',false,'error','verification_attempts_exceeded');
 END IF;
 IF r.code IS DISTINCT FROM p_code THEN
  UPDATE public.verification_requests SET attempts=coalesce(r.attempts,0)+1 WHERE id=r.id;
  IF coalesce(r.attempts,0)+1>=maximum THEN
    UPDATE public.verification_requests SET status='expired' WHERE id=r.id;
  END IF;
  RETURN jsonb_build_object('success',false,'error',CASE WHEN coalesce(r.attempts,0)+1>=maximum
    THEN 'verification_attempts_exceeded' ELSE 'verification_invalid' END);
 END IF;
 UPDATE public.verification_requests SET status='verified',verified_at=clock_timestamp(),
   attempts=coalesce(r.attempts,0)+1 WHERE id=r.id;
 RETURN jsonb_build_object('success',true,'request_id',r.id);
END $fn$;
REVOKE ALL ON FUNCTION public.veto2_consume_otp(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.veto2_consume_otp(text,text) TO service_role;
COMMIT;

