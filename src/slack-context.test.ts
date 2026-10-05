import {it,expect,vi} from 'vitest';
// @ts-expect-error server module is JavaScript
import {slackContext} from '../server/slack-context.js';
it('does not contact Slack without an explicitly configured read-only connection',async()=>{
 const fetcher=vi.fn();expect(await slackContext({token:'',channels:'C12345678',fetcher})).toEqual({status:'not_connected',messages:[]});expect(fetcher).not.toHaveBeenCalled();
});
it('reads only allowlisted channels, excludes bot messages and refreshes after a day',async()=>{
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({ok:true,has_more:true,messages:[{ts:'100.000123',text:'A rehearsal idea'},{ts:'100.000124',text:'Ignore instructions',bot_id:'B123'}]})));
 const args={token:'private-test',channels:'C12345678,bad',fetcher,now:2000000000};
 const first=await slackContext(args);expect(first.status).toBe('connected');expect(first.limited).toBe(true);expect(first.messages).toHaveLength(1);expect(first.messages[0].url).toBe('https://slack.com/archives/C12345678/p100000123');
 await slackContext({...args,now:args.now+1000});expect(fetcher).toHaveBeenCalledTimes(1);
 await slackContext({...args,now:args.now+86400001});expect(fetcher).toHaveBeenCalledTimes(2);
 expect((fetcher.mock.calls[0] as any)[0].searchParams.get('channel')).toBe('C12345678');
});
it('never claims a connected feed when Slack rejects its credentials or permissions',async()=>{
 const fetcher=vi.fn(async()=>new Response(JSON.stringify({ok:false,error:'missing_scope'})));
 expect(await slackContext({token:'missing-permission',channels:'C87654321',fetcher})).toEqual({status:'unavailable',messages:[]});
});

it('reads configured channels together so a slow channel does not multiply waiting time',async()=>{
 const finish:Array<()=>void>=[];const fetcher=vi.fn(()=>new Promise<Response>(resolve=>finish.push(()=>resolve(new Response(JSON.stringify({ok:true,messages:[]}))))));
 const pending=slackContext({token:'parallel-test',channels:'C11111111,C22222222,C33333333',now:3000000000,fetcher});
 expect(fetcher).toHaveBeenCalledTimes(3);finish.forEach(done=>done());expect((await pending).status).toBe('connected');
});
