import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
// Fail closed if V16 schema is unavailable. Apply migration before deploying.
export async function staffPhoneReservedV16(admin: SupabaseClient, phone: string): Promise<boolean> {
 const {data,error}=await admin.rpc('v16_phone_reserved',{p_phone:phone});
 if(error) throw new Error('staff_reservation_check_unavailable');
 return data===true;
}
