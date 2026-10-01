import {useEffect,useRef,useState} from 'react';
export function useMetronome(initial=100){
 const [playing,setPlaying]=useState(false),[bpm,setTempo]=useState(initial),[beat,setBeat]=useState(0),[error,setError]=useState('');
 const context=useRef<AudioContext|null>(null),scheduler=useRef<ReturnType<typeof setInterval>|null>(null),tempo=useRef(initial),pending=useRef(false),visualTimers=useRef<Set<ReturnType<typeof setTimeout>>>(new Set());
 function stop(){if(scheduler.current)clearInterval(scheduler.current);scheduler.current=null;for(const timer of visualTimers.current)clearTimeout(timer);visualTimers.current.clear();const current=context.current;context.current=null;current?.close().catch(()=>{});pending.current=false;setPlaying(false);setBeat(0)}
 function setBpm(value:number){const next=Math.min(240,Math.max(30,Math.round(value)||100));tempo.current=next;setTempo(next)}
 async function toggle(){if(context.current){stop();return}if(pending.current)return;pending.current=true;setError('');try{
  const Audio=window.AudioContext||(window as unknown as {webkitAudioContext:typeof AudioContext}).webkitAudioContext;if(!Audio)throw Error('Audio isn’t available in this browser.');
  // Create and resume directly in the button gesture, before any React effect.
  const audio=new Audio();context.current=audio;await audio.resume();if(context.current!==audio)return;if(audio.state!=='running')throw Error('Sound couldn’t start. Tap Start metronome again.');
  let next=audio.currentTime+.025,count=0;
  const schedule=()=>{if(context.current!==audio||audio.state!=='running')return;while(next<audio.currentTime+.12){const at=Math.max(next,audio.currentTime),position=count%4;const oscillator=audio.createOscillator(),gain=audio.createGain();oscillator.type='sine';oscillator.frequency.value=position===0?1200:850;gain.gain.setValueAtTime(.0001,at);gain.gain.exponentialRampToValueAtTime(.3,at+.002);gain.gain.exponentialRampToValueAtTime(.0001,at+.045);oscillator.connect(gain);gain.connect(audio.destination);oscillator.start(at);oscillator.stop(at+.055);oscillator.onended=()=>{oscillator.disconnect();gain.disconnect()};const timer=setTimeout(()=>{visualTimers.current.delete(timer);setBeat(position+1)},Math.max(0,(at-audio.currentTime)*1000));visualTimers.current.add(timer);count++;next=at+60/tempo.current;}}
  schedule();scheduler.current=setInterval(schedule,25);setPlaying(true);pending.current=false;
  audio.onstatechange=()=>{if(context.current===audio&&audio.state!=='running'){stop();setError('Sound paused. Tap Start metronome to resume.')}};
 }catch(e){stop();setError(e instanceof Error?e.message:'Sound couldn’t start. Please try again.')}}
 useEffect(()=>()=>{if(scheduler.current)clearInterval(scheduler.current);for(const timer of visualTimers.current)clearTimeout(timer);context.current?.close().catch(()=>{})},[]);
 return {playing,bpm,beat,error,setBpm,toggle};
}
