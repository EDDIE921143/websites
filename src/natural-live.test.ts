import {it,expect,vi,afterEach} from 'vitest';
// @ts-expect-error server module
import {naturalLiveSpeech} from '../server/natural-live.js';
afterEach(()=>vi.unstubAllGlobals());
it('waits for setup and streams actual PCM using the selected voice',async()=>{
 const sent:any[]=[];
 class Socket extends EventTarget {
  constructor(_url:URL){super();queueMicrotask(()=>this.dispatchEvent(new Event('open')))}
  send(raw:string){const value=JSON.parse(raw);sent.push(value);queueMicrotask(()=>this.dispatchEvent(new MessageEvent('message',{data:JSON.stringify(value.setup?{setupComplete:{}}:{serverContent:{modelTurn:{parts:[{inlineData:{mimeType:'audio/pcm;rate=24000',data:'AQACAA=='}}]},turnComplete:true}})})))}
  close(){}
 }
 vi.stubGlobal('WebSocket',Socket);const chunks=[];for await(const bytes of naturalLiveSpeech('Hello Ediz.','test-key','Aoede'))chunks.push(bytes);
 expect([...chunks[0]]).toEqual([1,0,2,0]);expect(sent[0].setup.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName).toBe('Aoede');expect(sent[1].clientContent.turnComplete).toBe(true);
});
it('does not open a connection when the caller has cancelled',async()=>{
 const constructor=vi.fn();vi.stubGlobal('WebSocket',constructor);const signal=AbortSignal.abort();await expect((async()=>{for await(const _ of naturalLiveSpeech('Cancelled','key','Aoede',signal)){}})()).rejects.toThrow('Aborted');expect(constructor).not.toHaveBeenCalled();
});
