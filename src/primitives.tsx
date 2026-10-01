import React from 'react';
import {BookOpen,Compass,PanelsTopLeft,AudioLines,GraduationCap,UserRound} from 'lucide-react';
import {spaces} from './core';
export const dateLabel=(d?:string)=>d?new Date(d).toLocaleDateString(undefined,{month:'short',day:'numeric'}):'No date';
export const spaceOf=(id:string)=>spaces.find(s=>s.id===id)!;
export function Mark({space,size=''}:{space:string;size?:string}){const s=spaceOf(space);const Icon=s.id==='ejj'?PanelsTopLeft:s.id==='band'?AudioLines:s.id==='moshia'?BookOpen:s.id==='school'?GraduationCap:UserRound;return <span className={'space-mark '+size} style={{color:s.color}} aria-hidden="true"><Icon size={24}/></span>}
export function Empty({icon:Icon=Compass,title,description,action}:{icon?:typeof Compass;title:string;description:string;action?:React.ReactNode}){return <div className="empty"><Icon size={30} strokeWidth={2.3}/><h3>{title}</h3><p>{description}</p>{action}</div>}
