import { productPhone, internationalEnabled } from './product_phone.ts';
function equal(actual: unknown, expected: unknown) { if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error('phone assertion failed'); }
Deno.test('Egypt aliases retain the same account key', () => {
  for (const value of ['01012345678', '+201012345678', '٠١٠١٢٣٤٥٦٧٨']) equal(productPhone(value), { e164: '+201012345678', lookup: '01012345678' });
});
Deno.test('international mobile numbers use E164 without rewriting Egyptian identities', () => {
  equal(productPhone('+966501234567'), { e164: '+966501234567', lookup: '+966501234567' });
  equal(productPhone('123'), null);
});
Deno.test('production and default configuration reject international enablement', () => {
  equal(internationalEnabled('https://wbdjvzaomtlojttjnfhp.supabase.co', 'true'), false);
  equal(internationalEnabled('http://127.0.0.1:54321', undefined), false);
  equal(internationalEnabled('http://127.0.0.1:54321', 'true'), true);
});
