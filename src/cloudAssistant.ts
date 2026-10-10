import {statuses,spaces,moduleKinds,type Entity} from './core';
export interface AssistantAction {type:'create'|'update'|'delete';title:string;entityId?:string;fields?:Partial<Entity>}
export interface CloudAnswer {text:string;recordIds:string[];actions:AssistantAction[];sources?:{url:string;title:string}[];searchSuggestions?:string|null}
export async function askGemini(question:string,items:Entity[],conversation:{role:string;text:string}[],token:string,scope='all'):Promise<CloudAnswer>{
 const body=JSON.stringify({question,scope,records:items.slice(0,500),conversation:conversation.slice(-8),localDate:new Date().toLocaleString('sv-SE'),timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone});
 for(let attempt=0;attempt<2;attempt++){
  let response:Response;
  try{response=await fetch('/api/assistant',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},signal:AbortSignal.timeout(80000),body})}
  catch(error){if(attempt===0&&error instanceof TypeError){await new Promise(resolve=>setTimeout(resolve,650));continue}throw error}
  const result=await response.json().catch(()=>null);
  if(attempt===0&&[502,503,504].includes(response.status)){await new Promise(resolve=>setTimeout(resolve,700));continue}
  if(!response.ok)throw new Error(result?.error||'The connection couldn’t finish. Your message is kept; try again shortly.');
  if(!result||typeof result.text!=='string')throw new Error('That reply couldn’t be read. Your saved data is unchanged.');
  return result;
 }
 throw new Error('The connection couldn’t finish. Please try again.');
}
export function actionDraft(action:AssistantAction,existing?:Entity):Partial<Entity>{
 const fields=action.fields||{},space=fields.space||existing?.space||'personal',kind=fields.kind||existing?.kind||'task';
 if(!spaces.some(s=>s.id===space)||!Object.values(moduleKinds).flat().some(k=>k.kind===kind))throw new Error('Unsupported suggestion');
 const status=fields.status||existing?.status||statuses(kind,space)[0];
 return {...existing,...fields,space,kind,data:{...existing?.data,...fields.data},status:statuses(kind,space).includes(status)?status:statuses(kind,space)[0]};
}
