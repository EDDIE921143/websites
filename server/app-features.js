export function presentationReply(value,ids) {
 const text=(v,n)=>typeof v==='string'?v.trim().slice(0,n):undefined;
 const cards=(Array.isArray(value.cards)?value.cards:[]).slice(0,3).flatMap(card=>{
  if(!card||!['songs','practice','outline','list'].includes(card.type)||!text(card.title,100))return [];
  const items=(Array.isArray(card.items)?card.items:[]).slice(0,24).flatMap(item=>{
   if(!item||!text(item.title,160))return [];
   return [{title:text(item.title,160),...(text(item.detail,400)?{detail:text(item.detail,400)}:{}),...(text(item.meta,80)?{meta:text(item.meta,80)}:{}),...(ids.has(item.recordId)?{recordId:item.recordId}:{})}];
  });
  return items.length?[{type:card.type,title:text(card.title,100),...(text(card.subtitle,200)?{subtitle:text(card.subtitle,200)}:{}),items}]:[];
 });
 return {...(cards.length?{cards}:{}),...(text(value.spokenText,700)?{spokenText:text(value.spokenText,700)}:{})};
}
export const presentationInstructions=`When a list, song selection, practice plan or chapter outline would be useful, include cards alongside your answer: "cards":[{"type":"songs|practice|outline|list","title":"A clear heading","subtitle":"Optional short explanation","items":[{"title":"Song or step name","detail":"Artist, practice goal or useful detail","meta":"BPM, minutes, key or status when actually known","recordId":"Only when referring to a supplied saved record"}]}]. Put structured lists in these cards, not a wall of markdown. Use at most three cards and 24 items each. Keep unknown song BPM/key/tuning unknown. For music recommendations, distinguish suggestions from the band's existing repertoire. For rehearsal plans, group warm-up, focused work and a run-through, with realistic minutes and specific goals.`;
export function featureInstructions(mode) {
 if(mode==='semantic-search')return `You are helping Ediz recall saved work and previous chats by meaning. Interpret paraphrases, remembered events and partial descriptions, not just matching exact words. Rank only supplied records (which include chat transcripts) by relevance. Return JSON with text: a short explanation, recordIds: up to 12 matching supplied IDs in best-match order, and actions: []. If none match, return an empty recordIds array. Never invent a matching record or edit anything. Do not search the internet.`;
 if(mode==='chat-title')return `Name this conversation based on its substantive topic, not greetings. Use a natural specific title of 3 to 6 words in Ediz's language. A song selection discussion could be called Rehearsal songs for Friday. Never use Hello, Hi, New chat or a generic assistant greeting as the title. Return JSON with text containing only the title, recordIds: [], actions: [].`;
 return presentationInstructions;
}
export async function generateImage(apiKey,prompt) {
 const candidates=[process.env.GEMINI_IMAGE_MODEL||'gemini-3.1-flash-lite-image','gemini-3.1-flash-image'];
 let response;
 for(const model of [...new Set(candidates)]) {
  response=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},signal:AbortSignal.timeout(45000),body:JSON.stringify({contents:[{role:'user',parts:[{text:prompt}]}],generationConfig:{responseModalities:['TEXT','IMAGE'],imageConfig:{aspectRatio:'1:1'}}})});
  if(![404,429,500,502,503].includes(response.status))break;
 }
 if(!response.ok){const error=new Error(response.status===429?'Image generation has reached this connection’s quota. Your chat is still available.':'Image generation isn’t enabled for this connection. You can keep chatting and attaching images.');error.status=response.status===429?429:503;throw error;}
 const result=await response.json();const parts=result.candidates?.[0]?.content?.parts||[];
 const images=parts.flatMap(p=>{const image=p.inlineData;if(!image||!['image/png','image/jpeg','image/webp'].includes(image.mimeType)||typeof image.data!=='string'||image.data.length>10000000)return [];return [{mimeType:image.mimeType,data:image.data}]}).slice(0,1);
 if(!images.length)throw new Error('The provider returned no generated image. Try a more specific visual description.');
 return {text:parts.filter(p=>!p.thought&&typeof p.text==='string').map(p=>p.text).join('\n').slice(0,3000)||'Here’s your image.',recordIds:[],actions:[],images};
}
