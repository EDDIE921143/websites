import {chromium,devices} from '@playwright/test';
import {mkdir,writeFile} from 'node:fs/promises';
const browser=await chromium.launch({headless:true});const results=[];await mkdir('/tmp/ediz-qa',{recursive:true});
for(const [label,url] of [['before',process.env.EDIZ_BEFORE_URL],['after',process.env.EDIZ_TEST_URL||'http://localhost:4173']].filter(([,url])=>url)){
 const context=await browser.newContext({...devices['iPhone 13'],viewport:{width:402,height:874}}),page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(url);await page.getByRole('heading',{name:'Today',exact:true}).waitFor();
 await page.evaluate(async()=>{const db=await new Promise((resolve,reject)=>{const request=indexedDB.open('ediz-os',1);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});const tx=db.transaction('entities','readwrite');const now=new Date().toISOString();for(let i=0;i<500;i++)tx.objectStore('entities').put({id:'perf-'+i,title:'Performance fixture '+i,space:'personal',kind:'task',status:'active',created:now,updated:now,body:'',data:{},duration:20});await new Promise(resolve=>tx.oncomplete=resolve);db.close()});
 await page.reload();await page.getByRole('heading',{name:'Today',exact:true}).waitFor();await page.locator('.mobile-nav').getByRole('button',{name:'Spaces'}).click();await page.locator('.spaces-large').getByRole('button',{name:/Personal/}).click();await page.locator('.entity-row').first().waitFor();await page.waitForTimeout(350);
 const cdp=await context.newCDPSession(page);await cdp.send('Emulation.setCPUThrottlingRate',{rate:4});await cdp.send('Performance.enable');
 const initial=await cdp.send('Performance.getMetrics');
 const frames=await page.evaluate(()=>new Promise(resolve=>{const surface=getComputedStyle(document.querySelector('.content')).overflowY==='auto'?document.querySelector('.content'):document.scrollingElement;const frames=[];let previous=0;function tick(time){if(previous)frames.push(time-previous);previous=time;surface.scrollTop+=18;if(frames.length<120)requestAnimationFrame(tick);else resolve(frames)}requestAnimationFrame(tick)}));
 const final=await cdp.send('Performance.getMetrics');const metric=(name,data)=>data.metrics.find(m=>m.name===name)?.value||0;
 await cdp.send('Emulation.setCPUThrottlingRate',{rate:1});await page.evaluate(()=>{document.querySelector('.content').scrollTop=0;document.scrollingElement.scrollTop=0});await page.locator('.entity-row').first().evaluate(e=>window.__row=e);await page.getByRole('button',{name:'Open Performance fixture 0',exact:true}).click();
 const rowRetained=await page.evaluate(()=>window.__row===document.querySelector('.entity-row'));await page.getByRole('button',{name:'Close dialog'}).click();
 frames.sort((a,b)=>a-b);results.push({label,url,fixtureRows:500,cpuThrottle:4,frameP95Ms:Number(frames[Math.floor(frames.length*.95)].toFixed(2)),framesOver34Ms:frames.filter(v=>v>34).length,layoutCount:metric('LayoutCount',final)-metric('LayoutCount',initial),layoutDurationMs:Number(((metric('LayoutDuration',final)-metric('LayoutDuration',initial))*1000).toFixed(2)),rowRetained,errors});
 if(label==='after'){await page.locator('.mobile-nav').getByRole('button',{name:'Today'}).click();await page.waitForTimeout(250);await page.screenshot({path:'/tmp/ediz-qa/app-shell-phone.png'});await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:'/tmp/ediz-qa/app-shell-desktop.png'});}
 await context.close();
}
await browser.close();await writeFile('/tmp/ediz-qa/navigation-performance.json',JSON.stringify({note:'Headless Chromium with 4x CPU throttling; not physical iPhone or Safari frame-rate evidence.',results},null,2));console.log(JSON.stringify(results,null,2));
