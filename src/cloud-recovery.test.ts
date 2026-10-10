import {it,expect,vi,afterEach} from 'vitest';
import {askGemini} from './cloudAssistant';
afterEach(()=>vi.unstubAllGlobals());
it('browser recovers from a temporary HTML error page without duplicating the request content',async()=>{
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('<html>Busy</html>',{status:503})).mockResolvedValueOnce(new Response(JSON.stringify({text:'Recovered',recordIds:[],actions:[]})));vi.stubGlobal('fetch',fetcher);
 expect((await askGemini('Hello',[],[],'test')).text).toBe('Recovered');expect(fetcher.mock.calls[0][1].body).toBe(fetcher.mock.calls[1][1].body);
});
it('browser does not retry rejected credentials',async()=>{
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({error:'Connect first'}),{status:401}));vi.stubGlobal('fetch',fetcher);
 await expect(askGemini('Hello',[],[],'test')).rejects.toThrow('Connect first');expect(fetcher).toHaveBeenCalledTimes(1);
});
