#!/usr/bin/env python3
"""Generates lib/core/data/catalogue_specs.dart from the client's catalogue CSVs.

The stones table has no size / thickness / sqft-per-box / pieces values, so the
app fills them from the client's PDFs. The CSVs (outside this repo, in
../catalogue-import) were extracted from those PDFs and spot-checked by eye.

Usage: python3 scripts/gen_catalogue_specs.py [csv_dir]
"""
import csv, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
CSV_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'catalogue-import')
OUT = os.path.join(HERE, '..', 'lib', 'core', 'data', 'catalogue_specs.dart')
AR_DIR = os.path.join(HERE, '..', 'assets', 'ar_textures')


def norm(s):
    s = s.lower()
    s = re.sub(r'\b(series|collection|ledge)\b', '', s)
    return re.sub(r'\s+', ' ', s).strip()


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


def opt_str(s):
    return dart_str(s) if s else 'null'


def opt_num(v):
    return 'null' if v is None else repr(v)


def mm_pair(text):
    """'600x 1200 mm.' / '30 x 30 cm.' / '490x195x35' -> display 'A × B mm' or None."""
    t = text.replace('х', 'x').replace('×', 'x').lower()
    if '/' in t or ',' in t or text.count('x') > 2:
        return None  # several sizes in one string: leave blank rather than guess
    m = re.search(r'(\d+(?:\.\d+)?)\s*x\s*(\d+(?:\.\d+)?)', t)
    if not m:
        return None
    a, b = float(m.group(1)), float(m.group(2))
    if 'cm' in t:
        a, b = a * 10, b * 10
    f = lambda v: str(int(v)) if v == int(v) else str(v)
    return f'{f(a)} × {f(b)} mm'


def thick(text):
    t = text.lower().replace(' ', '')
    m = re.search(r'(\d+)-?(\d+)?(mm|cm)', t)
    if not m:
        return None
    unit = 'mm'  # the PDF's one "15 cm." is a typo for 15 mm (every other panel is 15-35 mm)
    return f'{m.group(1)}-{m.group(2)} {unit}' if m.group(2) else f'{m.group(1)} {unit}'


def rd(name):
    with open(os.path.join(CSV_DIR, name + '.csv'), newline='') as f:
        return list(csv.DictReader(f))


# ── Cultured series (Ledge / Design Surface / Brick / CNC) ───────────────────
# ponytail: patch height = real height of the catalogue photo, ESTIMATED by
# counting stone courses against the PDF tile size; refine on a real device.
SERIES_PATCH_M = {
    'grande': 1.3, 'country': 1.1, 'mountain': 1.1, 'classic': 0.9, 'opus': 1.2, 'vantage': 1.0,
    'rockface linear': 1.0, 'castle': 0.55, 'cuarzo': 1.25, 'venetian': 1.3, 'andorra': 1.3,
    'european stack': 0.9, 'veines': 1.0, 'travertine': 1.0, 'sleepwood': 1.3, 'sierra': 0.8,
    'fossile rock': 0.35, 'tevoli': 0.9, 'rustic brick': 0.56, 'tarnished brick': 0.6,
    'colonial brick': 0.65, 'lakhori brick': 0.6, 'florentine': 1.1, 'foliage': 0.6, 'flora': 0.6,
    'vine': 0.8, 'hexa': 0.7, 'modena': 0.9, 'cave': 1.0, 'egyptian': 0.35, 'weave': 0.75,
    'milano': 0.6, 'alpine': 0.9,
}
# CSV series name (normalized) -> app catalogue key (DB names differ in spelling)
ALIAS = {'venecia': 'venetian', 'andorra': 'andorra', 'travertino': 'travertine',
         'sleeper wood': 'sleepwood', 'fossil rock': 'fossile rock', 'tivoli': 'tevoli',
         'rockface linear': 'rockface linear'}

series = {}
for r in rd('cultured_series'):
    key = ALIAS.get(norm(r['series']), norm(r['series']))
    if key == 'rockface':
        continue  # plain Rockface is hidden in the app (client chose Linear)
    first = (r['sizes_mm_LxWxT'] or '').split(';')[0].strip()
    m = re.match(r'(\d+)x(\d+)x(\d+)', first)
    sqft = None
    try:
        sqft = float(r['sqft_per_box'])
    except ValueError:
        pass
    series[key] = dict(
        size=f'{m.group(1)} × {m.group(2)} mm' if m else None,
        thickness=f'{m.group(3)} mm' if m else None,
        sqft=sqft,
    )
# values the PDF extraction left blank are filled from the app's older hard-coded
# collection specs (checked equal to the PDF for every series that has both)
APP_FALLBACK = {'classic': (11.40, '340 × 100 mm', '20 mm'), 'castle': (6.60, '305 × 165 mm', '25 mm'),
                'sierra': (6.50, None, '35 mm'), 'fossile rock': (5.50, None, '50 mm'),
                'opus': (7.35, None, '30 mm'), 'european stack': (5.75, None, '35 mm')}
