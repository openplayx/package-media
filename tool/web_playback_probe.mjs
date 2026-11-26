// Native browser/MSE feasibility probe (ALL-331). Uses a local Playwright
// installation: PLAYWRIGHT_MODULE=/path/to/playwright-core/index.mjs node ...
import {createServer} from 'node:http';
import {readFile,stat,mkdir,writeFile} from 'node:fs/promises';
import {resolve,extname,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../materials/playback/fixtures');
const report=resolve(process.argv[2] || '/tmp/opx-web-playback.json');
const server=createServer(async(req,res)=>{
 try {
  const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
  if(!path.startsWith(root+'/')){res.writeHead(403).end();return;}
  const data=await readFile(path);
  res.setHeader('Content-Type',({'.mp4':'video/mp4','.m3u8':'application/vnd.apple.mpegurl','.ts':'video/mp2t'})[extname(path)]||'application/octet-stream');
  res.setHeader('Accept-Ranges','bytes');
  const m=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range||'');
  if(m){let start=Number(m[1]),end=m[2]?Math.min(Number(m[2]),data.length-1):data.length-1;
   if(start>end){res.writeHead(416,{'Content-Range':`bytes */${data.length}`}).end();return;}
   res.writeHead(206,{'Content-Range':`bytes ${start}-${end}/${data.length}`,'Content-Length':end-start+1});res.end(data.subarray(start,end+1));
  }else{res.setHeader('Content-Length',data.length);res.end(data);}
 }catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{
 browser=await chromium.launch({executablePath:process.env.CHROME_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage();
 // Same-origin page without an external service or credentials.
 await page.goto(`http://127.0.0.1:${server.address().port}/common/baseline.mp4`);
 const result=await page.evaluate(async()=>{
  const types={h264_aac:'video/mp4; codecs="avc1.42E01E,mp4a.40.2"',hevc:'video/mp4; codecs="hvc1.1.6.L93.B0"',av1:'video/mp4; codecs="av01.0.04M.08"',vp9:'video/webm; codecs="vp9,opus"',hls:'application/vnd.apple.mpegurl'};
  const v=document.createElement('video');v.muted=true;document.body.append(v);
  const capabilities=Object.fromEntries(Object.entries(types).map(([k,t])=>[k,{native:v.canPlayType(t),mse:!!globalThis.MediaSource&&MediaSource.isTypeSupported(t)}]));
  const wait=(target,event)=>new Promise((ok,bad)=>{const timer=setTimeout(()=>bad(Error(event+' timeout')),12000);target.addEventListener(event,()=>{clearTimeout(timer);ok();},{once:true});target.addEventListener('error',()=>{clearTimeout(timer);bad(Error('media error '+(v.error?.code||'')));},{once:true});});
  const progress=async()=>{await v.play();await new Promise((ok,bad)=>{const end=performance.now()+10000;const poll=()=>v.currentTime>.35?ok():performance.now()>end?bad(Error('no playback progress')):setTimeout(poll,30);poll();});const before=v.currentTime;const seeking=wait(v,'seeked');v.currentTime=v.duration/2;await seeking;return {before,seek:v.currentTime,width:v.videoWidth,height:v.videoHeight,duration:v.duration,decodedFrames:v.getVideoPlaybackQuality().totalVideoFrames};};
  v.src='/common/baseline.mp4';await wait(v,'loadedmetadata');const native=await progress();v.pause();
  let hls;
  try {v.src='/advanced/web-hls/index.m3u8';await wait(v,'loadedmetadata');hls={status:'passed',...await progress()};v.pause();}
  catch(error){hls={status:'unavailable',reason:String(error)};}
  const media=new MediaSource();v.src=URL.createObjectURL(media);await wait(media,'sourceopen');
  const buffer=media.addSourceBuffer('video/mp4; codecs="avc1.42C01E,mp4a.40.2"');
  const bytes=await (await fetch('/advanced/web-fragmented.mp4')).arrayBuffer();const updated=wait(buffer,'updateend');buffer.appendBuffer(bytes);await updated;media.endOfStream();
  // MSE duration/metadata may be ready before sourcebuffer's updateend.
  if(!Number.isFinite(v.duration))await wait(v,'loadedmetadata');const mse=await progress();v.pause();
  return {capabilities,native,hls,mse};
 });
 result.browser=await browser.version();result.date=new Date().toISOString();result.platform=process.platform;result.status='passed';
 await mkdir(dirname(report),{recursive:true});await writeFile(report,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
}finally{await browser?.close();server.close();}
