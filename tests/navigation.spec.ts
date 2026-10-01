import {test,expect} from '@playwright/test';

test('app navigation restores module position and preserves live rows and assistant context',async({page})=>{
 await page.goto('/');await expect(page.getByRole('heading',{name:'Today',exact:true})).toBeVisible();
 // Isolated browser data only, never production owner data.
 await page.evaluate(async()=>{
  const database=await new Promise<IDBDatabase>((resolve,reject)=>{const r=indexedDB.open('ediz-os',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
  const tx=database.transaction('entities','readwrite');const now=new Date().toISOString();
  for(let i=0;i<160;i++)tx.objectStore('entities').put({id:'nav-'+i,space:'personal',kind:'task',title:'Navigation test '+i,body:'',status:'active',created:now,updated:now,data:{},duration:20});
  await new Promise<void>((resolve,reject)=>{tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error)});database.close();
 });await page.reload();
 await page.locator('.mobile-nav').getByRole('button',{name:'Spaces'}).click();await page.locator('.spaces-large').getByRole('button',{name:/Personal/}).click();
 await expect(page.locator('.entity-row')).toHaveCount(160);
 await page.locator('.content').evaluate(e=>e.scrollTop=1400);const before=await page.locator('.content').evaluate(e=>e.scrollTop);
 await page.locator('.mobile-nav').getByRole('button',{name:'Today'}).click();await expect.poll(()=>page.locator('.content').evaluate(e=>e.scrollTop)).toBe(0);
 await page.locator('.mobile-nav').getByRole('button',{name:'Spaces'}).click();await page.locator('.spaces-large').getByRole('button',{name:/Personal/}).click();
 await expect.poll(()=>page.locator('.content').evaluate(e=>e.scrollTop)).toBe(before);
 await page.locator('.content').evaluate(e=>e.scrollTop=0);
 await page.locator('.entity-row').first().evaluate(e=>(window as any).__stableRow=e);
 await page.getByRole('button',{name:'Open Navigation test 0',exact:true}).click();await expect(page.getByRole('dialog')).toBeVisible();
 expect(await page.evaluate(()=>(window as any).__stableRow===document.querySelector('.entity-row'))).toBe(true);
 await page.getByRole('button',{name:'Close dialog'}).click();expect(await page.evaluate(()=>document.scrollingElement!.scrollTop)).toBe(0);
 await page.locator('.mobile-nav').getByRole('button',{name:'Assistant'}).click();await page.getByRole('button',{name:'What matters today?'}).click();await expect(page.locator('.conversation-message')).toHaveCount(2);
 await page.locator('.mobile-nav').getByRole('button',{name:'Today'}).click();await page.locator('.mobile-nav').getByRole('button',{name:'Assistant'}).click();await expect(page.locator('.conversation-message')).toHaveCount(2);
});

test('screen chrome remains stationary while the work surface scrolls',async({page})=>{
 await page.goto('/');await expect(page.getByRole('heading',{name:'Today',exact:true})).toBeVisible();
 const header=await page.locator('.topbar').boundingBox(),dock=await page.locator('.mobile-nav').boundingBox();
 await page.locator('.content').evaluate(e=>e.scrollTop=900);
 expect((await page.locator('.topbar').boundingBox())!.y).toBe(header!.y);expect((await page.locator('.mobile-nav').boundingBox())!.y).toBe(dock!.y);
 await page.getByRole('button',{name:'Settings and backup'}).click();await expect(page.getByRole('heading',{name:'Settings',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Back',exact:true}).click();await expect(page.getByRole('heading',{name:'Today',exact:true})).toBeVisible();
});
