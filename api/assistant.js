import {authorized,validateReply,systemPrompt,workspaceContext,groundedSources} from '../server/gemini.js';
const requests=new Map();
export default async function handler(req,res) {
 const apiKey=process.env.GEMINI_API_KEY||process.env.geminiapi;
 res.setHeader('Cache-Control','no-store');
 if(req.method==='GET'&&req.query?.context==='1'){if(!authorized(req.headers.authorization?.replace(/^Bearer /,''),process.env.EDIZ_ASSISTANT_TOKEN))return res.status(401).json({error:'Connect this device first.'});return res.status(200).json({items:workspaceContext(process.env.EDIZ_CONTEXT_JSON)});}
 if(req.method==='GET')return res.status(200).json({configured:!!(apiKey&&process.env.EDIZ_ASSISTANT_TOKEN),provider:'Gemini'});
 if(req.method!=='POST'){res.setHeader('Allow','GET, POST');return res.status(405).json({error:'Use a supported request method.'});}
 const origin=req.headers.origin;
 if(origin&&origin!==`https://${req.headers.host}`&&origin!=='http://localhost:4173')return res.status(403).json({error:'This request must come from Ediz OS.'});
 if(!apiKey)return res.status(503).json({error:'Gemini isn’t configured yet. Your on-device assistant still works.'});
 if(!authorized(req.headers.authorization?.replace(/^Bearer /,''),process.env.EDIZ_ASSISTANT_TOKEN))return res.status(401).json({error:'Connect this device using your private assistant link.'});
 const now=Date.now(),window=Math.floor(now/60000),count=requests.get(window)||0;requests.clear();requests.set(window,count+1);
 if(count>=10)return res.status(429).json({error:'A few too many requests at once. Try again in a minute.'});
 let body=req.body;try{if(typeof body==='string')body=JSON.parse(body)}catch{return res.status(400).json({error:'That request couldn’t be read.'})}
 if(!body||typeof body.question!=='string'||!body.question.trim()||body.question.length>8000||!Array.isArray(body.records)||body.records.length>500||JSON.stringify(body).length>700000)return res.status(400).json({error:'Share up to 500 records and a shorter question.'});
 const model=process.env.GEMINI_MODEL||'gemini-3.8-flash';
 try{
  const search=/\b(search|look up|browse|internet|latest|current news|recherchier|suche im|im internet)\b/i.test(body.question);
  const models=[...new Set([model,'gemini-3.1-flash-lite'])];
  let response;
  for(const candidate of models){
   response=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(candidate)}:generateContent`,{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},signal:AbortSignal.timeout(30000),body:JSON.stringify({systemInstruction:{parts:[{text:systemPrompt}]},contents:[{role:'user',parts:[{text:JSON.stringify({question:body.question,workspace:body.scope||'all',workspaceBriefs:workspaceContext(process.env.EDIZ_CONTEXT_JSON,body.scope||'all'),records:body.records,conversation:(body.conversation||[]).slice(-8),localDate:body.localDate,timeZone:body.timeZone})}]}],...(search?{tools:[{google_search:{}}]}:{}),generationConfig:{...(search?{}:{responseMimeType:"application/json"}),temperature:.25,maxOutputTokens:4096}})});
   if(![429,503,404].includes(response.status))break;
  }
  if(!response.ok){const status=response.status;const failure=await response.json().catch(()=>({}));const detail=typeof failure.error?.message==='string'?failure.error.message.replaceAll(apiKey,'[redacted]').slice(0,500):'';return res.status(status===429?429:502).json({error:status===429?'Google’s free quota is temporarily unavailable. Your on-device assistant still works.':status===401||status===403?'Google rejected the configured API key. Check its API restrictions and account access.':'Google couldn’t answer this request. '+detail});}
  const result=await response.json();const text=result.candidates?.[0]?.content?.parts?.filter(p=>!p.thought).map(p=>p.text||'').join('');
  if(!text)return res.status(502).json({error:'Google returned no usable answer. Your saved data is unchanged.'});
  const metadata=result.candidates?.[0]?.groundingMetadata;
  return res.status(200).json({...validateReply(parseModelText(text),body.records),sources:groundedSources(metadata),searchSuggestions:metadata?.searchEntryPoint?.renderedContent||null});
 }catch{return res.status(502).json({error:'Gemini couldn’t finish that reply. Your saved data is unchanged.'});}
}

function parseModelText(text){
 const clean=text.trim().replace(/^```(?:json)?\s*/,'').replace(/\s*```$/,'');
 try{return JSON.parse(clean)}catch{return {text:clean,actions:[],recordIds:[]}}
}
