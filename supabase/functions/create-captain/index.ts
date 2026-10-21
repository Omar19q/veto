import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify the caller is an admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Create admin client with service role key (server-side only — never exposed to Flutter)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Verify caller is admin using their JWT
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user: callerUser } } = await callerClient.auth.getUser()
    if (!callerUser) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: callerProfile } = await supabaseAdmin
      .from('user_profiles')
      .select('user_role')
      .eq('id', callerUser.id)
      .single()

    if (!callerProfile || callerProfile.user_role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const {
      full_name,
      phone,
      vehicle_type,
      vehicle_brand,
      vehicle_model,
      vehicle_year,
      vehicle_color,
      vehicle_plate,
      captain_status,
      can_do_car_ride,
      can_do_motorcycle_ride,
      can_do_package,
      can_do_vito_market,
    } = body

    if (!full_name || !phone || !vehicle_type) {
      return new Response(JSON.stringify({ error: 'full_name, phone, vehicle_type are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Validate vehicle type
    if (vehicle_type !== 'car' && vehicle_type !== 'motorcycle') {
      return new Response(JSON.stringify({ error: 'vehicle_type must be car or motorcycle' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ── VEHICLE-TYPE COMPATIBILITY VALIDATION ──────────────────────────────────
    // car_ride can only be assigned to a captain whose vehicle type is car
    if (can_do_car_ride && vehicle_type !== 'car') {
      return new Response(JSON.stringify({ 
        error: 'خدمة مشوار سيارة تتطلب نوع مركبة: سيارة. الكابتن لديه موتوسيكل.' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // motorcycle_ride can only be assigned to a captain whose vehicle type is motorcycle
    if (can_do_motorcycle_ride && vehicle_type !== 'motorcycle') {
      return new Response(JSON.stringify({ 
        error: 'خدمة مشوار موتوسيكل تتطلب نوع مركبة: موتوسيكل. الكابتن لديه سيارة.' 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalize Egyptian phone number
    let normalizedPhone = phone.replace(/\D/g, '')
    // Convert +20XXXXXXXXXX or 20XXXXXXXXXX to 0XXXXXXXXXX
    if (normalizedPhone.startsWith('20') && normalizedPhone.length === 12) {
      normalizedPhone = '0' + normalizedPhone.substring(2)
    }
    // Ensure it starts with 0 and is 11 digits
    if (!normalizedPhone.startsWith('0') || normalizedPhone.length !== 11) {
      return new Response(JSON.stringify({ error: 'رقم الهاتف غير صحيح. يجب أن يكون رقم مصري مكون من 11 رقم.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check duplicate phone in captains table
    const { data: existingCaptain } = await supabaseAdmin
      .from('captains')
      .select('id, full_name')
      .eq('phone', normalizedPhone)
      .maybeSingle()

    if (existingCaptain) {
      return new Response(JSON.stringify({ 
        error: `رقم الهاتف ${normalizedPhone} مسجل بالفعل للكابتن: ${existingCaptain.full_name}` 
      }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Create auth user for captain using service role (secure server-side only)
    // Email is derived from phone — never exposed to client
    const captainEmail = `captain_${normalizedPhone}@vetosanya.internal`
    const captainPassword = `Cap${normalizedPhone}!VS2026`

    // Check if auth user already exists for this email
    const { data: existingUsersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 })
    const existingAuthUser = existingUsersData?.users?.find((u: any) => u.email === captainEmail)

    let authUserId: string

    if (existingAuthUser) {
      // Auth user exists — check if captain row already exists for this user_id
      const { data: captainForUser } = await supabaseAdmin
        .from('captains')
        .select('id')
        .eq('user_id', existingAuthUser.id)
        .maybeSingle()

      if (captainForUser) {
        return new Response(JSON.stringify({ 
          error: 'يوجد حساب كابتن مرتبط بهذا الرقم بالفعل.' 
        }), {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      authUserId = existingAuthUser.id
    } else {
      // Create new auth user — this generates a REAL Supabase Auth UUID
      const { data: newAuthUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: captainEmail,
        password: captainPassword,
        email_confirm: true,
        user_metadata: { 
          full_name, 
          phone: normalizedPhone, 
          role: 'captain' 
        },
      })

      if (authError || !newAuthUser.user) {
        return new Response(JSON.stringify({ 
          error: `فشل إنشاء حساب المصادقة: ${authError?.message ?? 'خطأ غير معروف'}` 
        }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      authUserId = newAuthUser.user.id
    }

    // Upsert user_profile with captain role — authUserId is a REAL Supabase Auth UUID
    const { error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .upsert({
        id: authUserId,
        phone: normalizedPhone,
        full_name,
        user_role: 'captain',
        is_active: true,
      }, { onConflict: 'id' })

    if (profileError) {
      return new Response(JSON.stringify({ 
        error: `خطأ في إنشاء الملف الشخصي: ${profileError.message}` 
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Insert captain record — user_id references the REAL auth UUID
    const { data: captain, error: captainError } = await supabaseAdmin
      .from('captains')
      .insert({
        user_id: authUserId,
        phone: normalizedPhone,
        full_name,
        vehicle_type: vehicle_type,
        vehicle_brand: vehicle_brand || null,
        vehicle_model: vehicle_model || null,
        vehicle_year: vehicle_year ? parseInt(vehicle_year) : null,
        vehicle_color: vehicle_color || null,
        vehicle_plate: vehicle_plate || null,
        captain_status: captain_status || 'active',
        is_online: false,
        is_available: false,
        // Service eligibility — already validated for vehicle-type compatibility above
        can_do_car_ride: can_do_car_ride ?? false,
        can_do_motorcycle_ride: can_do_motorcycle_ride ?? false,
        can_do_package: can_do_package ?? false,
        can_do_vito_market: can_do_vito_market ?? false,
      })
      .select()
      .single()

    if (captainError) {
      return new Response(JSON.stringify({ 
        error: `خطأ في إنشاء سجل الكابتن: ${captainError.message}` 
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Log audit entry
    await supabaseAdmin.from('audit_logs').insert({
      admin_id: callerUser.id,
      action: 'create_captain',
      entity_type: 'captain',
      entity_id: captain.id,
      details: { 
        full_name, 
        phone: normalizedPhone, 
        vehicle_type,
        services: {
          car_ride: can_do_car_ride ?? false,
          motorcycle_ride: can_do_motorcycle_ride ?? false,
          package: can_do_package ?? false,
          vito_market: can_do_vito_market ?? false,
        }
      },
    })

    return new Response(JSON.stringify({ 
      success: true, 
      captain,
      auth_user_id: authUserId,
      message: 'تم إنشاء الكابتن بنجاح مع حساب مصادقة حقيقي'
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
