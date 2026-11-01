// Renders assets/3d/aarna.glb into the small-avatar animations the app uses where a live WebGL view per avatar would be
// too heavy (chat bubbles, pills, cards). Every frame is the real 3D model, not artwork.
// Run: node tool/aarna_sprites/render.mjs   (then python3 tool/aarna_sprites/pack.py)
import puppeteer from "/Users/raghavshah/.nvm/versions/node/v22.22.3/lib/node_modules/puppeteer/lib/puppeteer/puppeteer.js";
import http from "node:http"; import fs from "node:fs"; import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname);
const app = path.resolve(here, "../..");
const frames = path.join(here, "frames");
const cfg = JSON.parse(fs.readFileSync(path.join(here, "shots.json"), "utf8"));

const files = {
  "/mv.js": path.join(app, "assets/3d/model-viewer.min.js"),
  "/aarna.glb": path.join(app, "assets/3d/aarna.glb"),
};
const page = `<!doctype html><meta charset=utf8><style>html,body{margin:0;background:transparent}model-viewer{width:100vw;height:100vh;--poster-color:transparent}</style>
<script type=module src="/mv.js"></script>
<model-viewer id=m src="/aarna.glb" exposure="${cfg.exposure}" environment-image="neutral" shadow-intensity="0" interaction-prompt="none"></model-viewer>`;
const srv = http.createServer((q, r) => {
  const f = files[q.url.split("?")[0]];
  if (!f) { r.writeHead(200, { "Content-Type": "text/html" }); return r.end(page); }
  r.writeHead(200, { "Content-Type": f.endsWith(".js") ? "text/javascript" : "model/gltf-binary" });
  fs.createReadStream(f).pipe(r);
}).listen(0);

const b = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "new",
  args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const pg = await b.newPage();
pg.on("pageerror", e => console.log("pageerror", String(e).slice(0, 200)));
await pg.goto(`http://localhost:${srv.address().port}/`);
await pg.waitForFunction(() => document.getElementById("m")?.loaded, { timeout: 120000 });

const only = process.env.ONLY?.split(",");
for (const s of cfg.shots.filter(s => !only || only.includes(s.name))) {
  const dir = path.join(frames, s.name);
  fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
  await pg.setViewport({ width: s.px, height: s.px, deviceScaleFactor: 1 });
  const n = Math.max(1, Math.round(s.dur * s.fps));
  for (let i = 0; i < n; i++) {
    await pg.evaluate(async (s, t) => {
      const m = document.getElementById("m");
      m.cameraOrbit = s.orbit; m.cameraTarget = s.target; m.fieldOfView = s.fov;
      m.animationCrossfadeDuration = 0; m.animationName = s.clip; m.play(); m.pause(); m.currentTime = t; m.jumpCameraToGoal();
      await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    }, s, (s.start || 0) + i / s.fps);
    await pg.screenshot({ path: path.join(dir, String(i).padStart(4, "0") + ".png"), omitBackground: true });
  }
  console.log("rendered", s.name, n, "frames");
}
await b.close(); srv.close();
