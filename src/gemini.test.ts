import {describe,it,expect} from 'vitest';
// @ts-expect-error server module is plain JavaScript
import {authorized,validateReply,workspaceContext} from '../server/gemini.js';
describe('Gemini boundary',()=>{
 it('requires the exact private device credential',()=>{expect(authorized('a'.repeat(64),'a'.repeat(64))).toBe(true);expect(authorized('b'.repeat(64),'a'.repeat(64))).toBe(false);expect(authorized(undefined,undefined)).toBe(false)});
 it('discards invented record edits and unsafe fields',()=>{const r=validateReply({text:'Review these',recordIds:['real','invented'],actions:[{type:'delete',entityId:'invented',title:'Delete'},{type:'update',entityId:'real',title:'Edit',fields:{title:'A title',id:'override',due:'bad date',data:{valid:'note',bad:42}}}]},[{id:'real'}]);expect(r.recordIds).toEqual(['real']);expect(r.actions).toHaveLength(1);expect(r.actions[0].fields).toEqual({title:'A title',data:{valid:'note'}})});
 it('requires valid typed creations',()=>{expect(validateReply({text:'Draft',actions:[{type:'create',title:'Create',fields:{space:'madeup',kind:'chapter',title:'X'}}]}).actions).toEqual([])});
});

it('workspace context excludes unrelated private space facts and handles invalid profiles',()=>{const profile=JSON.stringify({items:[{space:'ejj',kind:'note',body:'Business facts'},{space:'moshia',kind:'note',body:'Story facts'},{space:'personal',kind:'note',body:'Owner preferences'}]});expect(workspaceContext(profile,'moshia').map((e:{space:string})=>e.space)).toEqual(['moshia','personal']);expect(workspaceContext('bad json')).toEqual([])});
