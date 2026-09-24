// Minimal CDP driver: open a file in a running Edge/Chromium, read a probe report, screenshot.
// Usage: node cdp.mjs <port> <fileUrl> [outPng]
import { writeFileSync } from 'node:fs';
import http from 'node:http';

const [portArg, targetUrl, outPng] = process.argv.slice(2);
const port = Number(portArg);

const getJson = (path) => new Promise((resolve, reject) => {
  http.get({ host: '127.0.0.1', port, path }, (res) => {
    let body = '';
    res.setEncoding('utf8');
    res.on('data', (c) => { body += c; });
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

const version = await getJson('/json/version');
const browserWs = version.webSocketDebuggerUrl;
if (!browserWs) throw new Error('no webSocketDebuggerUrl; is it headless with --remote-debugging-port?');

const ws = new WebSocket(browserWs);
await new Promise((resolve, reject) => {
  ws.addEventListener('open', resolve, { once: true });
  ws.addEventListener('error', (e) => reject(new Error('ws error ' + (e.message ?? ''))), { once: true });
});

let nextId = 1;
const pending = new Map();
const events = [];
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id !== undefined) {
    const slot = pending.get(msg.id);
    if (slot) { pending.delete(msg.id); slot(msg); }
  } else {
    events.push(msg);
  }
});
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = nextId++;
  pending.set(id, (msg) => (msg.error ? reject(new Error(method + ': ' + JSON.stringify(msg.error))) : resolve(msg.result)));
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});

const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
await send('Page.enable', {}, sessionId);
await send('Runtime.enable', {}, sessionId);
await send('Emulation.setDeviceMetricsOverride', { width: 914, height: 654, deviceScaleFactor: 1, mobile: false }, sessionId);
await send('Page.navigate', { url: targetUrl }, sessionId);

// wait for the page's own probe to finish (sets document.title = 'DONE')
const deadline = Date.now() + 20000;
let title = '';
while (Date.now() < deadline) {
  await new Promise((r) => setTimeout(r, 300));
  const res = await send('Runtime.evaluate', { expression: 'document.title', returnByValue: true }, sessionId);
  title = res.result?.value ?? '';
  if (title === 'DONE') break;
}

const report = await send('Runtime.evaluate', {
  expression: 'document.getElementById("report").textContent',
  returnByValue: true,
}, sessionId);
const state = await send('Runtime.evaluate', {
  expression: 'JSON.stringify({title: document.title, dpr: window.devicePixelRatio, inner: [innerWidth, innerHeight]})',
  returnByValue: true,
}, sessionId);

console.log('=== title/inner ===');
console.log(state.result?.value);
console.log('=== report ===');
console.log(report.result?.value ?? '(no report element)');

if (outPng) {
  const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false }, sessionId);
  writeFileSync(outPng, Buffer.from(shot.data, 'base64'));
  console.log('=== screenshot ===');
  console.log(outPng);
}

ws.close();
process.exit(0);
