import {useEffect,useRef,useState,type CSSProperties} from 'react';
import {House,Plus,Layers,Search,MessageCircle} from 'lucide-react';
const tabs=[{id:'today',label:'Today',icon:House},{id:'capture',label:'Capture',icon:Plus},{id:'spaces',label:'Spaces',icon:Layers},{id:'search',label:'Search',icon:Search},{id:'assistant',label:'Assistant',icon:MessageCircle}];
type Drag={origin:number;x:number;index:number;moved:boolean;left:number;step:number;pointer:number};
export function Dock({page,isSpace,go}:{page:string;isSpace:boolean;go:(page:string)=>void}){
 const current=Math.max(0,tabs.findIndex(t=>t.id===(isSpace?'spaces':page)));const [scrubbing,setScrubbing]=useState(false);
 const node=useRef<HTMLElement>(null),drag=useRef<Drag|null>(null),frame=useRef(0),suppressClick=useRef(false);
 const reset=()=>{cancelAnimationFrame(frame.current);frame.current=0;drag.current=null;setScrubbing(false);node.current?.style.removeProperty('--dock-offset');node.current?.style.removeProperty('--dock-lean');};
 useEffect(()=>()=>cancelAnimationFrame(frame.current),[]);
 function paint(){frame.current=0;const value=drag.current;if(!value||!node.current)return;const offset=Math.min(value.step*4,Math.max(0,value.x-value.left-value.step/2));node.current.style.setProperty('--dock-offset',`${offset}px`);node.current.style.setProperty('--dock-lean',`${Math.min(1,Math.max(-1,(value.x-value.origin)/100))}deg`)}
 return <nav ref={node} className={'mobile-nav'+(scrubbing?' scrubbing':'')} aria-label="Primary navigation" style={{'--dock-index':current} as CSSProperties}
 onPointerDown={e=>{if(e.button!==0||drag.current)return;const bounds=e.currentTarget.getBoundingClientRect();suppressClick.current=false;drag.current={origin:e.clientX,x:e.clientX,index:current,moved:false,left:bounds.left+7,step:(bounds.width-14)/5,pointer:e.pointerId};setScrubbing(true)}}
 onPointerMove={e=>{const value=drag.current;if(!value||value.pointer!==e.pointerId)return;value.x=e.clientX;if(Math.abs(value.x-value.origin)>5)value.moved=true;if(value.moved){if(!e.currentTarget.hasPointerCapture(e.pointerId))e.currentTarget.setPointerCapture(e.pointerId);value.index=Math.min(4,Math.max(0,Math.floor((value.x-value.left)/value.step)));if(!frame.current)frame.current=requestAnimationFrame(paint)}}}
 onPointerUp={e=>{const value=drag.current;if(!value||value.pointer!==e.pointerId)return;const target=value.index;if(value.moved)suppressClick.current=true;reset();if(e.currentTarget.hasPointerCapture(e.pointerId))e.currentTarget.releasePointerCapture(e.pointerId);if(value.moved)go(tabs[target].id)}}
 onPointerCancel={e=>{if(drag.current?.pointer===e.pointerId)reset()}} onContextMenu={e=>e.preventDefault()} onLostPointerCapture={()=>{if(drag.current)reset()}}
 onClickCapture={e=>{if(suppressClick.current){e.preventDefault();e.stopPropagation();suppressClick.current=false}}}>
 <div className="dock-selection" aria-hidden="true"/>{tabs.map((t,i)=><button key={t.id} className={current===i?'selected':''} aria-current={current===i?'page':undefined} onClick={()=>go(t.id)} onKeyDown={e=>{const next=e.key==='ArrowRight'?(i+1)%5:e.key==='ArrowLeft'?(i+4)%5:-1;if(next>=0){e.preventDefault();(e.currentTarget.parentElement?.querySelectorAll('button')[next] as HTMLButtonElement)?.focus();go(tabs[next].id)}}}><t.icon size={22}/><span>{t.label}</span></button>)}
 </nav>
}
