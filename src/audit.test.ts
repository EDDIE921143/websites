import {describe,it,expect,vi,afterEach} from 'vitest';
import {makeEntity,rank,search} from './core';
import {continueItem,meaningfulUpdates,orderedSpaces} from './surfaces';
import {LocalProvider,localEndpoint} from './ai';
import {save,load,importItems,remove,files} from './db';
afterEach(()=>vi.unstubAllGlobals());
describe('focus is a preference, not a deadline filter',()=>{
 it('keeps imminent school deadlines above focused work and rejects discarded tasks',()=>{
 const now=new Date('2026-10-01T12:00:00Z');
 const exam=makeEntity({space:'school',kind:'exam',due:'2026-10-02T08:00:00Z',importance:1});
 const work=makeEntity({space:'moshia',importance:5,updated:'2026-08-01T12:00:00Z'});
 expect(rank([work,exam,makeEntity({status:'REJECTED'})],now,'moshia').map(r=>r.entity.id)).toEqual([exam.id,work.id]);
 });
 it('changes continuation and shortcuts using real recent work',()=>{
 const a=makeEntity({space:'personal'}),b=makeEntity({space:'moshia'});
 expect(continueItem([a,b],[{id:'1',entityId:b.id,title:b.title,action:'Created',at:b.created}],'moshia',a.id)?.id).toBe(b.id);
 expect(orderedSpaces('school')[0].id).toBe('school');
 });
 it('keeps imminent exams ahead of focused non-urgent updates',()=>{
 const now=new Date('2026-10-01T12:00:00Z');const thread=makeEntity({space:'moshia',kind:'thread',status:'CANON',updated:'2026-08-01T00:00:00Z'}),exam=makeEntity({space:'school',kind:'exam',due:'2026-10-02T08:00:00Z'});
 expect(meaningfulUpdates([thread,exam],'moshia',now)[0].id).toBe(exam.id);
 });
 it('ranks a title match ahead of an incidental mention',()=>{const body=makeEntity({title:'Research',body:'Nathaniel'}),title=makeEntity({title:'Nathaniel'});expect(search([body,title],'Nathaniel')[0].id).toBe(title.id)});
});
describe('data safety',()=>{
 it('rejects ID collisions without overwriting or partially importing',async()=>{const original=makeEntity({title:'Preserve original'});await save(original);await expect(importItems([makeEntity({title:'Should not import'}),{...original,title:'Conflicting title'}])).rejects.toThrow('conflicts');const records=(await load()).items;expect(records.find(e=>e.id===original.id)?.title).toBe(original.title);expect(records.some(e=>e.title==='Should not import')).toBe(false)});
 it('removes attachments and records a deletion together',async()=>{const e=makeEntity({title:'Delete safely'});await save(e,'Created');await remove(e.id);expect((await load()).items.some(r=>r.id===e.id)).toBe(false);expect((await load()).activity.some(a=>a.entityId===e.id&&a.action==='Deleted')).toBe(true);expect(await files(e.id)).toHaveLength(0)});
});
describe('honest local model connection',()=>{
 it('accepts private LAN URLs and rejects remote services or embedded credentials',()=>{expect(localEndpoint('http://192.168.1.2:1234/')).toBe('http://192.168.1.2:1234/v1');expect(()=>localEndpoint('https://cloud.example.com/v1')).toThrow();expect(()=>localEndpoint('http://secret@localhost:1234')).toThrow()});
 it('discovers and sends an actual model ID',async()=>{const fetcher=vi.fn().mockResolvedValueOnce({ok:true,json:async()=>({data:[{id:'loaded-model'}]})}).mockResolvedValueOnce({ok:true,json:async()=>({choices:[{message:{content:'A useful summary'}}]})});vi.stubGlobal('fetch',fetcher);expect(await new LocalProvider('http://localhost:1234').suggest('Summarize','shared')).toBe('A useful summary');expect(JSON.parse(fetcher.mock.calls[1][1].body).model).toBe('loaded-model')});
 it('never claims success for an empty model list or malformed response',async()=>{vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,json:async()=>({data:[]})}));await expect(new LocalProvider('http://localhost:1234').connect()).rejects.toThrow('no models')});
});
