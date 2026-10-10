// Read-only Slack context. Requires a server-side bot token and explicit channel allowlist.
// Never reuse the user's connector token, expose credentials, or post to Slack.
let cached;
export async function slackContext({token=process.env.EDIZ_SLACK_BOT_TOKEN,channels=process.env.EDIZ_SLACK_CHANNEL_IDS,now=Date.now(),fetcher=fetch}={}){
 if(!token||!channels)return {status:'not_connected',messages:[]};
 const ids=[...new Set(channels.split(',').map(x=>x.trim()).filter(x=>/^[CG][A-Z0-9]{8,}$/.test(x)))].slice(0,6);
 if(!ids.length)return {status:'not_connected',messages:[]};
 const key=ids.join(',');
 if(cached?.key===key&&cached.token===token&&now-cached.at<86400000)return cached.value;
 const messages=[];let limited=false;
 try{
  const feeds=await Promise.all(ids.map(async channel=>{
   const url=new URL('https://slack.com/api/conversations.history');url.searchParams.set('channel',channel);url.searchParams.set('oldest',String((now-7*86400000)/1000));url.searchParams.set('limit','15');
   const response=await fetcher(url,{headers:{Authorization:'Bearer '+token},signal:AbortSignal.timeout(6000)});const result=await response.json();
   if(!response.ok||!result.ok)throw new Error('Read-only context unavailable');
   return {channel,result};
  }));
  for(const {channel,result} of feeds){
   limited ||= !!result.has_more;
   for(const item of result.messages||[]){if(item.bot_id||item.subtype||typeof item.text!=='string'||!/^\d+\.\d+$/.test(item.ts))continue;messages.push({channel,time:item.ts,text:item.text.slice(0,2000),url:`https://slack.com/archives/${channel}/p${item.ts.replace('.','')}`});}
  }
 }catch{return {status:'unavailable',messages:[]};}
 const value={status:'connected',fetchedAt:new Date(now).toISOString(),windowDays:7,limited,messages:messages.slice(0,60),readOnly:true};cached={key,token,at:now,value};return value;
}
