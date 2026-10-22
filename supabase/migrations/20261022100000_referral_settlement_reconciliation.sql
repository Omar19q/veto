-- VETO SANYA: Idempotent Referral Settlement Reconciliation
-- Policy: 15 EGP per successful, settled first ride of an invited customer.
-- Ensures that first completed rides credit the referring friend regardless of booking path.

BEGIN;
SET LOCAL lock_timeout = '8s';
SET LOCAL statement_timeout = '60s';

-- 1. Function to idempotently award 15 EGP referral reward for a completed trip
CREATE OR REPLACE FUNCTION public.reconcile_trip_referral_reward(p_trip_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
  v_trip record;
  v_referral record;
  v_referrer_customer_id uuid;
  v_referrer_user_id uuid;
  v_reward_amount numeric := 15.00;
  v_tx_id uuid;
BEGIN
  -- Lock and read the completed trip
  SELECT id, customer_id, trip_status, total_fare, created_at, completed_at
  INTO v_trip
  FROM public.trips
  WHERE id = p_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'trip_not_found');
  END IF;

  IF v_trip.trip_status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'trip_not_completed');
  END IF;

  -- Verify this customer has an active, bound referral where binding occurred before trip
  SELECT id, referrer_id, referee_id, created_at, status
  INTO v_referral
  FROM public.growth_referrals
  WHERE referee_id = v_trip.customer_id
    AND status IN ('bound', 'pending')
    AND created_at <= v_trip.created_at
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Fallback: check legacy/friend referral bindings if growth_referrals not used
    RETURN jsonb_build_object('success', false, 'reason', 'no_qualifying_referral');
  END IF;

  -- Ensure this is the referee's FIRST completed trip
  IF EXISTS (
    SELECT 1 FROM public.trips
    WHERE customer_id = v_trip.customer_id
      AND trip_status = 'completed'
      AND id <> v_trip.id
      AND completed_at < coalesce(v_trip.completed_at, v_trip.created_at)
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_first_completed_trip');
  END IF;

  -- Verify referrer exists and lock referrer wallet
  v_referrer_customer_id := v_referral.referrer_id;
  SELECT user_id INTO v_referrer_user_id
  FROM public.customers
  WHERE id = v_referrer_customer_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'referrer_not_found');
  END IF;

  -- IDEMPOTENCY CHECK: has this referral already been paid?
  IF EXISTS (
    SELECT 1 FROM public.wallet_transactions
    WHERE customer_id = v_referrer_customer_id
      AND tx_type = 'promo'
      AND description LIKE '%مكافأة دعوة صديق%'
      AND (metadata->>'trip_id' = p_trip_id::text OR metadata->>'referral_id' = v_referral.id::text)
  ) THEN
    RETURN jsonb_build_object('success', true, 'reason', 'already_awarded');
  END IF;

  -- Insert promotional credit to referrer's wallet
  INSERT INTO public.wallet_transactions (
    customer_id,
    tx_type,
    amount,
    description,
    metadata,
    created_at
  ) VALUES (
    v_referrer_customer_id,
    'promo',
    v_reward_amount,
    'مكافأة دعوة صديق - أول رحلة مكتملة',
    jsonb_build_object(
      'trip_id', p_trip_id,
      'referral_id', v_referral.id,
      'referee_id', v_trip.customer_id,
      'awarded_amount', v_reward_amount,
      'policy', '15_egp_first_ride'
    ),
    now()
  ) RETURNING id INTO v_tx_id;

  -- Update referrer wallet balance
  UPDATE public.customer_wallets
  SET balance = balance + v_reward_amount,
      updated_at = now()
  WHERE customer_id = v_referrer_customer_id;

  -- Mark referral as rewarded/qualified
  UPDATE public.growth_referrals
  SET status = 'rewarded',
      updated_at = now()
  WHERE id = v_referral.id;

  RETURN jsonb_build_object(
    'success', true,
    'awarded', true,
    'amount', v_reward_amount,
    'transaction_id', v_tx_id,
    'referrer_id', v_referrer_customer_id
  );
END $$;

-- 2. Bulk reconciliation function for past qualifying trips (Audit & Staging safe)
CREATE OR REPLACE FUNCTION public.reconcile_past_eligible_referrals()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
  v_rec record;
  v_count integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_single jsonb;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin_safe() THEN
    RAISE EXCEPTION 'admin_required' USING errcode = '42501';
  END IF;

  FOR v_rec IN
    SELECT t.id AS trip_id, t.customer_id
    FROM public.trips t
    JOIN public.growth_referrals r ON r.referee_id = t.customer_id
    WHERE t.trip_status = 'completed'
      AND r.status IN ('bound', 'pending')
      AND r.created_at <= t.created_at
      AND NOT EXISTS (
        SELECT 1 FROM public.trips t2
        WHERE t2.customer_id = t.customer_id
          AND t2.trip_status = 'completed'
          AND t2.completed_at < coalesce(t.completed_at, t.created_at)
          AND t2.id <> t.id
      )
    ORDER BY t.created_at ASC
  LOOP
    v_single := public.reconcile_trip_referral_reward(v_rec.trip_id);
    IF (v_single->>'awarded')::boolean = true THEN
      v_count := v_count + 1;
      v_results := v_results || v_single;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'reconciled_count', v_count,
    'details', v_results
  );
END $$;

REVOKE ALL ON FUNCTION public.reconcile_trip_referral_reward(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_trip_referral_reward(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reconcile_past_eligible_referrals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_past_eligible_referrals() TO authenticated, service_role;

COMMIT;
