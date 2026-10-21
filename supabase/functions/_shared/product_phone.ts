import { parsePhoneNumberFromString } from 'npm:libphonenumber-js@1.13.15/max';

/** Existing Egyptian identities retain their original 01... lookup key. */
export function productPhone(value: string): { e164: string; lookup: string } | null {
  const digits = value.replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 1632))
    .replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 1776));
  const phone = parsePhoneNumberFromString(digits, 'EG');
  if (!phone?.isValid() || !['MOBILE', 'FIXED_LINE_OR_MOBILE'].includes(phone.getType() ?? '')) return null;
  return { e164: phone.number, lookup: phone.country === 'EG' ? `0${phone.nationalNumber}` : phone.number };
}

export function internationalEnabled(project: string, flag: string | undefined): boolean {
  try {
    const host = new URL(project).hostname;
    return flag === 'true' && host !== 'wbdjvzaomtlojttjnfhp.supabase.co';
  } catch { return false; }
}
