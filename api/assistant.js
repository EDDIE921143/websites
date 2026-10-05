import {requestedSong,musicPreview} from '../server/music-preview.js';
import {slackContext} from '../server/slack-context.js';
import {authorized,validateReply,systemPrompt,workspaceContext,groundedSources,parseModelText,attachmentParts,generatedSpeech,botDirections,speechChunks} from '../server/gemini.js';
import {featureInstructions,generateImage,replySchema,needsWebSearch,requestsPresentation,requestsVoicePresentation} from '../server/app-features.js';
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
  try{let speechModel;for await(const bytes of speechChunks(body.text,apiKey,body.voice,controller.signal,body.speechModel,model=>{speechModel=model})){if(controller.signal.aborted)break;res.write(JSON.stringify({audio:bytes.toString('base64'),rate:24000,model:speechModel})+'\n')};if(!controller.signal.aborted)res.write(JSON.stringify({done:true})+'\n')}
  catch(error){if(!controller.signal.aborted)res.write(JSON.stringify({error:error.message})+'\n')}
  return res.end();
 }
 if(body?.mode==='speech'){try{return res.status(200).json(await generatedSpeech(body.text,apiKey,body.voice))}catch(error){return res.status(error.status===429?429:503).json({error:error.message,...(error.quota?{quota:error.quota}:{})})}}
 if(body?.mode==='image'){if(typeof body.question!=='string'||!body.question.trim()||body.question.length>4000)return res.status(400).json({error:'Describe the image in a shorter message.'});try{return res.status(200).json(await generateImage(apiKey,body.question))}catch(error){return res.status(error.status||503).json({error:error.message})}}
 if(!body||typeof body.question!=='string'||!body.question.trim()||body.question.length>(body.mode==='capture-polish'?32000:8000)||!Array.isArray(body.records)||body.records.some(record=>!record||typeof record!=='object'||typeof record.id!=='string')||body.records.length>(body.mode==='exercise-search'?1200:500)||(body.conversation!=null&&!Array.isArray(body.conversation))||JSON.stringify(body).length>4100000)return res.status(400).json({error:'Share up to 500 records and a shorter question.'});
 const controller=new AbortController();res.on?.('close',()=>{if(!res.writableEnded)controller.abort()});
 let media;try{media=attachmentParts(body.attachments)}catch(error){return res.status(400).json({error:error.message})}
 if(body.mode?.startsWith('record-')&&(body.records.length!==1||media.length))return res.status(400).json({error:'Choose one item without attachments for these writing tools.'});
 const model=process.env.GEMINI_MODEL||'gemini-3.8-flash';
 try{
  const song=body.mode !== 'semantic-search' && body.scope==='band' ? requestedSong(body.question):null;
  if(song){
   try{const preview=await musicPreview(song);return res.status(200).json({text:preview?`Here’s a preview of ${preview.title} by ${preview.artist}.`:'I couldn’t find a catalog preview for that song. Try its title and artist.',recordIds:[],actions:[],...(preview?{musicPreview:preview,presentResults:true}:{})})}
   catch(error){return res.status(503).json({error:error.message})}
  }
  const special=['semantic-search','exercise-search','chat-title','capture-polish'].includes(body.mode)||body.mode?.startsWith('record-');
  const search=!special && needsWebSearch(body.question);
  const slack= !special && ['ejj','all',undefined].includes(body.scope) ? await slackContext():{status:'out_of_scope',messages:[]};
  const careful=['school','moshia'].includes(body.scope);
  const models=[...new Set((media.length||search)?[process.env.GEMINI_MEDIA_MODEL||'gemini-3.8-flash',model,'gemini-3.1-flash-lite','gemini-2.5-flash']:careful?[model,'gemini-2.5-flash','gemini-3.1-flash-lite','gemini-2.5-flash-lite']:['gemini-3.1-flash-lite',model,'gemini-2.5-flash','gemini-2.5-flash-lite'])];
  let response,selectedModel;let quotaLimited=false;const attempts=[];const deadline=Date.now()+65000;
  for(const candidate of models){
   if(Date.now()>=deadline)throw new DOMException("Reply deadline exceeded","TimeoutError");
   selectedModel=candidate;
   const payload={systemInstruction:{parts:[{text:special?featureInstructions(body.mode):systemPrompt+"\n"+botDirections(body.scope,body.voiceMode===true)+"\n"+featureInstructions(body.mode)}]},contents:[...(body.conversation||[]).slice(-12).filter(item=>item && ["user","assistant"].includes(item.role) && typeof item.text === "string" && item.text.trim()).map(item=>({role:item.role === "assistant" ? "model":"user",parts:[{text:item.text.slice(0,8000)}]})),{role:'user',parts:[{text:JSON.stringify({question:body.question,slackContext:slack,workspace:body.scope||'all',workspaceBriefs:special?[]:workspaceContext(process.env.EDIZ_CONTEXT_JSON,body.scope||'all').filter(item=>!body.records.some(record=>record.id===item.id)),records:body.records,conversationMemory:special?[]:(Array.isArray(body.memories)?body.memories:[]).slice(0,12).filter(item=>item&&typeof item.title==='string'&&typeof item.body==='string'&&(body.scope==='all'||!body.scope||item.space===body.scope)).map(item=>({title:item.title.slice(0,100),body:item.body.slice(0,6000),space:item.space,readOnly:true})),conversation:(body.conversation||[]).slice(-8),earlierMedia:Array.isArray(body.earlierMedia)?body.earlierMedia.filter(name=>typeof name==='string').slice(0,3):[],localDate:body.localDate,timeZone:body.timeZone})},...media]}],...(search?{tools:[{google_search:{}}]}:{}),generationConfig:{...(search?{}:{responseMimeType:"application/json",...(['chat-title','semantic-search','exercise-search'].includes(body.mode)?{responseJsonSchema:replySchema(body.mode)}:{})}),temperature:body.scope==='moshia'?.4:body.scope==='school'?.15:.25,maxOutputTokens:body.mode==='chat-title'?128:['semantic-search','exercise-search'].includes(body.mode)?1400:body.mode==='capture-polish'?16384:body.scope==='school'?6000:4096,...(/^gemini-3\./.test(candidate)?{thinkingConfig:{thinkingLevel:candidate==='gemini-3.1-flash-lite'?'minimal':'low'}}:{})}};
   const request=()=>fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(candidate)}:generateContent`,{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},signal:AbortSignal.any([controller.signal,AbortSignal.timeout(Math.max(1,Math.min(20000,deadline-Date.now())))]),body:JSON.stringify(payload)});
   try{
    response=await request();
    if(response.status===400 && !search && payload.generationConfig.responseJsonSchema){delete payload.generationConfig.responseJsonSchema;response=await request()}
   }catch(error){if(controller.signal.aborted || candidate===models.at(-1))throw error;continue}
   if(!response.ok){const failure=await response.clone().json().catch(()=>({}));attempts.push({model:candidate,status:response.status,reason:String(failure.error?.message||'').replaceAll(apiKey,'[redacted]').slice(0,300)})}
   if(response.status===429)quotaLimited=true;
   if(![400,429,500,502,503,504,404].includes(response.status))break;
  }
  if(!response.ok){const status=quotaLimited?429:response.status;return res.status(status===429?429:502).json({error:status===429?'Google’s quota is temporarily unavailable. Please try again shortly.':status===401||status===403?'The cloud connection was rejected. Check the assistant connection in Settings.':'The assistant provider couldn’t answer. Please try again.',...(body.diagnostics===true?{attempts}:{})});}
  res.setHeader('X-Ediz-Model',selectedModel);
  const result=await response.json();const text=result.candidates?.[0]?.content?.parts?.filter(p=>!p.thought).map(p=>p.text||'').join('');
  if(!text)return res.status(502).json({error:'Google returned no usable answer. Your saved data is unchanged.'});
  if(result.candidates?.[0]?.finishReason==='MAX_TOKENS')return res.status(502).json({error:'That reply was cut short. Try a more focused question.'});
  const metadata=result.candidates?.[0]?.groundingMetadata;
  const parsed=parseModelText(text);const reply=validateReply(parsed,body.records);
  if(body.mode==='song-recommendations'){reply.actions=[];}
  if(body.mode==='song-recommendations')reply.songSuggestions=(Array.isArray(parsed.songSuggestions)?parsed.songSuggestions:[]).filter(item=>item&&typeof item.title==='string'&&typeof item.artist==='string'&&typeof item.reason==='string').slice(0,20).map(item=>({title:item.title.slice(0,160),artist:item.artist.slice(0,160),reason:item.reason.slice(0,400)}));if(special){reply.actions=[];delete reply.cards;}
  if(!special){const present=body.voiceMode===true?requestsVoicePresentation(body.question):requestsPresentation(body.question,body.conversation);reply.presentResults=present;if(!present){delete reply.cards;reply.recordIds=[]}}
  return res.status(200).json({...reply,sources:groundedSources(metadata),searchSuggestions:metadata?.searchEntryPoint?.renderedContent||null});
 }catch(error){if(controller.signal.aborted)return;return res.status(502).json({error:['TimeoutError','AbortError'].includes(error?.name)?'The assistant took too long to reply. Please try again.':'That reply couldn’t be completed. Please try again.'});}
}
