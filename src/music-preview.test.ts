import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server module
import {requestedSong,musicPreview} from '../server/music-preview.js';
// @ts-expect-error server module
import {requestsPresentation} from '../server/app-features.js';
afterEach(()=>vi.unstubAllGlobals());
it('requires an explicit request before showing generated results',()=>{
 expect(requestsPresentation('Hello')).toBe(false);expect(requestsPresentation('I practiced guitar yesterday')).toBe(false);expect(requestsPresentation('I practiced songs yesterday')).toBe(false);
 expect(requestsPresentation('Make me a rehearsal plan')).toBe(true);expect(requestsPresentation('Add another one',[{role:'user',text:'Suggest songs for rehearsal'}])).toBe(true);
});
it('recognizes direct music requests without treating a discussion as playback',()=>{expect(requestedSong('Hey, play Seven Nation Army')).toBe('Seven Nation Army');expect(requestedSong('I want to practice Seven Nation Army')).toBeNull()});
it('uses an actual exact catalog match and only its trusted preview URL',async()=>{
 vi.stubGlobal('fetch',vi.fn(async()=>new Response(JSON.stringify({results:[{kind:'song',trackName:'Other song',artistName:'Other',previewUrl:'https://attacker.example/track'},{kind:'song',trackId:123,trackName:'Seven Nation Army',artistName:'The White Stripes',previewUrl:'https://audio-ssl.itunes.apple.com/preview.m4a',trackViewUrl:'https://music.apple.com/track/123'}]}))));
 const result=await musicPreview('Seven Nation Army');expect(result.artist).toBe('The White Stripes');expect(result.id).toBe('123');
});
