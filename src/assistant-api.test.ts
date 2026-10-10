import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server endpoint is JavaScript
import handler from '../api/assistant.js';
function response(){const result={statusCode:0,headers:{} as Record<string,string>,body:undefined as unknown,status(code:number){this.statusCode=code;return this},setHeader(key:string,value:string){this.headers[key]=value},json(body:unknown){this.body=body;return this}};return result}
const credential='a'.repeat(64);
function request(body:unknown,authorization='Bearer '+credential){return {method:'POST',headers:{host:'ediz-os.vercel.app',authorization},body}}
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals()});
it('rejects malformed mode and conversation fields without calling the provider',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 for(const body of [{mode:{},question:1},{mode:42,question:"Hello",records:[]},{mode:{},question:"Hello",records:[]},{question:'Hello',records:[],conversation:{}},{question:'Hello',records:[null]}]){const res=response();await handler(request(body),res);expect(res.statusCode).toBe(400)}
});
it('requires authentication before any speech stream starts',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const res=response();await handler(request({mode:'speech-stream',text:'Hello'},'Bearer invalid'),res);expect(res.statusCode).toBe(401);
});
it('rejects empty and oversized speech before opening an audio stream',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 for(const text of ['', 'x'.repeat(2001)]){const res=response();await handler(request({mode:'speech-stream',text}),res);expect(res.statusCode).toBe(400)}
});

it('uses the stronger model for media and the faster model for ordinary chat',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);vi.stubEnv('GEMINI_MODEL','gemini-3.8-flash');
 const fetcher=vi.fn(async(_url:string)=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'A checked reply',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const media=response();await handler(request({question:'Describe this recording',records:[],attachments:[{name:'practice.wav',mimeType:'audio/wav',data:'AQACAA=='}]}),media);expect(media.statusCode).toBe(200);expect(fetcher.mock.calls[0][0]).toContain('gemini-3.8-flash');
 const chat=response();await handler(request({question:'Hello',records:[]}),chat);expect(chat.statusCode).toBe(200);expect(fetcher.mock.calls[1][0]).toContain('gemini-3.5-flash-lite');
});

it('tries the next configured model after a transport timeout',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);vi.stubEnv('GEMINI_MODEL','gemini-3.8-flash');
 const fetcher=vi.fn().mockRejectedValueOnce(new DOMException('Timeout','TimeoutError')).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Recovered reply',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Hello',records:[]}),res);expect(res.statusCode).toBe(200);expect(fetcher).toHaveBeenCalledTimes(2);expect(res.headers['X-Ediz-Model']).toBe('gemini-3.8-flash');
});

it('recovers from a provider schema rejection while retaining JSON and action validation',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('{}',{status:400})).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Hello Ediz!',actions:[{type:'delete',recordId:'invented'}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({mode:'semantic-search',question:'Find a remembered chapter',scope:'band',records:[]}),res);
 expect(res.statusCode).toBe(200);expect(fetcher).toHaveBeenCalledTimes(2);
 const first=JSON.parse(fetcher.mock.calls[0][1].body),retry=JSON.parse(fetcher.mock.calls[1][1].body);
 expect(first.generationConfig.responseJsonSchema).toBeDefined();expect(retry.generationConfig.responseJsonSchema).toBeUndefined();expect(retry.generationConfig.responseMimeType).toBe('application/json');expect((res.body as any).actions).toEqual([]);
});

it('suppresses unsolicited cards and saved-item panels in ordinary conversation',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Hello Ediz!',recordIds:['saved'],cards:[{type:'songs',title:'Unrequested songs',items:[{title:'An unrelated song'}]}],actions:[]})}]},finishReason:'STOP'}]}))));
 const res=response();await handler(request({question:'Hello',scope:'band',records:[{id:'saved'}]}),res);
 expect(res.statusCode).toBe(200);expect((res.body as any).cards).toBeUndefined();expect((res.body as any).recordIds).toEqual([]);
});
it('returns bounded song suggestions and drops incomplete catalog entries',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Songs to explore',actions:[],songSuggestions:[{title:'Last Resort',artist:'Papa Roach',reason:'A focused guitar practice choice.'},null,{title:'Missing artist'}]})}]},finishReason:'STOP'}]}))));
 const res=response();await handler(request({mode:'song-recommendations',question:'Recommend 20 songs',scope:'band',records:[]}),res);expect(res.statusCode).toBe(200);expect((res.body as any).songSuggestions).toEqual([{title:'Last Resort',artist:'Papa Roach',reason:'A focused guitar practice choice.'}]);expect((res.body as any).actions).toEqual([]);
});
it('recovers through a stable Gemini model when the first models are unavailable',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);vi.stubEnv('GEMINI_MODEL','gemini-3.8-flash');
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('{}',{status:429})).mockResolvedValueOnce(new Response('{}',{status:404})).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Recovered reply',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Hello',scope:'personal',records:[]}),res);expect(res.statusCode).toBe(200);expect(res.headers['X-Ediz-Model']).toBe('gemini-3.7-flash');
});
it('passes prior messages in separate user and model roles',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Continue the band plan',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Continue',scope:'band',records:[],conversation:[{role:'user',text:'Plan a rehearsal'},{role:'assistant',text:'Start with a warm-up'}]}),res);
 const body=JSON.parse((fetcher.mock.calls[0] as any)[1].body);expect(body.contents.map((item:any)=>item.role)).toEqual(['user','model','user']);expect(body.contents[1].parts[0].text).toBe('Start with a warm-up');
});
it('reports a temporary provider overload instead of treating all failures as an app error',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({error:{message:'Temporarily busy'}}),{status:503})));
 const res=response();await handler(request({question:'Hello',records:[]}),res);expect(res.statusCode).toBe(503);expect(res.headers['Retry-After']).toBe('3');expect((res.body as any).error).toContain('message is saved');
});

