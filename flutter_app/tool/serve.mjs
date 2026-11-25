import http from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/web');
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.otf':'font/otf','.ttf':'font/ttf'};
const server=http.createServer(async(req,res)=>{
 try {
  const requested=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const target=path.resolve(root,'.'+(requested==='/'?'/index.html':requested));
  if(!target.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  const info=await stat(target);if(!info.isFile())throw Error('Not found');
  res.writeHead(200,{'Content-Type':types[path.extname(target)]??'application/octet-stream','Cache-Control':'no-store'});res.end(await readFile(target));
 }catch{res.writeHead(404);res.end('Arquivo não encontrado.');}
});
server.listen(5180,'127.0.0.1',()=>console.log('Centavus Flutter: http://localhost:5180'));
