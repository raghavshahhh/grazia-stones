import puppeteer from "/Users/raghavshah/.nvm/versions/node/v22.22.3/lib/node_modules/puppeteer/lib/puppeteer/puppeteer.js";
import http from "node:http"; import fs from "node:fs"; import path from "node:path";
const root = path.dirname(new URL(import.meta.url).pathname);
const srv = http.createServer((q, r) => { const f = path.join(root, decodeURIComponent(q.url.split("?")[0])); fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { "Content-Type": f.endsWith(".js") ? "text/javascript" : f.endsWith(".html") ? "text/html" : "application/octet-stream" }); r.end(d); } }); }).listen(0);
const port = srv.address().port;
const shots = JSON.parse(process.argv[2]);           // [{name, clip, t, orbit?, w?, h?}]
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new", args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const pg = await b.newPage(); pg.on("console", m => { const t = m.text(); if (/error|warn/i.test(t)) console.log("page:", t.slice(0, 200)); }); pg.on("pageerror", e => console.log("pageerror", String(e).slice(0, 200)));
await pg.setViewport({ width: 900, height: 900 });
await pg.goto(`http://localhost:${port}/preview.html`);
await pg.waitForFunction(() => { const m = document.getElementById("m"); return m && m.loaded; }, { timeout: 60000 });
console.log("clips:", await pg.evaluate(() => document.getElementById("m").availableAnimations.join(",")));
for (const s of shots) {
  await pg.setViewport({ width: s.w || 900, height: s.h || 900 });
  await pg.evaluate(async (s) => { const m = document.getElementById("m"); if (s.orbit) m.cameraOrbit = s.orbit; if (s.target) m.cameraTarget = s.target; if (s.fov) m.fieldOfView = s.fov; m.animationCrossfadeDuration = 0; m.animationName = s.clip; m.play(); await new Promise(r => setTimeout(r, 300)); m.pause(); m.currentTime = s.t; m.jumpCameraToGoal(); await new Promise(r => setTimeout(r, 700)); }, s);
  if (s.transparent) await pg.evaluate(() => { document.body.style.background = 'transparent'; document.documentElement.style.background = 'transparent'; const m = document.getElementById('m'); m.setAttribute('shadow-intensity', '0'); document.querySelector('.bar').style.display = 'none'; }); await pg.screenshot({ path: path.join(root, "out", s.name + ".png"), omitBackground: !!s.transparent }); console.log("shot", s.name);
}
await b.close(); srv.close();
