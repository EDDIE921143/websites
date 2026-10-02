import {Plus,Upload,Calendar,SlidersHorizontal,ArrowUpRight,Layers} from 'lucide-react';
import {type ReactNode,type CSSProperties} from 'react';
import {spaces,type Entity,type Kind,type rank,moduleKinds,actionable} from './core';
import {Mark,dateLabel,spaceOf} from './primitives';
import {MeaningfulUpdates} from './modules';
type Ranked=ReturnType<typeof rank>;
const workspaceCopy:Record<string,{line:string;action:string;kind:Kind;empty:string}>={
 ejj:{line:'Relationships. Next steps. Good work.',action:'New lead',kind:'lead',empty:'No next actions saved here. Open your leads or capture the next conversation.'},
 band:{line:'Make some noise.',action:'Plan rehearsal',kind:'rehearsal',empty:'Your songs and rehearsal plans, together. Choose your setlist to get started.'},
 moshia:{line:'Back to the story.',action:'Start a chapter',kind:'chapter',empty:'A quiet place for the story. Open a chapter or follow a thread.'},
 school:{line:'One thing at a time.',action:'Plan homework',kind:'assignment',empty:'No school work needs attention. Your subjects and materials are still here.'},
 personal:{line:'A little room for yourself.',action:'Keep a thought',kind:'idea',empty:'Nothing asking for your attention here. Keep a thought or make a little space.'}
};
export function Today({greeting,priorities,items,upcoming,last,onCapture,onImport,onSpace,onReview,onOpen,onFocus,focus,onSelectFocus,onModule,onCreate,rows}:{greeting:string;priorities:Ranked;items:Entity[];upcoming:Entity[];last:Entity|null;onCapture:()=>void;onImport:()=>void;onSpace:(id:string)=>void;onReview:(period:'evening'|'weekly')=>void;onOpen:(e:Entity)=>void;onFocus:()=>void;focus:string;onSelectFocus:(id:string)=>void;onModule:(id:string,kind:Kind)=>void;onCreate:(id:string,kind:Kind)=>void;rows:(list:Entity[],priorityRows?:boolean)=>ReactNode}){
 const focused=focus!=='all',space=focused?spaceOf(focus):null,copy=space?workspaceCopy[focus]:null;
 const selected=focused?priorities.filter(p=>p.entity.space===focus):priorities;
 const material=items.filter(e=>e.space===focus&&!['done','REJECTED','archived','Lost'].includes(e.status));
 const recent=last&&(!focused||last.space===focus)?last:null;
 const schedule=upcoming.filter(e=>!focused||e.space===focus);
 const urgentElsewhere=focused?priorities.filter(p=>p.entity.space!==focus&&p.entity.due&&new Date(p.entity.due).getTime()<=Date.now()+86400000):[];
 const date=new Date();
 return <div className={'today-v2'+(focused?' workspace-focused':'')} style={{'--workspace-color':space?.color||'#b6afa1'} as CSSProperties}>
  <header className="day-heading"><div className="day-brand" aria-label="Ediz OS"><span className="e-mark"><i/><i/><i/></span></div><div><span className="day-date">{date.toLocaleDateString(undefined,{weekday:'long',month:'long',day:'numeric'})}</span><h1 aria-label="Today">{greeting}, Ediz</h1></div><button className="icon-button glass-control" aria-label="Change focus" onClick={onFocus}><SlidersHorizontal size={19}/></button></header>
  {focused&&space&&copy?<section className="workspace-stage" aria-label={'Focused on '+space.name}>
   <div className="workspace-stage-top"><span className="workspace-mode"><span/>IN FOCUS</span><button onClick={()=>onSelectFocus('all')} className="workspace-reset"><Layers size={15}/> All spaces</button></div>
   <div className="workspace-title"><Mark space={focus} size="large"/><h2>{space.name}</h2></div><p className="workspace-line">{copy.line}</p>
   <div className="workspace-launchers">{moduleKinds[focus].slice(0,3).map(m=><button key={m.kind} onClick={()=>onModule(focus,m.kind)}><span>{m.label}</span><ArrowUpRight size={16}/></button>)}</div>
   <button className="workspace-create" onClick={()=>onCreate(focus,copy.kind)}><Plus size={18}/>{copy.action}</button>
  </section>:<section className="workspace-choice" aria-label="Choose a workspace"><div className="section-title"><h2>Where do you want to be?</h2></div><div className="workspace-choice-list">{spaces.map(s=><button key={s.id} aria-label={'Focus on '+s.name} onClick={()=>onSelectFocus(s.id)}><Mark space={s.id}/><span><strong>{s.name}</strong><small>{s.description}</small></span><span className="workspace-choice-count">{items.filter(e=>e.space===s.id&&actionable(e)).length||'—'}</span></button>)}</div></section>}
  <div className="day-work"><section className="next-move"><div className="section-title"><h2>{focused?'Next in '+space!.name:'A few things that matter'}</h2>{selected.length>0&&<span className="muted">{Math.min(4,selected.length)} next steps</span>}</div>
  {selected.length?<><div className="grouped-list">{rows(selected.slice(0,4).map(p=>p.entity),true)}</div><details className="priority-reasons"><summary>Why these next steps?</summary>{selected.slice(0,4).map(p=><div key={p.entity.id}><strong>{p.entity.title}</strong><p>{p.reasons.join(' ')}</p></div>)}</details>{selected.length>4&&<details className="other-priorities"><summary>{selected.length-4} other next steps</summary>{rows(selected.slice(4).map(p=>p.entity))}</details>}</>:<div className="day-quiet"><p>{focused?copy!.empty:'Nothing pressing. Bring in your work, or choose a space above.'}</p>{focused&&material.length>0&&<button className="text-button" onClick={()=>onSpace(focus)}>Open your {material.length} saved {material.length===1?'item':'items'}<ArrowUpRight size={16}/></button>}</div>}
  {!focused&&<div className="next-actions"><button className="quiet" aria-label="Capture something" onClick={onCapture}><Plus size={18}/> Capture</button><button className="text-button" onClick={onImport}><Upload size={16}/> Import</button></div>}</section>
  {recent&&<section className="continue-section"><div className="section-title"><h2>Pick up where you left off</h2></div><button className="continue-panel" onClick={()=>onOpen(recent)}><Mark space={recent.space}/><div><h3>{recent.title}</h3><p>{recent.kind} · {recent.status}</p></div><ArrowUpRight size={17}/></button></section>}
  {schedule.length>0&&<section className="schedule"><div className="section-title"><h2>Coming up</h2></div><div className="agenda grouped-list">{schedule.map(e=><button key={e.id} onClick={()=>onOpen(e)}><span>{dateLabel(e.due)}<small>{new Date(e.due!).toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})}</small></span><div><strong>{e.title}</strong><small>{spaceOf(e.space).name}</small></div></button>)}</div></section>}
  <MeaningfulUpdates items={focused?items.filter(e=>e.space===focus):items} onOpen={onOpen} focus={focus}/>
  <div className="day-footer"><button onClick={()=>onReview('evening')}><Calendar size={17}/> Review today</button><button onClick={()=>onReview('weekly')}>This week<ArrowUpRight size={15}/></button></div>
  </div>
 </div>
}
