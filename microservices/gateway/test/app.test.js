// Testy jednostkowe gateway: serwis catalog zastąpiony lokalną atrapą (stub)
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { createApp } = require('../src/app');

let stub;
let gateway;
let base;

before(async () => {
  stub = http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    if (req.url === '/health') return res.end(JSON.stringify({ status: 'ok', version: '9.9.9' }));
    if (req.url === '/products') return res.end(JSON.stringify({ version: '9.9.9', items: [{ id: 1, name: 'Test' }] }));
    res.statusCode = 404;
    res.end('{}');
  });
  await new Promise((r) => stub.listen(0, r));
  const app = createApp({ catalogUrl: `http://127.0.0.1:${stub.address().port}`, version: '1.0.0-test' });
  gateway = app.listen(0);
  await new Promise((r) => gateway.once('listening', r));
  base = `http://127.0.0.1:${gateway.address().port}`;
});

after(() => {
  gateway.close();
  stub.close();
});

test('GET / zwraca wersje gateway i catalog', async () => {
  const body = await (await fetch(`${base}/`)).json();
  assert.strictEqual(body.gateway, '1.0.0-test');
  assert.strictEqual(body.catalog, '9.9.9');
});

test('GET /api/products pobiera dane z catalog', async () => {
  const body = await (await fetch(`${base}/api/products`)).json();
  assert.strictEqual(body.source, 'catalog');
  assert.strictEqual(body.items.length, 1);
});

test('GET /health = 200 gdy catalog działa', async () => {
  assert.strictEqual((await fetch(`${base}/health`)).status, 200);
});

test('GET /health = 503 gdy wersja uszkodzona', async () => {
  process.env.APP_BROKEN = '1';
  try {
    assert.strictEqual((await fetch(`${base}/health`)).status, 503);
  } finally {
    delete process.env.APP_BROKEN;
  }
});
