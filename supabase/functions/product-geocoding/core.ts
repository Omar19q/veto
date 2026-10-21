export function coordinate(v:unknown,max:number):number {
 if(typeof v!=="number"||!Number.isFinite(v)||Math.abs(v)>max)throw new Error("invalid_coordinates");
 return Number(v.toFixed(7));
}
export function geoRequest(body:Record<string,unknown>,key:string):URL {
 const language=body.language==="en"?"en":"ar";
 const op=body.operation;
 let path:string;
 const params=new URLSearchParams({apiKey:key,lang:language,format:"json"});
 if(op==="reverse"){
  path="/v1/geocode/reverse";
  params.set("lat",String(coordinate(body.latitude,90)));params.set("lon",String(coordinate(body.longitude,180)));
 }else if(op==="search"){
  path="/v1/geocode/search";const q=String(body.query??"").trim();
  if(q.length<2||q.length>200)throw new Error("invalid_query");
  params.set("text",q);params.set("limit","6");params.set("filter","countrycode:eg");
 }else if(op==="route"){
  path="/v1/routing";params.delete("format");
  const points=body.points;
  if(!Array.isArray(points)||points.length!==2)throw new Error("invalid_coordinates");
  params.set("waypoints",points.map(p=>{if(!Array.isArray(p)||p.length!==2)throw new Error("invalid_coordinates");return `${coordinate(p[0],90)},${coordinate(p[1],180)}`;}).join("|"));
  params.set("mode","drive");
 }else throw new Error("invalid_operation");
 return new URL(`https://api.geoapify.com${path}?${params}`);
}
export function addressRows(data:unknown):Record<string,unknown>[] {
 if(typeof data!=="object"||data===null)return [];
 const source=data as {results?:unknown;features?:unknown};
 const results=Array.isArray(source.results)?source.results:Array.isArray(source.features)?source.features.map(v=>v?.properties):[];
 return results.filter(v=>typeof v==="object"&&v!==null&&Number.isFinite(v.lat)&&Number.isFinite(v.lon)&&Math.abs(v.lat)<=90&&Math.abs(v.lon)<=180).map(v=>({
  latitude:v.lat,longitude:v.lon,address:String(v.formatted??""),street:String(v.street??""),area:String(v.suburb??v.district??""),city:String(v.city??v.town??v.village??""),confidence:typeof v.rank?.confidence==="number"?v.rank.confidence:null,
 }));
}
