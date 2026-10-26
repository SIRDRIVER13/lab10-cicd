const { createApp } = require('./app');

const port = Number(process.env.PORT || 8080);
const app = createApp({
  catalogUrl: process.env.CATALOG_URL || 'http://localhost:8000',
  version: process.env.APP_VERSION || 'dev',
});

const server = app.listen(port, () => console.log(`gateway nasłuchuje na porcie ${port}`));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
