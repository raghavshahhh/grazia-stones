#!/usr/bin/env node
// Updates the Google Play store listing (text, screenshots, icon, feature graphic). No app bundle upload.
//   node tool/play_listing.js dry     -> apply everything in an edit, validate, then DISCARD the edit
//   node tool/play_listing.js commit  -> apply, validate and commit (listing goes to Google review)
// Uses the shared service account at ~/.config/play-publisher/service-account.json (never committed).
const fs = require('fs'), path = require('path');
const { GoogleAuth } = require(require.resolve('google-auth-library', { paths: [
  '/Users/raghavshah/02_BUSINESS/03_CLIENTS/06_GENZ_RESTAURANT/website/backend/node_modules', __dirname, process.cwd()] }));
const PKG = 'com.graziastones.grazia_stones';
const ROOT = path.join(__dirname, '..', 'docs', 'store-listing');
const L = JSON.parse(fs.readFileSync(path.join(ROOT, 'play_listing_en-US.json')));
const api = (p) => `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/${p}`;
const upl = (p) => `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PKG}/${p}`;
const png = { 'Content-Type': 'image/png' };
(async () => {
  const mode = process.argv[2];
  if (!['dry', 'commit'].includes(mode)) throw new Error('usage: play_listing.js dry|commit');
  const c = await new GoogleAuth({ keyFile: path.join(process.env.HOME, '.config/play-publisher/service-account.json'),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'] }).getClient();
  const id = (await c.request({ url: api('edits'), method: 'POST', data: {} })).data.id;
  const drop = () => c.request({ url: api(`edits/${id}`), method: 'DELETE' }).catch(() => {});
  try {
    await c.request({ url: api(`edits/${id}/listings/en-US`), method: 'PUT', data: {
      language: 'en-US', title: L.title, shortDescription: L.short, fullDescription: L.full } });
    const sdir = path.join(ROOT, 'assets', 'screenshots');
    const shots = fs.readdirSync(sdir).filter((f) => f.endsWith('.png')).sort();
    await c.request({ url: api(`edits/${id}/listings/en-US/phoneScreenshots`), method: 'DELETE' });
    for (const f of shots) await c.request({ url: upl(`edits/${id}/listings/en-US/phoneScreenshots?uploadType=media`),
      method: 'POST', headers: png, body: fs.createReadStream(path.join(sdir, f)), maxBodyLength: Infinity });
    await c.request({ url: api(`edits/${id}/listings/en-US/icon`), method: 'DELETE' });
    await c.request({ url: upl(`edits/${id}/listings/en-US/icon?uploadType=media`), method: 'POST', headers: png,
      body: fs.createReadStream(path.join(ROOT, 'assets', 'play_icon_512.png')) });
    await c.request({ url: api(`edits/${id}/listings/en-US/featureGraphic`), method: 'DELETE' });
    await c.request({ url: upl(`edits/${id}/listings/en-US/featureGraphic?uploadType=media`), method: 'POST', headers: png,
      body: fs.createReadStream(path.join(ROOT, 'assets', 'feature_graphic_1024x500.png')) });
    await c.request({ url: api(`edits/${id}:validate`), method: 'POST', data: {} });
    console.log(`validated: ${shots.length} screenshots, icon, feature graphic, text`);
    if (mode === 'dry') { await drop(); console.log('dry run: edit discarded, nothing published'); return; }
    const done = await c.request({ url: api(`edits/${id}:commit`), method: 'POST', data: {} });
    console.log('COMMITTED', done.data.id);
  } catch (e) {
    console.log('FAILED', JSON.stringify(e.response?.data?.error || e.message).slice(0, 700));
    await drop(); process.exit(1);
  }
})();
