import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server modules are JavaScript
import {presentationReply,featureInstructions,generateImage,replySchema,needsWebSearch,requestsVoicePresentation} from '../server/app-features.js';
// @ts-expect-error server modules are JavaScript
import {botDirections} from '../server/gemini.js';
// @ts-expect-error server modules are JavaScript
import handler from '../api/assistant.js';
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals()});
it('labels actual saved references separately from generated lists and removes duplicate cards',()=>{
 const list={type:'list',title:'Ideas',purpose:'saved',items:[{title:'An idea',recordId:'invented'}]};
 const result=presentationReply({cards:[list,list,{type:'songs',title:'Repertoire',items:[{title:'A real song',recordId:'real'}]}]},new Set(['real']));
 expect(result.cards).toHaveLength(2);expect(result.cards[0].purpose).toBe('generated');expect(result.cards[1].purpose).toBe('saved');
});
it('uses web tools for weather and research but not private recall or planning',()=>{
 for(const question of ['What is the weather in Berlin?','Wie wird das Wetter morgen?','Search for current music tools'])expect(needsWebSearch(question)).toBe(true);
 for(const question of ['Hello','Plan my homework tomorrow','Find our rehearsal notes'])expect(needsWebSearch(question)).toBe(false);
 expect(replySchema().properties.cards.items.properties.type.enum).toContain('songs');expect(replySchema('semantic-search').properties.actions.maxItems).toBe(0);
});
it('shares earlier chats as scoped read-only memory and requests dependable structured results',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 const fetcher=vi.fn(async(_url:any,options:any)=>{if(JSON.parse(options.body).tools?.[0]?.functionDeclarations)return new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:['chat-memory-0']}}}]}}]}));return new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'We planned an acoustic warm-up.',recordIds:['memory'],actions:[{type:'update',entityId:'memory',title:'Edit remembered chat',fields:{body:'Changed'}}]})}]},finishReason:'STOP'}]}))});vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{question:'What did we agree in our earlier rehearsal conversation?',scope:'band',records:[],memories:[{title:'Warm-up',space:'band',body:'Acoustic warm-up for five minutes.'},{title:'Private client',space:'ejj',body:'Business context'}]}},res);
 expect(res.statusCode).toBe(200);expect(res.body.actions).toEqual([]);expect(res.body.recordIds).toEqual([]);
 const request=JSON.parse((fetcher.mock.calls[1] as any)[1].body);const input=JSON.parse(request.contents[0].parts[0].text);
 expect(input.conversationMemory).toEqual([{title:'Warm-up',space:'band',body:'Acoustic warm-up for five minutes.',readOnly:true}]);expect(request.generationConfig.responseMimeType).toBe('application/json');expect(request.generationConfig.responseJsonSchema).toBeUndefined();
});
it('validates result cards without inventing saved links or accepting unsupported cards',()=>{
 const result=presentationReply({spokenText:'Here are three suggestions.',cards:[{type:'songs',title:'Friday rehearsal',items:[{title:'A song',detail:'Suggested, not saved',recordId:'invented'},{title:'Saved song',recordId:'known'}]},{type:'html',title:'Unsafe card',items:[{title:'x'}]}]},new Set(['known']));
 expect(result.cards).toHaveLength(1);expect(result.cards[0].items[0]).not.toHaveProperty('recordId');expect(result.cards[0].items[1].recordId).toBe('known');expect(result.spokenText).toContain('suggestions');expect(presentationReply({},new Set())).toEqual({});
});
it('gives calls spoken delivery and visual results while keeping band facts grounded',()=>{
 expect(botDirections('band',true)).toContain('live voice call');expect(botDirections('band',true)).toContain('spokenText');expect(botDirections('band',true)).toContain('unknown tempos');expect(featureInstructions('semantic-search')).toContain('Never invent');expect(featureInstructions('chat-title')).toContain('not greetings');
});
it('meaning search ranks only existing records and cannot act or invoke web search',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'The concert discussion fits.',recordIds:['chat:band:one','invented'],actions:[{type:'delete',entityId:'chat:band:one',title:'Delete'}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{mode:'semantic-search',question:'We talked about songs for the next show',records:[{id:'chat:band:one',space:'band',kind:'note',title:'Concert plans'}]}},res);
 expect(res.statusCode).toBe(200);expect(res.body.recordIds).toEqual(['chat:band:one']);expect(res.body.actions).toEqual([]);const body=JSON.parse((fetcher.mock.calls[0] as any)[1].body);expect(body).not.toHaveProperty('tools');expect(body.generationConfig.maxOutputTokens).toBe(1400);
});
it('image generation returns image bytes only when the provider produced an image',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{inlineData:{mimeType:'image/png',data:'AQACAA=='}},{text:'A poster idea'}]}}]}))).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:'No picture'}]}}]})));vi.stubGlobal('fetch',fetcher);
 const result=await generateImage('test','A band poster');expect(result.images[0].mimeType).toBe('image/png');expect(result.text).toBe('A poster idea');await expect(generateImage('test','A second poster')).rejects.toThrow('no generated image');
});

