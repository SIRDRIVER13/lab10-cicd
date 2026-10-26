// Gateway: publiczne API, które pobiera dane z mikroserwisu catalog
const express = require('express');
const os = require('os');

function createApp({ catalogUrl, version }) {
  const app = express();
  app.disable('x-powered-by');

  async function fetchCatalog(path) {
    const res = await fetch(`${catalogUrl}${path}`, { signal: AbortSignal.timeout(3000) });
    return { status: res.status, body: await res.json() };
  }

  app.get('/', async (_req, res) => {
    let catalog = null;
    try {
      catalog = (await fetchCatalog('/health')).body.version;
    } catch {
      catalog = 'niedostępny';
    }
    res.json({ app: 'Shop API (mikroserwisy)', gateway: version, catalog, environment: process.env.APP_ENV || 'local', host: os.hostname() });
  });

  app.get('/health', async (_req, res) => {
    if (process.env.APP_BROKEN) {
      return res.status(503).json({ status: 'error', reason: 'APP_BROKEN', version });
    }
    try {
      const catalog = await fetchCatalog('/health');
      if (catalog.status !== 200) throw new Error('catalog unhealthy');
      return res.json({ status: 'ok', service: 'gateway', version, catalog: 'ok' });
    } catch {
      return res.status(503).json({ status: 'error', service: 'gateway', version, catalog: 'unreachable' });
    }
  });

  app.get('/api/products', async (_req, res) => {
    try {
      const { status, body } = await fetchCatalog('/products');
      res.status(status).json({ source: 'catalog', catalogVersion: body.version, items: body.items });
    } catch {
      res.status(502).json({ error: 'Serwis catalog nie odpowiada' });
    }
  });

  return app;
}

module.exports = { createApp };
