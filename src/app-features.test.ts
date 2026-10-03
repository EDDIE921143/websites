import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server modules are JavaScript
import {presentationReply,featureInstructions,generateImage,replySchema,needsWebSearch} from '../server/app-features.js';
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
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'We planned an acoustic warm-up.',recordIds:['memory'],actions:[{type:'update',entityId:'memory',title:'Edit remembered chat',fields:{body:'Changed'}}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res={statusCode:0,body:null as any,setHeader(){},status(code:number){this.statusCode=code;return this},json(body:any){this.body=body;return this}};
 await handler({method:'POST',headers:{host:'ediz-os.vercel.app',authorization:'Bearer '+token},body:{question:'What did we agree in our earlier rehearsal conversation?',scope:'band',records:[],memories:[{title:'Warm-up',space:'band',body:'Acoustic warm-up for five minutes.'},{title:'Private client',space:'ejj',body:'Business context'}]}},res);
 expect(res.statusCode).toBe(200);expect(res.body.actions).toEqual([]);expect(res.body.recordIds).toEqual([]);
 const request=JSON.parse((fetcher.mock.calls[0] as any)[1].body);const input=JSON.parse(request.contents[0].parts[0].text);
 expect(input.conversationMemory).toEqual([{title:'Warm-up',space:'band',body:'Acoustic warm-up for five minutes.',readOnly:true}]);expect(request.generationConfig.responseJsonSchema.required).toEqual(['text','recordIds','actions']);
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
 expect(res.statusCode).toBe(200);expect(res.body.actions).toEqual([]);expect(res.body.text).toContain('if I have time');const body=JSON.parse((fetcher.mock.calls[0] as any)[1].body);expect(body).not.toHaveProperty('tools');expect(body.generationConfig.responseJsonSchema.properties).not.toHaveProperty('cards');expect(featureInstructions('capture-polish')).toContain('Do not add facts');
});
