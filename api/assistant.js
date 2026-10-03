import {authorized,validateReply,systemPrompt,workspaceContext,groundedSources,parseModelText,attachmentParts,generatedSpeech,botDirections,speechChunks} from '../server/gemini.js';
import {featureInstructions,generateImage} from '../server/app-features.js';
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
 let body;try{body=typeof req.body==='string'?JSON.parse(req.body):req.body}catch{return res.status(400).json({error:'That request couldn’t be read.'})}
 const bucket=(typeof body?.mode==='string'&&body.mode.startsWith('speech'))?'speech':'chat',window=Math.floor(Date.now()/60000);
 for(const [key,value] of requests){if(value.window!==window)requests.delete(key)}
 const count=requests.get(bucket)?.count||0;requests.set(bucket,{window,count:count+1});
 if(count>=30)return res.status(429).json({error:'A few too many requests at once. Try again in a minute.'});
 if(body?.mode==='speech-stream'){
  if(typeof body.text!=='string'||!body.text.trim()||body.text.length>2000)return res.status(400).json({error:'Use a shorter reply for speech.'});
  const controller=new AbortController();res.on('close',()=>{if(!res.writableEnded)controller.abort()});
  res.status(200);res.setHeader('Content-Type','application/x-ndjson');res.setHeader('Cache-Control','no-store, no-transform');
  try{for await(const bytes of speechChunks(body.text,apiKey,body.voice,controller.signal)){if(controller.signal.aborted)break;res.write(JSON.stringify({audio:bytes.toString('base64'),rate:24000})+'\n')};if(!controller.signal.aborted)res.write(JSON.stringify({done:true})+'\n')}
  catch(error){if(!controller.signal.aborted)res.write(JSON.stringify({error:error.message})+'\n')}
  return res.end();
 }
 if(body?.mode==='speech'){try{return res.status(200).json(await generatedSpeech(body.text,apiKey,body.voice))}catch(error){return res.status(error.status===429?429:503).json({error:error.message,...(error.quota?{quota:error.quota}:{})})}}
 if(body?.mode==='image'){if(typeof body.question!=='string'||!body.question.trim()||body.question.length>4000)return res.status(400).json({error:'Describe the image in a shorter message.'});try{return res.status(200).json(await generateImage(apiKey,body.question))}catch(error){return res.status(error.status||503).json({error:error.message})}}
 if(!body||typeof body.question!=='string'||!body.question.trim()||body.question.length>8000||!Array.isArray(body.records)||body.records.some(record=>!record||typeof record!=='object'||typeof record.id!=='string')||body.records.length>500||(body.conversation!=null&&!Array.isArray(body.conversation))||JSON.stringify(body).length>4100000)return res.status(400).json({error:'Share up to 500 records and a shorter question.'});
 let media;try{media=attachmentParts(body.attachments)}catch(error){return res.status(400).json({error:error.message})}
 const model=process.env.GEMINI_MODEL||'gemini-3.8-flash';
 try{
  const special=['semantic-search','chat-title'].includes(body.mode);
  const search=!special && /\b(search|look up|browse|internet|latest|current news|recherchier|suche im|im internet)\b/i.test(body.question);
  const models=[...new Set(media.length?[process.env.GEMINI_MEDIA_MODEL||'gemini-3.8-flash',model,'gemini-3.1-flash-lite']:['gemini-3.1-flash-lite',model])];
  let response,selectedModel;
  for(const candidate of models){
   selectedModel=candidate;try{response=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(candidate)}:generateContent`,{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},signal:AbortSignal.timeout(20000),body:JSON.stringify({systemInstruction:{parts:[{text:systemPrompt+"\n"+botDirections(body.scope,body.voiceMode===true)+"\n"+featureInstructions(body.mode)}]},contents:[{role:'user',parts:[{text:JSON.stringify({question:body.question,workspace:body.scope||'all',workspaceBriefs:special?[]:workspaceContext(process.env.EDIZ_CONTEXT_JSON,body.scope||'all').filter(item=>!body.records.some(record=>record.id===item.id)),records:body.records,conversation:(body.conversation||[]).slice(-8),localDate:body.localDate,timeZone:body.timeZone})},...media]}],...(search?{tools:[{google_search:{}}]}:{}),generationConfig:{...(search?{}:{responseMimeType:"application/json"}),temperature:.25,maxOutputTokens:body.mode==='chat-title'?128:body.mode==='semantic-search'?1400:4096,...(/^gemini-3\./.test(candidate)?{thinkingConfig:{thinkingLevel:candidate==='gemini-3.1-flash-lite'?'minimal':'low'}}:{})}})});}catch(error){if(candidate===models.at(-1))throw error;continue}
   if(![429,500,502,503,504,404].includes(response.status))break;
  }
  if(!response.ok){const status=response.status;return res.status(status===429?429:502).json({error:status===429?'Google’s quota is temporarily unavailable. Please try again shortly.':status===401||status===403?'The cloud connection was rejected. Check the assistant connection in Settings.':'The assistant provider couldn’t answer. Please try again.'});}
  res.setHeader('X-Ediz-Model',selectedModel);
  const result=await response.json();const text=result.candidates?.[0]?.content?.parts?.filter(p=>!p.thought).map(p=>p.text||'').join('');
  if(!text)return res.status(502).json({error:'Google returned no usable answer. Your saved data is unchanged.'});
  if(result.candidates?.[0]?.finishReason==='MAX_TOKENS')return res.status(502).json({error:'That reply was cut short. Try a more focused question.'});
  const metadata=result.candidates?.[0]?.groundingMetadata;
  const reply=validateReply(parseModelText(text),body.records);if(special)reply.actions=[];
  return res.status(200).json({...reply,sources:groundedSources(metadata),searchSuggestions:metadata?.searchEntryPoint?.renderedContent||null});
 }catch(error){return res.status(502).json({error:['TimeoutError','AbortError'].includes(error?.name)?'The assistant took too long to reply. Please try again.':'That reply couldn’t be completed. Please try again.'});}
}
