import {authorized,validateReply,systemPrompt} from '../server/gemini.js';
const requests=new Map();
export default async function handler(req,res) {
 const apiKey=process.env.GEMINI_API_KEY||process.env.geminiapi;
 res.setHeader('Cache-Control','no-store');
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
  const response=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},signal:AbortSignal.timeout(45000),body:JSON.stringify({systemInstruction:{parts:[{text:systemPrompt}]},contents:[{role:'user',parts:[{text:JSON.stringify({question:body.question,records:body.records,conversation:(body.conversation||[]).slice(-8),localDate:body.localDate,timeZone:body.timeZone})}]}],generationConfig:{responseMimeType:'application/json',temperature:.25,maxOutputTokens:4096}})});
  if(!response.ok){const status=response.status;const failure=await response.json().catch(()=>({}));const detail=typeof failure.error?.message==='string'?failure.error.message.replaceAll(apiKey,'[redacted]').slice(0,500):'';return res.status(status===429?429:502).json({error:status===429?'Google’s free quota is temporarily unavailable. Your on-device assistant still works.':status===401||status===403?'Google rejected the configured API key. Check its API restrictions and account access.':'Google couldn’t answer this request. '+detail});}
  const result=await response.json();const text=result.candidates?.[0]?.content?.parts?.filter(p=>!p.thought).map(p=>p.text||'').join('');
  if(!text)return res.status(502).json({error:'Google returned no usable answer. Your saved data is unchanged.'});
  return res.status(200).json(validateReply(JSON.parse(text),body.records));
 }catch{return res.status(502).json({error:'Gemini couldn’t finish that reply. Your saved data is unchanged.'});}
}
