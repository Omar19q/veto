import {geoRequest,addressRows} from './core.ts';
function assert(v:unknown){if(!v)throw new Error('assertion_failed');}
Deno.test('Coordinates finite and ordered lat/lon; no arbitrary upstream URL',()=>{
 const u=geoRequest({operation:'reverse',latitude:29.98,longitude:31.11,language:'en'},'synthetic');
 assert(u.hostname==='api.geoapify.com'&&u.searchParams.get('lat')==='29.98'&&u.searchParams.get('lon')==='31.11');
 for(const invalid of [NaN,Infinity,91]){let rejected=false;try{geoRequest({operation:'reverse',latitude:invalid,longitude:31},'synthetic');}catch{rejected=true;}assert(rejected);}
});
Deno.test('Search bounded and encoded; user place descriptions preserved',()=>{
 const u=geoRequest({operation:'search',query:'شارع & مكان',language:'ar'},'synthetic');assert(u.searchParams.get('text')==='شارع & مكان');assert(u.searchParams.get('filter')==='countrycode:eg');
 const rows=addressRows({results:[{lat:29.9,lon:31.1,formatted:'عنوان كما ورد',street:'شارع',rank:{confidence:0.8}},{lat:NaN,lon:1}]});assert(rows.length===1&&rows[0].address==='عنوان كما ورد');
});
Deno.test('Routing geometry is display-only and exactly two valid points',()=>{
 const u=geoRequest({operation:'route',points:[[29.9,31.1],[30,31.2]]},'synthetic');assert(u.searchParams.get('waypoints')==='29.9,31.1|30,31.2');
 let rejected=false;try{geoRequest({operation:'route',points:[[0,0]]},'synthetic');}catch{rejected=true;}assert(rejected);
});
