import {useRef,useState,type CSSProperties} from 'react';
import {House,Plus,Layers,Search,MessageCircle} from 'lucide-react';
const tabs=[{id:'today',label:'Today',icon:House},{id:'capture',label:'Capture',icon:Plus},{id:'spaces',label:'Spaces',icon:Layers},{id:'search',label:'Search',icon:Search},{id:'assistant',label:'Assistant',icon:MessageCircle}];
export function Dock({page,isSpace,go}:{page:string;isSpace:boolean;go:(page:string)=>void}){
 const current=Math.max(0,tabs.findIndex(t=>t.id===(isSpace?'spaces':page)));
 const [preview,setPreview]=useState<number|null>(null);
 const drag=useRef<{x:number;index:number;moved:boolean}|null>(null),suppressClick=useRef(false);
 const pick=(node:HTMLElement,x:number)=>{const bounds=node.getBoundingClientRect();return Math.min(4,Math.max(0,Math.floor((x-bounds.left-7)/(bounds.width-14)*5)))};
 return <nav className={'mobile-nav'+(preview!==null?' scrubbing':'')} aria-label="Primary navigation" style={{'--dock-index':preview??current} as CSSProperties}
 onPointerDown={e=>{if(e.button!==0)return;suppressClick.current=false;drag.current={x:e.clientX,index:current,moved:false};}}
 onPointerMove={e=>{if(!drag.current)return;if(Math.abs(e.clientX-drag.current.x)>8)drag.current.moved=true;if(drag.current.moved){if(!e.currentTarget.hasPointerCapture(e.pointerId))e.currentTarget.setPointerCapture(e.pointerId);drag.current.index=pick(e.currentTarget,e.clientX);setPreview(drag.current.index)}}}
 onPointerUp={e=>{if(drag.current?.moved){suppressClick.current=true;go(tabs[drag.current.index].id)}drag.current=null;setPreview(null);if(e.currentTarget.hasPointerCapture(e.pointerId))e.currentTarget.releasePointerCapture(e.pointerId)}}
 onPointerCancel={()=>{drag.current=null;setPreview(null)}}
 onClickCapture={e=>{if(suppressClick.current){e.preventDefault();e.stopPropagation();suppressClick.current=false}}}>
 <div className="dock-selection" aria-hidden="true"/>{tabs.map((t,i)=><button key={t.id} className={(preview??current)===i?'selected':''} aria-current={current===i?'page':undefined} onClick={()=>go(t.id)} onKeyDown={e=>{const next=e.key==='ArrowRight'?(i+1)%5:e.key==='ArrowLeft'?(i+4)%5:-1;if(next>=0){e.preventDefault();(e.currentTarget.parentElement?.querySelectorAll('button')[next] as HTMLButtonElement)?.focus();go(tabs[next].id)}}}><t.icon size={22}/><span>{t.label}</span></button>)}
 </nav>
}
