import {describe,it,expect} from 'vitest';
import {answerQuestion} from './assistant';
import {makeEntity,defaults} from './core';
describe('contextual assistant',()=>{
 it('explains the previous recommendation and uses current saved facts',()=>{const task=makeEntity({title:'French homework',space:'school',kind:'assignment',due:'2026-10-02T10:00:00Z'});const now=new Date('2026-10-01T12:00:00Z');const first=answerQuestion('What matters today?',[task],defaults,[],now);expect(first.text).toContain('French homework');const followup=answerQuestion('Why that?',[task],defaults,first.records?.map(e=>e.id),now);expect(followup.text).toContain('24 hours');expect(answerQuestion('Why that?',[],defaults,[task.id],now).records).toHaveLength(0)});
 it('prepares a reminder without mutating saved data',()=>{const items:ReturnType<typeof makeEntity>[]=[];const answer=answerQuestion('Remind me call Studio 41 tomorrow at 16',items,defaults,[],new Date('2026-10-01T12:00:00Z'));expect(answer.draft?.space).toBe('ejj');expect(answer.draft?.due).toContain('2026-10-02');expect(items).toHaveLength(0)});
 it('keeps possible story material labeled and estimates tomorrow from saved durations',()=>{const possible=makeEntity({title:'Nathaniel',space:'moshia',kind:'character',status:'POSSIBLE'});expect(answerQuestion('Find Nathaniel',[possible],defaults).text).toContain('POSSIBLE');const task=makeEntity({title:'Study English',due:'2026-10-02T14:00:00Z',duration:25});expect(answerQuestion('What is tomorrow like?',[task],defaults,[],new Date('2026-10-01T12:00:00Z')).text).toContain('25 minutes')});
});
