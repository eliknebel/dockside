// Local TLS fixture; no Kubernetes cluster or external service is required.
import https from 'node:https';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'dockside-tls-'));
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
let servers = [];
const stalledSockets = new Set();
try {
  const trusted = generate('trusted', 'localhost');
  const wrong = generate('wrong', 'wrong.example');
  const sockets = new Set();
  let redirected = 0;
  const serve = async (tls, handler) => {
    const server = https.createServer(tls, handler);
    servers.push(server);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    return `https://localhost:${server.address().port}`;
  };
  const target = await serve(trusted, (_req, res) => { redirected++; res.end('forwarded'); });
  const url = await serve(trusted, (req, res) => {
    if (req.url === '/redirect') { res.writeHead(302, {location: `${target}/stolen`}); res.end(); }
    else if (req.url === '/stall') { /* wait for client cancellation */ }
    else if (req.url === '/trickle') {
      res.writeHead(200); res.write('a');
      const timer = setInterval(() => res.write('a'), 20);
      res.on('close', () => clearInterval(timer));
    } else if (req.url === '/active') { res.end(String(sockets.size)); }
    else { res.end(req.headers.authorization === 'Bearer sentinel-private-token' ? 'ok' : 'missing auth'); }
  });
  servers[1].on('secureConnection', socket => {
    sockets.add(socket); socket.on('close', () => sockets.delete(socket));
  });
  const wrongUrl = await serve(wrong, (_req, res) => res.end('wrong host'));
  const handshake = net.createServer(socket => {
    stalledSockets.add(socket); socket.on('close', () => stalledSockets.delete(socket));
  });
  servers.push(handshake);
  await new Promise(resolve => handshake.listen(0, '127.0.0.1', resolve));
  const child = spawn('gleam', ['run', '-m', 'transport_integration'], {
    stdio: ['ignore', 'pipe', 'pipe'], env: {...process.env, TLS_URL: url, TLS_CA: trusted.file,
      TLS_WRONG_URL: wrongUrl, TLS_WRONG_CA: wrong.file, TLS_HANDSHAKE_URL: `https://localhost:${handshake.address().port}`},
  });
  let output = '';
  for (const stream of [child.stdout, child.stderr]) stream.on('data', chunk => {
    output += chunk.toString(); process.stdout.write(chunk);
  });
  const timer = setTimeout(() => child.kill('SIGKILL'), 60_000);
  const code = await new Promise(resolve => child.on('exit', resolve));
  clearTimeout(timer);
  if (code !== 0) throw new Error(`Transport tests failed: ${code}`);
  if (output.includes('sentinel-private-token')) throw new Error('Credential appeared in output');
  if (redirected !== 0) throw new Error('Redirect forwarded credentials');
  console.log('TLS, deadlines, caller cancellation, socket cleanup and redirect isolation passed.');
} finally {
  for (const server of servers) { server.closeAllConnections?.(); server.close(); }
  for (const socket of stalledSockets) socket.destroy();
  fs.rmSync(dir, {recursive: true, force: true});
}
