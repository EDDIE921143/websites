import React from 'react';
import {BookOpen,Compass} from 'lucide-react';
import {spaces} from './core';
export const dateLabel=(d?:string)=>d?new Date(d).toLocaleDateString(undefined,{month:'short',day:'numeric'}):'No date';
export const spaceOf=(id:string)=>spaces.find(s=>s.id===id)!;
export function Mark({space,size=''}:{space:string;size?:string}){const s=spaceOf(space);return <span className={'space-mark '+size} style={{background:s.color}}>{s.id==='ejj'?<span className="neutral-monogram">EJJ</span>:s.id==='school'?<BookOpen size={23}/>:s.id==='band'?<span className="band-mark">19</span>:s.mark}</span>}
export function Empty({icon:Icon=Compass,title,description,action}:{icon?:typeof Compass;title:string;description:string;action?:React.ReactNode}){return <div className="empty"><Icon size={30} strokeWidth={2.3}/><h3>{title}</h3><p>{description}</p>{action}</div>}
