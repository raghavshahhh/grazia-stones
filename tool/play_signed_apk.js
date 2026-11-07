// Downloads the Play-signed universal APK for QA sideloads (same key as Play, so Play updates keep working).
// node tool/play_signed_apk.js com.graziastones.grazia_stones <versionCode> build
const path = require('path'), fs = require('fs');
const { GoogleAuth } = require(require.resolve('google-auth-library', { paths: ['/Users/raghavshah/02_BUSINESS/03_CLIENTS/06_GENZ_RESTAURANT/website/backend/node_modules'] }));
const [pkg, vc, out] = process.argv.slice(2);
const api = (p) => `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/${p}`;
(async () => {
  const c = await new GoogleAuth({ keyFile: path.join(process.env.HOME, '.config/play-publisher/service-account.json'), scopes: ['https://www.googleapis.com/auth/androidpublisher'] }).getClient();
  const list = (await c.request({ url: api(`generatedApks/${vc}`) })).data.generatedApks || [];
  const g = list[0]; if (!g) return console.log('none');
  console.log('universal:', !!g.generatedUniversalApk, 'signingKey:', g.certificateSha256Hash);
  if (out && g.generatedUniversalApk) {
    const r = await c.request({ url: api(`generatedApks/${vc}/downloads/${g.generatedUniversalApk.downloadId}:download`), params: { alt: 'media' }, responseType: 'arraybuffer' });
    fs.writeFileSync(path.join(out, `grazia-play-signed-vc${vc}.apk`), Buffer.from(r.data)); console.log('saved');
  }
})().catch((e) => { console.error('FAILED', JSON.stringify(e.response?.data?.error || e.message).slice(0, 300)); process.exit(1); });
