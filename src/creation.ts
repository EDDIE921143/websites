import {fields,type Kind} from './core';
export function creationSpec(space:string,kind:Kind){
 const research=space==='moshia'&&kind==='note';
 const noun=kind==='thread'?'plot thread':kind==='assignment'?'homework':research?'research':kind;
 const details=kind==='chapter'?['POV','purpose','location','storyDate','characters','plotThreads','wordCount']:research?['source','relatedChapter']:fields[kind]||[];
 const hints:Partial<Record<Kind,string>>={chapter:'Give this chapter a point of view and a reason to exist.',thread:'Keep the setup, development, and eventual payoff together.',location:'A place in the story, with its own context.',character:'Who they are, what they know, and what they keep to themselves.',idea:'A possibility to come back to. No task required.',song:'Keep the essentials ready for practice.',lead:'A relationship and its next step.',assignment:'What needs doing, and when it needs to be ready.'};
 return {noun,title:'Add '+noun,details,hint:research?'Keep a source, what you learned, and where it belongs.':hints[kind]||'Keep the useful details together.',titleLabel:kind==='chapter'?'Chapter title':kind==='character'?'Character name':kind==='location'?'Location name':kind==='lead'?'Business name':kind==='song'?'Song title':kind==='thread'?'Thread title':research?'Research title':kind==='idea'?'Idea title':'Title',bodyLabel:research?'Research notes':kind==='idea'?'The idea':kind==='location'?'Atmosphere & context':'Notes',section:kind==='chapter'?'In this chapter':kind==='thread'?'The thread':kind==='location'?'The place':research?'Sources & connections':'Details'};
}
export const fieldLabel=(key:string)=>key==='POV'?'Point of view':key==='BPM'?'BPM':key.replace(/([a-z])([A-Z])/g,'$1 $2').replace(/^./,v=>v.toUpperCase());