it('dictated idea cleanup is read-only and cannot request cards or actions',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'I want to practice guitar tomorrow, if I have time.',recordIds:[],actions:[{type:'create',title:'Invented deadline',fields:{space:'personal',kind:'task',title:'Practice today'}}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{mode:'capture-polish',question:'Um I want to practice tomorrow, uh if I have time',scope:'personal',records:[]}},res);
 expect(res.statusCode).toBe(200);expect(res.body.actions).toEqual([]);expect(res.body.text).toContain('if I have time');const body=JSON.parse((fetcher.mock.calls[0] as any)[1].body);expect(body).not.toHaveProperty('tools');expect(body.generationConfig.responseJsonSchema).toBeUndefined();expect(featureInstructions('capture-polish')).toContain('Do not add facts');
});

it('keeps calls conversational until a visible result is explicitly requested',()=>{
 for(const text of ['Hello','I am thinking about our songs','I want to talk about my plan','What do you recommend?'])expect(requestsVoicePresentation(text)).toBe(false);
 for(const text of ['Show me the songs','Make me a list of songs','Give me a preview of Last Resort','Play Seven Nation Army'])expect(requestsVoicePresentation(text)).toBe(true);
});

it('record tools preserve uncertainty and require explicit review',()=>{
 for(const mode of ['record-polish','record-summary','record-plan','record-review']){
  const instructions=featureInstructions(mode);expect(instructions).toContain('selected supplied record');expect(instructions).toContain('Never invent');expect(instructions).toContain('actions: []');
 }
});

it('record AI suggestions cannot save, show unsolicited cards or invoke search',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'I may record guitar only if homework is finished.',recordIds:[],actions:[{type:'create',title:'Unrequested save',fields:{space:'personal',kind:'task',title:'Record today'}}],cards:[{type:'list',title:'Unrequested list',items:[{title:'Record today'}]}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{mode:'record-polish',question:'Improve this note',scope:'personal',records:[{id:'sample',space:'personal',kind:'note',title:'Guitar'}]}},res);
 expect(res.statusCode).toBe(200);expect(res.body.actions).toEqual([]);expect(res.body.cards).toBeUndefined();expect(JSON.parse((fetcher.mock.calls[0] as any)[1].body)).not.toHaveProperty('tools');
});

it('exercise description search accepts the catalogue and cannot invent or mutate exercises',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'The seated chest press matches that movement.',recordIds:['press','invented'],actions:[{type:'delete',entityId:'press',title:'Delete'}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 const records=[{id:'press',space:'gym',kind:'note',title:'Lever chest press'},...Array.from({length:901},(_,index)=>({id:'exercise-'+index,title:'Exercise '+index,space:'gym',kind:'note'}))];
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{mode:'exercise-search',scope:'gym',question:'The seated machine where I push forward',records}},res);
 expect(res.statusCode).toBe(200);expect(res.body.recordIds).toEqual(['press']);expect(res.body.actions).toEqual([]);const payload=JSON.parse((fetcher.mock.calls[0] as any)[1].body);expect(payload).not.toHaveProperty('tools');expect(payload.systemInstruction.parts[0].text).toContain('mechanical similarity');expect(botDirections('gym')).toContain('Gym Bot');expect(botDirections('band')).toContain('never offer Spotify');
});
it('client disconnection aborts a pending assistant provider request',async()=>{
 const token='a'.repeat(64);vi.stubEnv('GEMINI_API_KEY','test');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',token);
 let close:()=>void=()=>{};
 const fetcher=vi.fn((_url:any,options:any)=>new Promise((_resolve,reject)=>{options.signal.addEventListener('abort',()=>reject(new DOMException('Closed','AbortError')));queueMicrotask(()=>close())}));vi.stubGlobal('fetch',fetcher);
 const res={writableEnded:false,on(_event:string,cb:()=>void){close=cb},setHeader(){},status:vi.fn(),json:vi.fn()};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{scope:'personal',question:'Help me plan tomorrow',records:[]}},res);
 expect(fetcher).toHaveBeenCalledTimes(1);expect((fetcher.mock.calls[0] as any)[1].signal.aborted).toBe(true);expect(res.status).not.toHaveBeenCalled();
});
it('drawn music cards validate strings and fret ranges and trigger explicit presentation',()=>{
 const rows=['e','B','G','D','A','E'].map(title=>({title,detail:'0,-,2,-'}));
 const good=presentationReply({cards:[{type:'tablature',title:'Original practice',items:rows},{type:'chords',title:'Chord shapes',items:[{title:'Em',detail:'0,2,2,0,0,0'},{title:'Invalid span',detail:'0,1,12,0,0,0'}]}]},new Set());
 expect(good.cards).toHaveLength(2);expect(good.cards[1].items).toHaveLength(1);
 expect(presentationReply({cards:[{type:'tablature',title:'Broken',items:rows.map((r,i)=>({...r,detail:i===0?'99,-':'0,-,2,-'}))}]},new Set()).cards).toBeUndefined();
 expect(needsWebSearch('Find guitar tabs for Last Resort')).toBe(true);
 expect(requestsVoicePresentation('Generate a guitar tab')).toBe(true);
 expect(botDirections('band')).toContain('original practice');expect(botDirections('personal')).toContain('Avoid generic motivational speeches');
});

it('keeps private recall off the public web and grounds changing facts',()=>{
 for(const q of ['Find our saved guitar tabs','Search my previous school notes','We discussed the latest version in our saved notes'])expect(needsWebSearch(q)).toBe(false);
 for(const q of ['What is the latest version of iOS?','Find guitar tabs online','What is the weather today?'])expect(needsWebSearch(q)).toBe(true);
});
