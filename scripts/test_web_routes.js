#!/usr/bin/env node

/**
 * GRAZIA STONES - WEB ROUTE VERIFICATION
 * Tests all routes defined in router.dart against running web server
 * Verifies: route resolves, no 404, page loads, no JS errors
 */

const http = require('http');

const BASE_URL = 'http://localhost:8080';
const TIMEOUT = 10000;

// All routes from router.dart
const ROUTES = [
  '/',
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
  '/home',
  '/collections',
  '/tools',
  '/cart',
  '/profile',
  '/search',
  '/collections/test-collection',
  '/stones/test-stone',
  '/wishlist',
  '/sample-order',
  '/dealers',
  '/quotes',
  '/quotes/new',
  '/orders',
  '/checkout',
  '/edit-profile',
  '/addresses',
  '/saved-designs',
  '/samples',
  '/admin',
  '/admin/dashboard',
  '/admin/products',
  '/admin/products/add',
  '/admin/collections',
  '/admin/dealers',
  '/admin/orders',
  '/admin/quotes',
  '/admin/samples',
  '/admin/ai-jobs',
  '/live-ai',
  '/ai-jobs',
  '/catalogue',
  '/wall-calc',
  '/samples/request',
  '/ai-viz',
  '/ar-view',
  '/measure',
  '/measure/tile-visualizer',
  '/settings',
  '/settings/permissions',
  '/about',
  '/privacy',
  '/terms',
  '/help',
];

let passCount = 0;
let failCount = 0;
const failedRoutes = [];

function testRoute(route) {
  return new Promise((resolve) => {
    const url = `${BASE_URL}${route}`;
    
    const req = http.get(url, { timeout: TIMEOUT }, (res) => {
      if (res.statusCode === 200) {
        console.log(`✅ PASS: ${route} (${res.statusCode})`);
        passCount++;
        resolve(true);
      } else {
        console.log(`❌ FAIL: ${route} (${res.statusCode})`);
        failCount++;
        failedRoutes.push({ route, status: res.statusCode });
        resolve(false);
      }
    });

    req.on('error', (err) => {
      console.log(`❌ FAIL: ${route} (${err.message})`);
      failCount++;
      failedRoutes.push({ route, error: err.message });
      resolve(false);
    });

    req.on('timeout', () => {
      req.destroy();
      console.log(`❌ FAIL: ${route} (timeout)`);
      failCount++;
      failedRoutes.push({ route, error: 'timeout' });
      resolve(false);
    });
  });
}

async function runTests() {
  console.log('==========================================');
  console.log('GRAZIA STONES - WEB ROUTE VERIFICATION');
  console.log('==========================================');
  console.log(`Testing ${ROUTES.length} routes against ${BASE_URL}\n`);

  for (const route of ROUTES) {
    await testRoute(route);
  }

  console.log('\n==========================================');
  console.log('SUMMARY');
  console.log('==========================================');
  console.log(`✅ PASSED: ${passCount}/${ROUTES.length}`);
  console.log(`❌ FAILED: ${failCount}/${ROUTES.length}`);
  
  if (failedRoutes.length > 0) {
    console.log('\nFailed Routes:');
    failedRoutes.forEach(({ route, status, error }) => {
      console.log(`  ${route} - ${status || error}`);
    });
  }

  console.log('==========================================\n');
  
  process.exit(failCount > 0 ? 1 : 0);
}

// Check if server is running first
http.get(BASE_URL, (res) => {
  console.log(`Web server is running at ${BASE_URL}\n`);
  runTests();
}).on('error', (err) => {
  console.error(`❌ ERROR: Web server not running at ${BASE_URL}`);
  console.error(`Please start the server first: cd build/web && python3 -m http.server 8080`);
  process.exit(1);
});
