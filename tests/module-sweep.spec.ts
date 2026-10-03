import {test,expect} from '@playwright/test';
const catalog=[
 {space:'EJJ Digital',modules:[['Leads','lead','Business name'],['Websites','website','Title'],['Tasks','task','Title'],['Notes','note','Title'],['Ideas','idea','Idea title']]},
 {space:'CLEARANCE 19',modules:[['Songs','song','Song title'],['Rehearsals','rehearsal','Title'],['Practice','task','Title'],['Notes','note','Title'],['Ideas','idea','Idea title']]},
 {space:'Moshia',modules:[['Chapters','chapter','Chapter title'],['Characters','character','Character name'],['Plot threads','plot thread','Thread title'],['Locations','location','Location name'],['Organizations','organization','Title'],['Timeline','event','Title'],['Research','research','Research title'],['Ideas','idea','Idea title']]},
 {space:'School',modules:[['Homework','homework','Title'],['Tests','exam','Title'],['Subjects','subject','Title'],['Grades','grade','Title'],['Timetable','event','Title'],['Materials','note','Title']]},
 {space:'Personal',modules:[['Tasks','task','Title'],['Appointments','event','Title'],['Notes','note','Title'],['Ideas','idea','Idea title']]}
];
for(const {space,modules} of catalog)test('all '+space+' modules create, reopen, edit and retain their records',async({page})=>{
 await page.goto('/');await page.locator('.mobile-nav').getByRole('button',{name:'Spaces',exact:true}).click();await page.locator('.spaces-large').getByRole('button',{name:new RegExp(space)}).click();
 for(const [label,noun,titleLabel] of modules){
  await page.locator('.module-tabs').getByRole('button',{name:new RegExp('^'+label)}).click();
  await page.getByRole('button',{name:'Add '+noun,exact:true}).first().click();const sheet=page.getByRole('dialog');const name=space+' '+label+' sweep';
  await sheet.getByLabel(titleLabel,{exact:true}).fill(name);await sheet.getByRole('button',{name:'Add '+noun,exact:true}).click();await expect(sheet).toHaveCount(0);
  const record=page.getByRole('button',{name:new RegExp('^Open (Chapter \\d+: )?'+name+'$')});await expect(record).toBeVisible();await record.click();
  await page.getByRole('dialog').getByRole('textbox',{name:'Notes',exact:true}).fill('Verified '+label+' round trip');await page.getByRole('button',{name:'Save changes',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);await record.click();await expect(page.getByRole('dialog').getByRole('textbox',{name:'Notes',exact:true})).toHaveValue('Verified '+label+' round trip');await page.getByRole('button',{name:'Close dialog',exact:true}).click();
 }
 await page.reload();await page.locator('.mobile-nav').getByRole('button',{name:'Search',exact:true}).click();await page.getByPlaceholder('A person, a project, Friday…').fill('sweep');await expect(page.locator('main[data-page=search] .entity-row')).toHaveCount(modules.length);
});