it('never offers record mutations in response to a greeting',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Hello!',actions:[{type:'create',title:'Unasked task',fields:{space:'personal',kind:'task',title:'Call someone'}}]})}]},finishReason:'STOP'}]}))));
 const res=response();await handler(request({question:'Hello',scope:'personal',records:[]}),res);expect(res.statusCode).toBe(200);expect((res.body as any).actions).toEqual([]);
});

it('summarizing a corrected plan cannot create an unasked task',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Wednesday, 20 minutes.',actions:[{type:'create',title:'Practice',fields:{space:'personal',kind:'task',title:'Practice'}}]})}]},finishReason:'STOP'}]}))));
 const res=response();await handler(request({question:'Summarize the corrected plan.',scope:'personal',records:[]}),res);expect((res.body as any).actions).toEqual([]);
 const save=response();await handler(request({question:'Summarize the plan and save a task.',scope:'personal',records:[]}),save);expect((save.body as any).actions).toHaveLength(1);
});

it('recovers from empty, truncated and malformed successful provider responses',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 for(const bad of [{candidates:[]},{candidates:[{content:{parts:[{text:'{"text":"cut off'}]},finishReason:'MAX_TOKENS'}]},{candidates:[{content:{parts:[{text:'{"text":'}]},finishReason:'STOP'}]}]){
 const fetcher=vi.fn().mockResolvedValueOnce(new Response(JSON.stringify(bad))).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Recovered once',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Hello',records:[]}),res);expect(res.statusCode).toBe(200);expect((res.body as any).text).toBe('Recovered once');expect(fetcher).toHaveBeenCalledTimes(2);
 }
});
it('recovers once from a brief overload without changing models',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('{}',{status:503})).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Recovered',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Hello',records:[]}),res);expect(res.statusCode).toBe(200);expect(fetcher.mock.calls[0][0]).toBe(fetcher.mock.calls[1][0]);
});
it('blocks foreign records and cross-workspace creations at the API boundary',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'A story suggestion',actions:[{type:'create',title:'Foreign task',fields:{space:'ejj',kind:'task',title:'Business task'}},{type:'update',entityId:'foreign',title:'Foreign edit',fields:{body:'Changed'}}]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Review my story',scope:'moshia',records:[{id:'own',space:'moshia',body:'Story'},{id:'foreign',space:'ejj',body:'BUSINESS SECRET'}],memories:[{id:'foreign-chat',space:'ejj',title:'Client',body:'PRIVATE CLIENT'}]}),res);
 expect(res.statusCode).toBe(200);expect((res.body as any).actions).toEqual([]);
 expect((fetcher.mock.calls[0] as any)[1].body).not.toContain('BUSINESS SECRET');expect((fetcher.mock.calls[0] as any)[1].body).not.toContain('PRIVATE CLIENT');
});

it('confines Mentor Desk to the selected student and preserves student ownership on proposed edits',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 const student={id:'student-a',space:'tutoring',kind:'note',title:'Alex Example',body:'',data:{mentorType:'student',currentTopic:'Adding fractions',needsPractice:'Common denominators',strengths:'Equivalent fractions',nextStep:'Try independently'}};
 const note={id:'note-a',space:'tutoring',kind:'note',title:'Fractions',body:'STUDENT_A_ONLY',data:{studentID:'student-a',mentorType:'session'}};
 const other={id:'note-b',space:'tutoring',kind:'note',title:'Private',body:'STUDENT_B_SECRET',data:{studentID:'student-b'}};
 const fetcher=vi.fn(async(_url:string,options:any)=>{
  const payload=JSON.parse(options.body);
  if(payload.toolConfig)return new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:['student-a','note-a','note-b','school-note']}}}]}}]}));
  return new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Here is a next step to review.',actions:[{type:'update',entityId:'note-b',title:'Unsafe edit',fields:{body:'Changed'}},{type:'create',title:'Next lesson',fields:{space:'tutoring',kind:'task',title:'Practise fractions',data:{studentID:'student-b'}}}]})}]},finishReason:'STOP'}]}));
 });vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Plan the next lesson from my saved notes',scope:'tutoring',studentId:'student-a',records:[student,note,other,{id:'school-note',space:'school',kind:'note',body:'EDIZ_SCHOOL_SECRET'}],memories:[{id:'other-memory',title:'Other student chat',space:'tutoring',body:'OTHER_STUDENT_CHAT_SECRET',data:{studentID:'student-b'}}]}),res);
 expect(res.statusCode).toBe(200);expect(JSON.stringify(fetcher.mock.calls)).not.toContain('STUDENT_B_SECRET');expect(JSON.stringify(fetcher.mock.calls)).not.toContain('EDIZ_SCHOOL_SECRET');expect(JSON.stringify(fetcher.mock.calls)).not.toContain('OTHER_STUDENT_CHAT_SECRET');
 expect(JSON.stringify(fetcher.mock.calls.at(-1))).toContain('Common denominators');expect(JSON.stringify(fetcher.mock.calls.at(-1))).toContain('Equivalent fractions');expect(JSON.stringify(fetcher.mock.calls.at(-1))).toContain('Try independently');
 expect((res.body as any).actions).toHaveLength(1);expect((res.body as any).actions[0].fields.data.studentID).toBe('student-a');
});
