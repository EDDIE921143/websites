export function requestedSong(question){
 const match=question.trim().match(/^(?:hey[,!]?\s+)?(?:please\s+)?(?:give me (?:a )?preview of|can you (?:play|preview)|play|preview|spiel(?:e)?|spiele mir|hörprobe(?: von)?|play me)\s+(.+?)(?:\s+(?:please|bitte))?[.!?]*$/i);
 return match?.[1]?.replace(/^a preview of\s+/i,'').trim().slice(0,160)||null;
}
export async function musicPreview(query){
 const url=new URL('https://itunes.apple.com/search');url.search=new URLSearchParams({term:query,entity:'song',country:'DE',limit:'8'}).toString();
 const response=await fetch(url,{signal:AbortSignal.timeout(10000)});
 if(!response.ok)throw new Error('The music catalog couldn’t be reached. Try again shortly.');
 const result=await response.json();
 const songs=(result.results||[]).filter(item=>item.kind==='song'&&typeof item.previewUrl==='string'&&item.previewUrl.startsWith('https://')&&new URL(item.previewUrl).hostname.endsWith('.itunes.apple.com'));
 const normalize=value=>value.toLowerCase().replace(/[^\p{L}\p{N}]+/gu,' ').trim();
 const attribution=query.match(/^(.*)\s+by\s+(.+)$/i);const title=attribution?.[1]||query,artist=attribution?.[2];
 const wholeTitle=songs.find(item=>normalize(item.trackName)===normalize(query));
 const exact=songs.filter(item=>normalize(item.trackName)===normalize(title)&&(!artist||normalize(item.artistName)===normalize(artist)));
 const song=wholeTitle||(artist?exact[0]:(exact[0]||songs[0]));
 if(!song)return null;
 return {id:String(song.trackId),title:song.trackName,artist:song.artistName,audioURL:song.previewUrl,storeURL:song.trackViewUrl};
}
