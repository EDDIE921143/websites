import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server module
import {scopedItems,retrieveContext} from '../server/context-retrieval.js';
const records=[{id:'book',space:'moshia',title:'Chapter one',body:'PRIVATE BOOK'},{id:'business',space:'ejj',title:'Website project',body:'PRIVATE BUSINESS'}];
afterEach(()=>vi.unstubAllGlobals());
const args=(question:string,scope='all')=>({question,scope,records,briefs:[],memories:[],conversation:[],apiKey:'fake',signal:new AbortController().signal});
it('enforces workspace boundaries across records, briefs and chat memories',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:['book','business']}}}]}}]}))));
 expect(scopedItems(records,'moshia').map((x:any)=>x.id)).toEqual(['book']);
 const result=await retrieveContext({...args('Review my chapter','moshia'),briefs:[records[1]],memories:[records[1]]});
 expect(result.map((x:any)=>x.id)).toEqual(['book']);
});
it('does not retrieve saved context or call a tool for greetings and time questions',async()=>{
 const fetcher=vi.fn();vi.stubGlobal('fetch',fetcher);
 for(const question of ['Hello','Thanks!','What time is it?'])expect(await retrieveContext(args(question))).toEqual([]);
 expect(fetcher).not.toHaveBeenCalled();
});
it('executes a bounded context tool using metadata only and rejects invented IDs',async()=>{
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:['book','invented']}}}]}}]})));vi.stubGlobal('fetch',fetcher);
 const result=await retrieveContext(args('Review Moshia chapter one'));
 expect(result.map((x:any)=>x.id)).toEqual(['book']);
 const payload=(fetcher.mock.calls[0] as any)[1].body;
 expect(payload).not.toContain('PRIVATE BOOK');expect(payload).not.toContain('PRIVATE BUSINESS');expect(payload).toContain('read_saved_context');
});
it('fails closed rather than dumping every workspace after a retrieval outage',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>new Response('{}',{status:503})));
 expect(await retrieveContext(args('What did we plan?'))).toEqual([]);
});
it('keeps edited device context instead of overwriting it with a server brief',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:['book']}}}]}}]}))));
 const result=await retrieveContext({...args('Review my chapter','moshia'),briefs:[{...records[0],body:'Outdated brief'}]});
 expect(result[0].body).toBe('PRIVATE BOOK');
});
it('lets general questions request no personal context even with records available',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({candidates:[{content:{parts:[{functionCall:{name:'read_saved_context',args:{ids:[]}}}]}}]}))));
 expect(await retrieveContext(args('Explain why the sky looks blue','moshia'))).toEqual([]);
});
