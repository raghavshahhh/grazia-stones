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
# key -> (patchHeightM, renderType, measured, reference image + how). patchHeightM is the real height of the
# WHOLE reference image (native trims trimFraction per side and scales by 1 - 2*trim).
# measured = derived from joints/courses counted on that image against the PDF size (design setup 2026-10-30,
# build/audit/06_design_setup.md); otherwise an ESTIMATE ("est." in the UI) to be tuned on a real device.
# pattern = irregular stone/brick, tiled at photo height; module = fixed tiles/carved panels in a grid;
# artwork = one large design (must not be tiled at a guessed size).
SERIES = {
    'grande': (0.82, 'pattern', True, '1.jpg 460x260: panel seam rows ~62 px apart = 195 mm (2026-10-28)'),
    'rustic brick': (0.46, 'pattern', True, '1.jpg 460x260: brick pitch 116 px = 195+10 mm, course 39 px = 69 mm (both agree)'),
    'tarnished brick': (0.41, 'pattern', True, '1.jpg 460x260: brick pitch 126 px = 190+10 mm, course joints 44.75 px = 71 mm'),
    'colonial brick': (0.60, 'pattern', True, '1.jpg 460x260: brick pitch 107 px = 235+10 mm, course joints 33.5 px = 77 mm'),
    'castle': (0.49, 'pattern', True, '1.jpg 460x260: course joints at y 76/170 = 94 px = 165+10 mm'),
    'veines': (0.81, 'module', True, '1.jpg 460x260: slab course joints y 38/118/200 = 81 px = 250 mm'),
    'florentine': (0.97, 'module', True, '1.jpg 460x260: course joints every 33.5 px = 125 mm strip'),
    'egyptian': (0.31, 'module', True, 'ar_textures/egyptian.jpg 306x182: strip joints y 17/76/135 = 59 px = 100 mm'),
    'flora': (0.62, 'module', True, '1.jpg 460x260: tile joints x 183/372 = 189 px = 450 mm (height 300 mm = 126 px)'),
    'foliage': (0.56, 'module', True, '1.jpg 369x208: tile joints y 44/156 = 112 px = 300 mm; photo holds < 1 full repeat'),
    'hexa': (0.43, 'module', False, '1.jpg 460x260: one hex ~120 px flat-to-flat = 200 mm, by eye; lattice not exact in photo'),
    'country': (1.1, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'mountain': (1.1, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'classic': (0.9, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'opus': (1.2, 'pattern', False, '1.jpg: course count, no PDF size, ESTIMATE'),
    'vantage': (1.0, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'rockface linear': (1.0, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'cuarzo': (1.25, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'venetian': (1.3, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'andorra': (1.3, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'european stack': (0.9, 'pattern', False, '1.jpg: course count, no PDF size, ESTIMATE'),
    'travertine': (1.0, 'module', False, '1.jpg 369x208: one slab joint at y 102, 755x500 slabs not countable, ESTIMATE'),
    'sleepwood': (1.3, 'pattern', False, '1.jpg: plank count vs PDF, ESTIMATE'),
    'sierra': (0.8, 'pattern', False, '1.jpg: no PDF size, ESTIMATE'),
    'fossile rock': (0.35, 'pattern', False, 'ar_textures/fossil_rock.jpg (collage cell), no PDF size, ESTIMATE'),
    'tevoli': (0.9, 'pattern', False, '1.jpg: course count vs PDF tile, ESTIMATE'),
    'lakhori brick': (0.6, 'pattern', False, 'ar_textures/lakhori_brick.jpg (collage cell): courses unclear, ESTIMATE'),
    'vine': (0.8, 'module', False, '1.jpg 216x373: flutes, no tile joint visible, ESTIMATE'),
    'modena': (0.9, 'module', False, '1.jpg 369x209: ~6 strips of 150 mm by eye, ESTIMATE'),
    'cave': (1.0, 'module', False, '1.jpg 369x209: 300 mm tile edges not visible, ESTIMATE'),
    'weave': (0.75, 'module', False, '1.jpg 321x183: weave squares ~80 px if 300 mm, by eye, ESTIMATE'),
    'milano': (0.6, 'artwork', False, '1.jpg 293x167: part of one 895x595 carved panel, ESTIMATE; needs a whole-panel photo'),
    'alpine': (0.9, 'module', False, '1.jpg 259x458: no tile joint visible, ESTIMATE'),
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
# key -> (patchHeightM, measured, texture, trimFraction, renderType, how). Textures ending _tile.jpg are period-exact
# crops of the design's own bundled photo (one whole number of module repeats, lighting flattened with a
# one-repeat box filter): they tile edge to edge, so trimFraction 0 (a trim would shift the grid).
# px/mm comes from module joints counted on the image against the PDF module size.
SURFACE = {
    'athena': (1.2, True, '3d_athena_tile', 0.0, 'module', '3d_athena_tile 981x327: square block 54.5 px = 200 mm (two 100x200 pieces), repeat 109 px = 400 mm, 3 rows'),
    'blanco': (0.4, True, '3d_blanco_tile', 0.0, 'module', '3d_blanco_tile 972x354: column 88.4 px = 100 mm, Y repeat 354 px = one 400 mm piece'),
    'pietra': (0.4, True, '3d_pietra_tile', 0.0, 'module', '3d_pietra_tile 850x396: column 94.4 px = 100 mm, Y repeat 396 px = one 400 mm piece'),
    'kite': (1.219, True, '3d_kite_tile', 0.0, 'module', '3d_kite_tile 989x377: X 47.1 px = 152.4 mm, Y 94.3 px = 304.8 mm, 4 rows'),
    'feather': (0.4, True, '3d_feather_tile', 0.0, 'module', '3d_feather_tile 994x221: column 55.2 px = 100 mm, 221 px = one 400 mm piece'),
    '2-barcode': (1.067, True, '3d_2_barcode_tile', 0.0, 'module', '3d_2_barcode_tile 819x382: panel 136.5 px = 381 mm, joints y 96/478 = 1066.8 mm'),
    '5-barcode': (1.067, True, '3d_5_barcode_tile', 0.0, 'module', '3d_5_barcode_tile 801x498: joints y 19/517 = 498 px = 1066.8 mm; X repeat 267 px (autocorrelation) x3'),
    'archo': (1.219, True, '3d_archo_tile', 0.0, 'module', '3d_archo_tile 958x543: row joints y 30/302/573 = 271.5 px = 609.6 mm (24 in), 2 rows; width = whole photo, not a proven repeat'),
    'cairo': (0.973, True, '3d_cairo_tile', 0.0, 'module', '3d_cairo_tile 938x367: tall rows 160 px = 424 mm, repeat 367 px = 2 tall + 1 short row; width = whole photo'),
    'toran': (1.8, True, '3d_toran_tile', 0.0, 'module', '3d_toran_tile 776x582: piece 97 px = 300 mm, row 291 px = 900 mm, 2 rows composed from both rows in the photo'),
    'toran 2.0': (0.9, True, '3d_toran_2_0_tile', 0.0, 'module', '3d_toran_2_0_tile 837x504: column 167.4 px = 300 mm, Y repeat 504 px = 900 mm piece'),
    's-wave': (1.25, True, '3d_s_wave_tile', 0.0, 'module', '3d_s_wave_tile 795x442: column 88.3 px = 250 mm, 442 px = 1250 mm piece'),
    'granito': (0.9, True, '3d_granito_tile', 0.0, 'module', '3d_granito_tile 912x302: row joints every 151 px = 450 mm, 2 rows'),
    'flute fusion': (0.6, True, '3d_flute_fusion_tile', 0.0, 'module', '3d_flute_fusion_tile 370x244: module joints x 305/675 = 3 x 300 mm, 244 px = 2 modules'),
    'cosmic flutes': (1.8, True, '3d_cosmic_flutes', 0.08, 'module', '3d_cosmic_flutes 1024x960: column joints every 203 px = 381 mm; vertical repeat not in photo'),
    'scale': (1.96, False, '3d_scale_tile', 0.0, 'module', '3d_scale_tile 772x892: X repeat 193 px read as the 424 mm diagonal of a 300 mm piece; Y pitch disagrees, ESTIMATE'),
    'rover': (1.27, False, '3d_rover_tile', 0.0, 'module', '3d_rover_tile 523x543: 12 strips of 43.6 px = 101.6 mm; row joints (136 px) do not match 508 mm, ESTIMATE'),
    'verona': (1.31, False, '3d_verona', 0.08, 'module', '3d_verona 1024x619: X period 37.8 px = 80 mm; Y period 86 px matches no PDF length (foreshortened), ESTIMATE'),
    'hydes': (2.5, False, '3d_hydes', 0.08, 'pattern', '3d_hydes 1024x870: free-form 651 mm pieces span ~220 px by eye, ESTIMATE'),
    'mobis': (2.3, False, '3d_mobis', 0.08, 'module', '3d_mobis 990x819: column pitch 50-57 px (perspective) = 152.4 mm, ESTIMATE; needs a frontal photo'),
    'ferro': (3.0, False, '3d_ferro', 0.08, 'module', '3d_ferro 957x795: skewed; 609.6 mm piece ~160 px from its slot, ESTIMATE; needs a frontal photo'),
    'vegas': (1.0, False, '3d_vegas', 0.08, 'module', '3d_vegas 1024x684: perspective + light falloff, no consistent module pitch; old 1.0 kept, ESTIMATE; needs a frontal photo'),
}
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
assert set(SURFACE) == set(d3), set(SURFACE) ^ set(d3)

# ── Exclusive Patina (39 designs) ───────────────────────────────────────────
# 600 x 1200 mm panels carrying one composed design are 'artwork' (the crop is a slice of one panel, so the
# tiled slice is not the real repeat); the rest are 'module' grids of small tiles/strips. Every Exclusive crop is
# a perspective-skewed slice of a tilted panel shot, so no module can be counted: scale stays an ESTIMATE and the
# product needs a clean frontal photo from the client.
EX_ARTWORK = {'baroque copper patina', 'fleur lattice panel', 'fluid wave panel', 'midnight scallop mosaic',
              'ornate nickel scales', 'river pebble panel', 'timber flow panel', 'turquoise fleur heritage',
              'turquoise lava panel', 'turquoise scallop pattern'}
ex = {}
for r in rd('exclusive_patina_designs'):
    size = mm_pair(r['size'])
    t = thick(r['thickness'])
    patch = 0.6  # ESTIMATE for all 39: crops are perspective-skewed slices of tilted panel photos
    ex[r['name'].strip().lower()] = dict(size=size, thickness=t, patch=patch, asset='ex_' + slug(r['name']),
                                         kind='artwork' if r['name'].strip().lower() in EX_ARTWORK else 'module')

# ── write Dart ──────────────────────────────────────────────────────────────
have = set(os.listdir(AR_DIR)) if os.path.isdir(AR_DIR) else set()
def asset(a):
    return f"'assets/ar_textures/{a}.jpg'" if f'{a}.jpg' in have else 'null'

def render(patch, trim, kind, measured):
    t = '' if trim == 0.08 else f', trimFraction: {trim}'
    return f"patchHeightM: {opt_num(patch)}{t}, renderType: {dart_str(kind)}, patchMeasured: {'true' if measured else 'false'}"

L = ['// GENERATED by scripts/gen_catalogue_specs.py from the client catalogue PDFs. Do not edit by hand.',
     '// The stones table has no size / thickness / sqft-per-box data; these fill the gaps.',
     '// patchHeightM is the real-world height of the whole AR texture image. patchMeasured = counted from module',
     '// joints on that image against the PDF size; false = ESTIMATE, to be tuned on a real device.',
     '// Each entry\'s trailing comment names the reference image and how the value was measured',
     '// (details: build/audit/06_design_setup.md).',
     '', 'class CatalogueSpec {',
     '  final String? size;', '  final String? thickness;', '  final double? sqftPerBox;', '  final int? piecesPerBox;',
     '  final double? patchHeightM;', '  final String? arTexture;',
     '  /// Fraction of the image cut off each side before tiling (native scales patchHeightM by 1 - 2 * trimFraction).',
     '  /// 0 for period-exact crops: a trim would cut into the module and break the repeat.',
     '  final double trimFraction;',
     "  /// 'pattern' (irregular stone, tile the photo), 'module' (fixed tiles/panels in a grid) or 'artwork' (one large",
     '  /// design; the bundled image is only part of it, so tiling it is not the real repeat).',
     '  final String renderType;',
     '  /// True when patchHeightM was measured on this exact image; false = estimate.',
     '  final bool patchMeasured;',
     "  const CatalogueSpec({this.size, this.thickness, this.sqftPerBox, this.piecesPerBox, this.patchHeightM, this.arTexture,",
     "      this.trimFraction = 0.08, this.renderType = 'pattern', this.patchMeasured = false});",
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
    patch, kind, measured, how = SERIES[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, sqftPerBox: {opt_num(s['sqft'])}, {render(patch, 0.08, kind, measured)}, arTexture: {asset(CLEAN_SERIES_TEXTURE[k]) if k in CLEAN_SERIES_TEXTURE else 'null'}), // {how}")
L += ['  };', '', '  static const _surface3d = <String, CatalogueSpec>{']
for k in sorted(d3):
    s = d3[k]
    patch, measured, tex, trim, kind, how = SURFACE[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, sqftPerBox: {opt_num(s['sqft'])}, piecesPerBox: {opt_num(s['pieces'])}, {render(patch, trim, kind, measured)}, arTexture: {asset(tex)}), // {how}")
L += ['  };', '', '  static const _exclusive = <String, CatalogueSpec>{']
for k in sorted(ex):
    s = ex[k]
    L.append(f"    {dart_str(k)}: CatalogueSpec(size: {opt_str(s['size'])}, thickness: {opt_str(s['thickness'])}, {render(s['patch'], 0.08, s['kind'], False)}, arTexture: {asset(s['asset'])}), // {s['asset']}.jpg: skewed slice of a tilted panel, ESTIMATE")
L += ['  };', '}', '']
assert 'null), //' not in '\n'.join(l for l in L if '_tile' in l), 'missing tile asset'
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w').write('\n'.join(L))
print('series', len(series), '3d', len(d3), 'exclusive', len(ex), '->', os.path.normpath(OUT))
missing = sorted(set(SERIES) ^ set(series))
print('render table keys vs series data mismatch:', missing)
