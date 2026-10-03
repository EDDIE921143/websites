import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server endpoint is JavaScript
import handler from '../api/assistant.js';
function response(){const result={statusCode:0,headers:{} as Record<string,string>,body:undefined as unknown,status(code:number){this.statusCode=code;return this},setHeader(key:string,value:string){this.headers[key]=value},json(body:unknown){this.body=body;return this}};return result}
const credential='a'.repeat(64);
function request(body:unknown,authorization='Bearer '+credential){return {method:'POST',headers:{host:'ediz-os.vercel.app',authorization},body}}
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals()});
it('rejects malformed mode and conversation fields without calling the provider',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);
 for(const body of [{mode:{},question:1},{question:'Hello',records:[],conversation:{}},{question:'Hello',records:[null]}]){const res=response();await handler(request(body),res);expect(res.statusCode).toBe(400)}
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
 const chat=response();await handler(request({question:'Hello',records:[]}),chat);expect(chat.statusCode).toBe(200);expect(fetcher.mock.calls[1][0]).toContain('gemini-3.1-flash-lite');
});

it('tries the next configured model after a transport timeout',async()=>{
 vi.stubEnv('GEMINI_API_KEY','test-key');vi.stubEnv('EDIZ_ASSISTANT_TOKEN',credential);vi.stubEnv('GEMINI_MODEL','gemini-3.8-flash');
 const fetcher=vi.fn().mockRejectedValueOnce(new DOMException('Timeout','TimeoutError')).mockResolvedValueOnce(new Response(JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({text:'Recovered reply',actions:[]})}]},finishReason:'STOP'}]})));vi.stubGlobal('fetch',fetcher);
 const res=response();await handler(request({question:'Hello',records:[]}),res);expect(res.statusCode).toBe(200);expect(fetcher).toHaveBeenCalledTimes(2);expect(res.headers['X-Ediz-Model']).toBe('gemini-3.8-flash');
});
