import {it,expect} from 'vitest';
import {creationDraft,saveCreationDraft,saveCaptureDraft,captureDraft} from './db';
import {makeEntity} from './core';
it('typed creation drafts keep their fields and do not overwrite quick capture or another module',async()=>{
 await saveCaptureDraft({text:'Spontaneous thought',space:'auto',kind:'',due:''});const chapter=makeEntity({space:'moshia',kind:'chapter',title:'Chapter: literal title',data:{POV:'Narrator'}}),thread=makeEntity({space:'moshia',kind:'thread',title:'Thread'});
 await saveCreationDraft('moshia','chapter',chapter);await saveCreationDraft('moshia','thread',thread);expect((await creationDraft('moshia','chapter'))?.data.POV).toBe('Narrator');expect((await captureDraft())?.text).toBe('Spontaneous thought');await saveCreationDraft('moshia','chapter',null);expect(await creationDraft('moshia','chapter')).toBeUndefined();expect((await creationDraft('moshia','thread'))?.id).toBe(thread.id);
});
