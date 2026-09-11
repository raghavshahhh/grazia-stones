#!/usr/bin/env node

/**
 * Simple SPA server for testing Flutter web build
 * Serves index.html for all non-file routes (like Vercel does)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const WEB_DIR = path.join(__dirname, '..', 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
};

const server = http.createServer((req, res) => {
  let filePath = path.join(WEB_DIR, req.url === '/' ? 'index.html' : req.url);
  
  // Remove query params
  filePath = filePath.split('?')[0];

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // File doesn't exist - serve index.html for SPA routing
      filePath = path.join(WEB_DIR, 'index.html');
    }

    fs.readFile(filePath, (error, content) => {
      if (error) {
        res.writeHead(500);
        res.end(`Error loading file: ${error.code}`);
        return;
      }

      const ext = path.extname(filePath);
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';

      res.writeHead(200, { 
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*'
      });
      res.end(content);
    });
  });
});

server.listen(PORT, () => {
  console.log(`✅ SPA server running at http://localhost:${PORT}`);
  console.log(`📁 Serving: ${WEB_DIR}`);
  console.log(`🔄 All routes will serve index.html (Flutter handles routing)\n`);
});
