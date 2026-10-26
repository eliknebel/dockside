// Real HTTP/TLS peers for owned incremental streams; no cluster credentials.
import http from 'node:http';
import https from 'node:https';
import tls from 'node:tls';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn, execFileSync} from 'node:child_process';
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'dockside-stream-'));
const openssl = process.env.OPENSSL || 'openssl';
const generate = (name, host) => {
  const key = path.join(dir, `${name}.key`);
  const cert = path.join(dir, `${name}.pem`);
  execFileSync(openssl, ['req', '-x509', '-newkey', 'rsa:2048', '-nodes',
    '-keyout', key, '-out', cert, '-days', '1', '-subj', `/CN=${name} test CA`,
    '-addext', `subjectAltName=DNS:${host}`, '-addext', 'basicConstraints=critical,CA:TRUE'],
    { stdio: 'ignore' });
  const leafKey = path.join(dir, `${name}-leaf.key`);
  const csr = path.join(dir, `${name}.csr`);
  const leafCert = path.join(dir, `${name}-leaf.pem`);
  const ext = path.join(dir, `${name}.ext`);
  fs.writeFileSync(ext, `subjectAltName=DNS:${host}\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n`);
  execFileSync(openssl, ['req', '-newkey', 'rsa:2048', '-nodes', '-keyout', leafKey,
    '-out', csr, '-subj', `/CN=${host}`], {stdio: 'ignore'});
  execFileSync(openssl, ['x509', '-req', '-in', csr, '-CA', cert, '-CAkey', key,
    '-CAcreateserial', '-out', leafCert, '-days', '1', '-extfile', ext], {stdio: 'ignore'});
  return { key: fs.readFileSync(leafKey), cert: fs.readFileSync(leafCert), file: cert };
};
const servers = [], sockets = new Set(), timers = new Set();
let redirected = 0, never = 0, requests = 0;
const handshakes = new Set(), handshakeWaiters = [];
const later = (fn, ms) => {const timer = setTimeout(() => {timers.delete(timer); fn();}, ms); timers.add(timer); return timer;};
const listen = async (server, protocol) => {
  servers.push(server);
  server.on('connection', socket => {
    sockets.add(socket); socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
  });
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  return `${protocol}://localhost:${server.address().port}`;
};
function handler() {
  const active = new Map(), waiters = [];
  return (req,res) => {
    if (req.url === '/wait-handshake') {if(handshakes.size) res.end('ready'); else handshakeWaiters.push(res); return;}
    if (req.url === '/handshake-closed') {res.end(handshakes.size === 0 ? 'closed' : 'overlap');return;}
    if (req.url === '/redirected') {redirected++; res.end('wrong'); return;}
    if (req.url.startsWith('/wait/')) {
      const name=req.url.slice(6);
      if ([...active.values()].includes(name)) res.end('ready');
      else waiters.push({name,res});
      return;
    }
    if (req.url === '/closed') {res.end(active.size === 0 ? 'closed' : 'overlap'); return;}
    const url = new URL(req.url,'http://localhost');
    const name=url.searchParams.get('container');
    if (url.pathname !== '/api/v1/namespaces/test/pods/pod/log' ||
      url.searchParams.get('follow') !== 'true' ||
      url.searchParams.get('previous') !== 'false' ||
      url.searchParams.get('timestamps') !== 'true' ||
      url.searchParams.get('tailLines') !== '200' || url.searchParams.has('limitBytes')) {
      res.writeHead(400); res.end('bad query'); return;
    }
    requests++;
    active.set(req.socket,name);
    req.socket.on('close',()=>active.delete(req.socket));
    for(let i=waiters.length-1;i>=0;i--) if(waiters[i].name===name) waiters.splice(i,1)[0].res.end('ready');
    if(name==='never') {never++; res.end('wrong');}
    else if(name==='headers') { /* no response until cancellation/deadline */ }
    else if(name==='body') {res.writeHead(200);res.flushHeaders();}
    else if(name==='quiet') {res.writeHead(200);res.flushHeaders();later(()=>res.write('awake'),30500);}
    else if(name==='fragments') {res.writeHead(200);res.write('first');later(()=>res.write('second'),150);}
    else if(name==='denied' || name==='redirect') {
      res.writeHead(name==='denied'?403:302,{location:'/redirected'});res.write('private-upstream-error');
      const timer=setInterval(()=>res.write('private-upstream-error'),20);
      res.on('close',()=>clearInterval(timer));
    }
    else if(name==='container-a' || name==='container-b') {
      if(req.headers.authorization !== `Bearer ${name}`) {res.writeHead(401);res.end();}
      else res.end(name);
    }
    else res.end('finite body');
  };
}
function raw(socket) {
  socket.on('error',()=>{});
  let request='';
  const accept=bytes=>{
    request+=bytes.toString();
    if(!request.includes('\r\n\r\n')) return;
    socket.off('data',accept);
    const name=new URL(request.split(' ')[1],'http://localhost').searchParams.get('container');
    const prefix='HTTP/1.1 200 OK\r\nConnection: close\r\n';
    const chunked=prefix+'Transfer-Encoding: chunked\r\n\r\n';
    if(name==='encoding') socket.end(prefix+'Content-Encoding: gzip\r\nContent-Length: 0\r\n\r\n');
    else if(name==='ambiguous') socket.end(chunked.replace('Transfer-Encoding: chunked','Content-Length: 5\r\nTransfer-Encoding: chunked')+'5\r\nhello\r\n0\r\n\r\n');
    else if(name==='length') socket.end(prefix+'Content-Length: 5\r\n\r\nhello');
    else if(name==='eof') socket.end(prefix+'\r\nhello');
    else if(name==='split') {
      socket.write(chunked+'5;extension=yes\r');
      later(()=>{socket.write('\nhe');later(()=>{socket.write('llo\r');later(()=>socket.end('\n0\r\n\r\n'),10);},10);},10);
    }
    else if(name==='trailers') socket.end(chunked+'5\r\nhello\r\n0\r\nX-Test: yes\r\n\r\n');
    else if(name==='bad-size') socket.end(chunked+'zz\r\n');
    else if(name==='truncated') socket.end(chunked+'100\r\nabc');
    else if(name==='bad-crlf') socket.end(chunked+'3\r\nabcXX');
    else if(name==='long-size') socket.end(chunked+'a'.repeat(9000));
    else if(name==='long-trailer') socket.end(chunked+'0\r\nX: '+'a'.repeat(17000));
    else if(name==='large') {
      // Advertise 256 MiB, send only 8 MiB and remain open. No complete HTTP
      // chunk ever arrives; a whole-chunk parser cannot return the first byte.
      socket.write(chunked+'10000000\r\n');
      let sent=0;
      const timer=setInterval(()=>{
        if(socket.destroyed || sent>=8*1024*1024) {clearInterval(timer);return;}
        if(socket.writableLength<65536) {socket.write(Buffer.alloc(16384,97));sent+=16384;}
      },1);
      socket.on('close',()=>clearInterval(timer));
    } else socket.end(prefix+'Content-Length: 0\r\n\r\n');
  };
  socket.on('data',accept);
}
try {
  const trusted=generate('trusted','localhost'), wrong=generate('wrong','wrong.example');
  const httpUrl=await listen(http.createServer(handler()),'http');
  const tlsUrl=await listen(https.createServer(trusted,handler()),'https');
  const rawUrl=await listen(net.createServer(raw),'http');
  const rawTlsUrl=await listen(tls.createServer(trusted,raw),'https');
  const handshakeUrl=await listen(net.createServer(socket=>{
    socket.resume();handshakes.add(socket);socket.on('close',()=>handshakes.delete(socket));
    for(const waiter of handshakeWaiters.splice(0)) waiter.end('ready');
  }),'https');
  const wrongUrl=await listen(https.createServer(wrong,handler()),'https');
  const child=spawn('gleam',['run','-m','stream_integration'],{stdio:['ignore','pipe','pipe'],env:{...process.env,
    STREAM_HTTP_URL:httpUrl, STREAM_TLS_URL:tlsUrl, STREAM_RAW_URL:rawUrl, STREAM_RAW_TLS_URL:rawTlsUrl,
    STREAM_HANDSHAKE_URL:handshakeUrl, STREAM_WRONG_URL:wrongUrl, STREAM_CA:trusted.file, STREAM_WRONG_CA:wrong.file}});
  let output='';
  for(const stream of [child.stdout,child.stderr]) stream.on('data',bytes=>{output+=bytes;process.stdout.write(bytes);});
  const timer=setTimeout(()=>child.kill('SIGKILL'),80000);
  const code=await new Promise(resolve=>child.on('exit',resolve));clearTimeout(timer);
  if(code!==0) throw new Error(`Stream tests failed: ${code}`);
  if(output.includes('private-upstream-error')) throw new Error('Unsafe error body escaped');
  if(redirected || never) throw new Error('Redirect or unstarted request executed');
  if(sockets.size) throw new Error(`Retained ${sockets.size} sockets after exit`);
  console.log(`Stream fixture passed: ${requests} explicitly routed requests; zero retained connections.`);
} finally {
  for(const timer of timers) clearTimeout(timer);
  for(const socket of sockets) socket.destroy();
  for(const server of servers) {server.closeAllConnections?.();server.close();}
  fs.rmSync(dir,{recursive:true,force:true});
}
