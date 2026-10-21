import {parsePhoneNumberFromString} from 'npm:libphonenumber-js@1.13.15/max';
export const supportedCountries=new Set(['EG','GB','SA','AE']);
export function productPhone(value:string):{e164:string;lookup:string;country:string}|null {
 const digits=value.replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632)).replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-1776));
 const normalized=digits.trim().startsWith('00')?'+'+digits.trim().slice(2):digits;
 const phone=parsePhoneNumberFromString(normalized,'EG');
 if(!phone?.isValid()||!phone.country||!supportedCountries.has(phone.country)||!['MOBILE','FIXED_LINE_OR_MOBILE'].includes(phone.getType()??''))return null;
 return {e164:phone.number,country:phone.country,lookup:phone.country==='EG'?'0'+phone.nationalNumber:phone.number};
}
