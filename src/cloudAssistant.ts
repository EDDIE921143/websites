import {statuses,spaces,moduleKinds,type Entity} from './core';
export interface AssistantAction {type:'create'|'update'|'delete';title:string;entityId?:string;fields?:Partial<Entity>}
export interface CloudAnswer {text:string;recordIds:string[];actions:AssistantAction[]}
export async function askGemini(question:string,items:Entity[],conversation:{role:string;text:string}[],token:string):Promise<CloudAnswer>{
 const response=await fetch('/api/assistant',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},signal:AbortSignal.timeout(55000),body:JSON.stringify({question,records:items.slice(0,500),conversation:conversation.slice(-8),localDate:new Date().toLocaleString('sv-SE'),timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone})});
 const result=await response.json();if(!response.ok)throw new Error(result.error||'Gemini is unavailable.');return result;
}
export function actionDraft(action:AssistantAction,existing?:Entity):Partial<Entity>{
 const fields=action.fields||{},space=fields.space||existing?.space||'personal',kind=fields.kind||existing?.kind||'task';
 if(!spaces.some(s=>s.id===space)||!Object.values(moduleKinds).flat().some(k=>k.kind===kind))throw new Error('Unsupported suggestion');
 const status=fields.status||existing?.status||statuses(kind,space)[0];
 return {...existing,...fields,space,kind,data:{...existing?.data,...fields.data},status:statuses(kind,space).includes(status)?status:statuses(kind,space)[0]};
}