for k, (sq, sz, th) in APP_FALLBACK.items():
    d = series.setdefault(k, dict(size=None, thickness=None, sqft=None))
    d['sqft'] = d['sqft'] or sq
    d['size'] = d['size'] or sz
    d['thickness'] = d['thickness'] or th

# Collage thumbnails (several photos + captions) cannot be tiled; bundled clean crops are used.
CLEAN_SERIES_TEXTURE = {'fossile rock': 'fossil_rock', 'egyptian': 'egyptian', 'lakhori brick': 'lakhori_brick'}

# ── Premium 3D Surface (22 designs) ─────────────────────────────────────────
d3 = {}
for r in rd('premium_3d_surface_designs'):
    dims = re.search(r'(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)', r['dimensions_mm'].replace('X', 'x'))
    pcs = re.search(r'\d+', r['pieces_per_box'] or '')
    try:
        sq = float(r['area_covered_sqft'])
    except ValueError:
        sq = None
    d3[r['name'].strip().lower()] = dict(
        size=f'{dims.group(1)} × {dims.group(2)} mm' if dims else None,
        thickness=f'{dims.group(3)} mm' if dims else None,
        pieces=int(pcs.group()) if pcs else None, sqft=sq,
        asset='3d_' + slug(r['name']))

# ── Exclusive Patina (39 designs) ───────────────────────────────────────────
ex = {}
for r in rd('exclusive_patina_designs'):
    size = mm_pair(r['size'])
    t = thick(r['thickness'])
    patch = 0.6  # ESTIMATE: the crop is a ~0.35 m wide slice of the panel photo
    ex[r['name'].strip().lower()] = dict(size=size, thickness=t, patch=patch, asset='ex_' + slug(r['name']))

# ── write Dart ──────────────────────────────────────────────────────────────
have = set(os.listdir(AR_DIR)) if os.path.isdir(AR_DIR) else set()
def asset(a):
    return f"'assets/ar_textures/{a}.jpg'" if f'{a}.jpg' in have else 'null'

L = ['// GENERATED by scripts/gen_catalogue_specs.py from the client catalogue PDFs. Do not edit by hand.',
     '// The stones table has no size / thickness / sqft-per-box data; these fill the gaps.',
     '// patchHeightM is the real-world height of the AR texture photo: exact where the PDF gives the',
     '// panel size, otherwise ESTIMATED (see the script) and meant to be tuned on a real device.',
     '', 'class CatalogueSpec {',
     '  final String? size;', '  final String? thickness;', '  final double? sqftPerBox;', '  final int? piecesPerBox;',
     '  final double? patchHeightM;', '  final String? arTexture;',
     '  const CatalogueSpec({this.size, this.thickness, this.sqftPerBox, this.piecesPerBox, this.patchHeightM, this.arTexture});',
     '}', '', 'class CatalogueSpecs {',
     "  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\\b(series|collection|ledge)\\b'), '').replaceAll(RegExp(r'\\s+'), ' ').trim();",
     '',
     '  /// Spec for a stone (matched by collection + name), or null for anything not in the catalogue PDFs.',
     '  static CatalogueSpec? forStone(String collection, String name) {',
     '    final c = collection.toLowerCase();',
     "    if (c.contains('exclusive')) return _exclusive[name.trim().toLowerCase()];",
     "    if (c.contains('premium surface') || c.contains('premium 3d')) return _surface3d[name.trim().toLowerCase()];",
     '    return _series[_norm(collection)];',
     '  }', '',
     '  /// Every bundled clean AR texture named in the specs (used by tests to check the files exist).',
     '  static Iterable<String> get bundledTextures => [',
     '        ..._series.values, ..._surface3d.values, ..._exclusive.values,',
     '      ].map((s) => s.arTexture).whereType<String>();',
     '',
     '  static const _series = <String, CatalogueSpec>{']
for k in sorted(series):
    s = series[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, sqftPerBox: {opt_num(s['sqft'])}, patchHeightM: {opt_num(SERIES_PATCH_M.get(k))}, arTexture: {asset(CLEAN_SERIES_TEXTURE[k]) if k in CLEAN_SERIES_TEXTURE else 'null'}),")
L += ['  };', '', '  static const _surface3d = <String, CatalogueSpec>{']
for k in sorted(d3):
    s = d3[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, sqftPerBox: {opt_num(s['sqft'])}, piecesPerBox: {opt_num(s['pieces'])}, patchHeightM: 1.0, arTexture: {asset(s['asset'])}),")
L += ['  };', '', '  static const _exclusive = <String, CatalogueSpec>{']
for k in sorted(ex):
    s = ex[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, patchHeightM: {s['patch']}, arTexture: {asset(s['asset'])}),")
L += ['  };', '}', '']
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w').write('\n'.join(L))
print('series', len(series), '3d', len(d3), 'exclusive', len(ex), '->', os.path.normpath(OUT))
missing = [k for k in SERIES_PATCH_M if k not in series]
print('patch table keys without series data:', missing)
