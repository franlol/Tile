// Run with: node tests/run-aura-audit.cjs (from the addon directory).
// Test-only Lua VM and parser, pinned by version and SHA-256. Never loaded by WoW.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');

async function dependency(name, url, digest) {
  const file = path.join(os.tmpdir(), `mendframes-${name}-${digest}.js`);
  let source = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null;
  if (source === null) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${name}: HTTP ${response.status}`);
    source = await response.text();
  }
  if (crypto.createHash('sha256').update(source).digest('hex') !== digest) {
    throw new Error(`${name}: dependency checksum mismatch`);
  }
  fs.writeFileSync(file, source);
  const module = { exports: {} };
  new Function('module', 'exports', 'require', 'window', source)(module, module.exports, require, globalThis);
  return module.exports;
}

(async () => {
  const fengari = await dependency('fengari', 'https://unpkg.com/fengari-web@0.1.4/dist/fengari-web.js',
    'fbea0ee4b2e38840f96b03eb7ee162ae391127df26fccd000a2b8756535c8186');
  const parser = await dependency('luaparse', 'https://unpkg.com/luaparse@0.3.1/luaparse.js',
    '1c70940a6e46be63c84c285036925715f110bf06cbf058922372fb5c9d060b27');
  const toc = fs.readFileSync(path.join(root, 'MendFrames.toc'), 'utf8');
  const sources = toc.split(/\r?\n/).filter(line => /\.lua$/.test(line.trim()));
  for (const source of sources) {
    parser.parse(fs.readFileSync(path.join(root, source.replaceAll('\\', '/')), 'utf8'), { luaVersion: '5.1' });
  }
  const harness = fs.readFileSync(path.join(__dirname, 'aura-audit.lua'), 'utf8');
  const [setup, cases] = harness.split('-- LOAD_ADDON_HERE');
  if (!cases) throw new Error('Missing test insertion marker');
  const modules = ['Defaults.lua', 'AuraAudit.lua', 'NativeDispel.lua', 'Indicators.lua'];
  const core = fs.readFileSync(path.join(root, 'Core.lua'), 'utf8');
  const defaultsHelper = core.slice(core.indexOf('local function CopyDefaults'),
    core.indexOf('ns.CopyDefaults = CopyDefaults') + 'ns.CopyDefaults = CopyDefaults'.length);
  const previewModules = ['Media.lua', 'Frames.lua'];
  const previewTests = fs.readFileSync(path.join(__dirname, 'preview-colors.lua'), 'utf8');
  const program = setup + '\n' + defaultsHelper + modules.map(file =>
    `\n;(function(...)\n${fs.readFileSync(path.join(root, file), 'utf8')}\nend)('MendFrames', ns);\n`
  ).join('') + cases + previewModules.map(file =>
    `\n;(function(...)\n${fs.readFileSync(path.join(root, file), 'utf8')}\nend)('MendFrames', ns);\n`
  ).join('') + previewTests;
  fengari.load(program)();
  console.log(`PASS: Lua 5.1 syntax for all ${sources.length} files in the TOC`);
})().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
