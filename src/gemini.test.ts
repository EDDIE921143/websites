import {describe,it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server module is plain JavaScript
import {authorized,validateReply,workspaceContext,groundedSources,parseModelText,attachmentParts,wavFromPCM,botDirections,speechChunks,clearSpeechCache} from '../server/gemini.js';
describe('Gemini boundary',()=>{
 it('keeps natural replies but refuses broken structured output',()=>{expect(parseModelText('A natural answer.').text).toBe('A natural answer.');expect(parseModelText('[Source](https://example.com)').text).toBe('[Source](https://example.com)');expect(parseModelText('```json\n{"text":"Ready","actions":[]}\n```').text).toBe('Ready');expect(()=>parseModelText('{"text":"An unfinished')).toThrow('Incomplete structured reply');});
 it('includes imported chapter context only in its own workspace',()=>{const profile=JSON.stringify({items:[{space:'moshia',kind:'chapter',body:'Saved summary'},{space:'band',kind:'note',body:'Band context'}]});expect(workspaceContext(profile,'moshia')).toHaveLength(1);expect(workspaceContext(profile,'band').map((e:{kind:string})=>e.kind)).toEqual(['note']);});
 it('shows only distinct secure grounding sources from the provider',()=>{expect(groundedSources({groundingChunks:[{web:{uri:'https://example.com/news',title:'Verified source'}},{web:{uri:'https://example.com/news',title:'Duplicate'}},{web:{uri:'javascript:alert(1)',title:'Unsafe'}}]})).toEqual([{url:'https://example.com/news',title:'Verified source'}])});
 it('requires the exact private device credential',()=>{expect(authorized('a'.repeat(64),'a'.repeat(64))).toBe(true);expect(authorized('b'.repeat(64),'a'.repeat(64))).toBe(false);expect(authorized(undefined,undefined)).toBe(false)});
 it('discards invented record edits and unsafe fields',()=>{const r=validateReply({text:'Review these',recordIds:['real','invented'],actions:[{type:'delete',entityId:'invented',title:'Delete'},{type:'update',entityId:'real',title:'Edit',fields:{title:'A title',id:'override',due:'bad date',data:{valid:'note',bad:42}}}]},[{id:'real'}]);expect(r.recordIds).toEqual(['real']);expect(r.actions).toHaveLength(1);expect(r.actions[0].fields).toEqual({title:'A title',data:{valid:'note'}})});
 it('requires valid typed creations',()=>{expect(validateReply({text:'Draft',actions:[{type:'create',title:'Create',fields:{space:'madeup',kind:'chapter',title:'X'}}]}).actions).toEqual([])});
});

it('workspace context excludes unrelated private space facts and handles invalid profiles',()=>{const profile=JSON.stringify({items:[{space:'ejj',kind:'note',body:'Business facts'},{space:'moshia',kind:'note',body:'Story facts'},{space:'personal',kind:'note',body:'Owner preferences'}]});expect(workspaceContext(profile,'moshia').map((e:{space:string})=>e.space)).toEqual(['moshia','personal']);expect(workspaceContext('bad json')).toEqual([])});

 it('accepts Gemini media parts and reads text attachments without treating them as instructions',()=>{
  const image='iVBORw==';
  expect(attachmentParts([{name:'photo.png',mimeType:'image/png',data:image}])[1]).toEqual({inlineData:{mimeType:'image/png',data:image}});
  expect(attachmentParts([{name:'note.txt',mimeType:'text/plain',data:'S2VlcCB0aGlzIG5vdGUu'}])[0].text).toContain('Keep this note.');
 });
 it('rejects unsupported files, invalid encodings and oversized combined attachments',()=>{
  expect(()=>attachmentParts([{name:'app.exe',mimeType:'application/octet-stream',data:'YQ=='}])).toThrow();
  expect(()=>attachmentParts([{name:'bad.jpg',mimeType:'image/jpeg',data:'not base64!'}])).toThrow();
  expect(()=>attachmentParts([{name:'a.pdf',mimeType:'application/pdf',data:'YWFh'.repeat(500000)},{name:'b.pdf',mimeType:'application/pdf',data:'YWFh'.repeat(500000)}])).toThrow('2.5 MB');
 });

it('wraps mono PCM voice output in a playable WAV header',()=>{const wav=wavFromPCM(new Uint8Array([0,0,1,0]));expect(wav.toString('ascii',0,4)).toBe('RIFF');expect(wav.readUInt32LE(24)).toBe(24000);expect(wav.readUInt32LE(40)).toBe(4);expect(wav.length).toBe(48)});

it('passes recorded voice memos as audio to Gemini without changing their bytes',()=>{expect(attachmentParts([{name:'Voice memo.wav',mimeType:'audio/wav',data:'UklGRg=='}])[1]).toEqual({inlineData:{mimeType:'audio/wav',data:'UklGRg=='}})});

it('gives scoped bots useful directions without changing fiction or action boundaries',()=>{expect(botDirections('ejj')).toContain('EJJ Digital Bot');expect(botDirections('ejj')).toContain('€299');expect(botDirections('band')).toContain('CLEARANCE 19 Bot');expect(botDirections('moshia')).toContain('distinguish canon');expect(botDirections('moshia')).toContain('Ask before drafting');expect(botDirections('untrusted')).toContain('Everyday Bot');expect(botDirections('school',true)).toContain('one to three short sentences');});

afterEach(()=>{vi.unstubAllGlobals();clearSpeechCache();});
it('streams PCM immediately, keeps voice choice and reuses completed speech',async()=>{
 const event=JSON.stringify({candidates:[{content:{parts:[{inlineData:{mimeType:'audio/l16; rate=24000',data:'AQACAA=='}}]},finishReason:'STOP'}]});
 const fetcher=vi.fn(async(_url:string,_options:{body:string})=>new Response('data: '+event+'\n\n',{status:200}));vi.stubGlobal('fetch',fetcher);
 const parts=[];for await(const bytes of speechChunks('A unique streamed greeting','test-key','Puck'))parts.push(bytes);
 expect([...parts[0]]).toEqual([1,0,2,0]);expect(fetcher.mock.calls[0][0]).toContain('streamGenerateContent');
 expect(JSON.parse(fetcher.mock.calls[0][1].body).generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName).toBe('Puck');
 for await(const _ of speechChunks('A unique streamed greeting','test-key','Puck')){};expect(fetcher).toHaveBeenCalledTimes(1);
});
it('retries empty speech once and tries alternate models once on quota rejection',async()=>{
 const good='data: '+JSON.stringify({candidates:[{content:{parts:[{inlineData:{mimeType:'audio/l16',data:'AQACAA=='}}]},finishReason:'STOP'}]})+'\n\n';
 const fetcher=vi.fn().mockResolvedValueOnce(new Response('data: {}\n\n')).mockResolvedValueOnce(new Response(good));vi.stubGlobal('fetch',fetcher);
 const parts=[];for await(const b of speechChunks('Retry this empty response','test-key'))parts.push(b);expect(parts).toHaveLength(1);expect(fetcher).toHaveBeenCalledTimes(2);
 clearSpeechCache();fetcher.mockReset().mockResolvedValue(new Response('{}',{status:429}));
 await expect((async()=>{for await(const _ of speechChunks('Quota rejected','test-key')){}})()).rejects.toThrow('quota');expect(fetcher).toHaveBeenCalledTimes(5);expect(new Set(fetcher.mock.calls.map(call=>call[0])).size).toBe(5);
});
it('refuses truncated audio and keeps private speech caches isolated by credential',async()=>{
 const event=(finish:string)=>'data: '+JSON.stringify({candidates:[{content:{parts:[{inlineData:{mimeType:'audio/l16',data:'AQACAA=='}}]},finishReason:finish}]})+'\n\n';
 const fetcher=vi.fn(async()=>new Response(event('OTHER')));vi.stubGlobal('fetch',fetcher);
 await expect((async()=>{for await(const _ of speechChunks('Incomplete audio','key-one')){}})()).rejects.toThrow('interrupted');
 fetcher.mockReset().mockImplementation(async()=>new Response(event('STOP')));
 for await(const _ of speechChunks('Private cached reply','key-one')){};for await(const _ of speechChunks('Private cached reply','key-two')){};expect(fetcher).toHaveBeenCalledTimes(2);
});

it('samples video more frequently while keeping audio and image parts intact',()=>{const video=attachmentParts([{name:'practice.mp4',mimeType:'video/mp4',data:'AQACAA=='}])[1];expect(video).toEqual({inlineData:{mimeType:'video/mp4',data:'AQACAA=='},videoMetadata:{fps:4}});expect(attachmentParts([{name:'photo.png',mimeType:'image/png',data:'AQACAA=='}])[1]).not.toHaveProperty('videoMetadata')});

it('accepts common audio file formats without discarding the soundtrack',()=>{for(const mimeType of ['audio/mpeg','audio/mp4','audio/aac','audio/aiff','audio/flac','audio/ogg'])expect(attachmentParts([{name:'Recording',mimeType,data:'AQACAA=='}])[1]).toEqual({inlineData:{mimeType,data:'AQACAA=='}})});

vi.mock('../server/natural-live.js',()=>({naturalLiveSpeech:async function*(){throw new Error('Speech quota reached');}}));
