BEGIN;
SET LOCAL lock_timeout='8s';
CREATE OR REPLACE FUNCTION public.create_verification_request(p_phone text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_phone TEXT;
  v_existing public.verification_requests%ROWTYPE;
  v_request public.verification_requests%ROWTYPE;
BEGIN
  v_phone := regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g');

  IF length(v_phone) = 12 AND left(v_phone, 2) = '20' THEN
    v_phone := '0' || substring(v_phone FROM 3);
  END IF;

  IF v_phone !~ '^01[0-9]{9}$' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_phone'
    );
  END IF;

  -- Serialize identical requests before selecting or creating an OTP lifecycle.
  PERFORM pg_advisory_xact_lock(hashtextextended('product_otp:'||v_phone,0));
  IF NOT public.claim_login_budget_scale_v15('customer',
    md5('otp_request:'||v_phone)||md5(v_phone||':request')) THEN
    RETURN jsonb_build_object('success',false,'error','login_rate_limit');
  END IF;
  SELECT * INTO v_existing
  FROM public.verification_requests
  WHERE phone = v_phone
    AND status IN ('pending', 'code_sent')
  ORDER BY created_at DESC
  LIMIT 1;

  -- عدم إنشاء طلبات متكررة لنفس الرقم
  IF FOUND AND v_existing.expires_at > now() THEN
    RETURN jsonb_build_object(
      'success', true,
      'request_id', v_existing.id,
      'status', v_existing.status::TEXT
    );
  END IF;

  -- إنهاء أي طلب قديم
  UPDATE public.verification_requests
  SET status = 'expired'
  WHERE phone = v_phone
    AND status IN ('pending', 'code_sent');

  -- إنشاء الطلب الجديد
  INSERT INTO public.verification_requests (
    phone,
    status,
    attempts,
    max_attempts,
    requested_at,
    expires_at
  ) VALUES (
    v_phone,
    'pending',
    0,
    5,
    now(),
    now() + interval '30 minutes'
  )
  RETURNING * INTO v_request;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_request.id,
    'status', v_request.status::TEXT
  );
END;
$function$
;
COMMIT;

