# Live AR texture audit (all 95 catalogue products)

Generated 2026-10-25 from the live `stones` table (95 active rows) with the app's own resolver
(`StoneRepository.arTextureFor`). Per-product data: `docs/live_ar_texture_audit.csv`. Repeat sheets (2x2 tiles;
left = photo as used, right = after the seam cut) were reviewed by eye: `docs/evidence/live_ar_texture/`.

Evidence levels: VIRTUAL-TESTED = offline on the real texture files; DEVICE-VERIFIED = seen on the OnePlus NE2211.

## Summary

| Status | Products |
|---|---|
| SUPPORTED_VERIFIED (device) | 1 (Grande Ledge Series) |
| SUPPORTED_NOT_DEVICE_VERIFIED | 2 |
| has SEAMING_DEFECT | 78 |
| has LOW_RESOLUTION (< 400 px short side) | 42 |
| has DIMENSIONS_UNVERIFIED | 11 |
| WRONG_IMAGE_TYPE (room/lifestyle photo as tile) | 0 (all 95 visually reviewed) |
| MISSING_TEXTURE | 0 |

## Findings

1. **Every texture is a real stone/tile surface photo of that product**: 69 bundled AR textures, 26 the product's own
   catalogue photo. Product IDs resolve deterministically (exact id / code / name before any `contains` match;
   unknown ids no longer fall back to the first product).
2. **No product photo tiles seamlessly as delivered** (seam score > 2 for 95/95: the jump across the repeat edge
   is more than twice the image's own pixel-to-pixel variation).
3. **The seam cut (`SeamlessTile`) must not be applied to designed patterns.** The 2x2 sheets show it breaking
   Arctic Chevron Strata, Indigo Linear Weave, Ivory Metallic Strata, Archo, Toran, Timber Flow Panel and the
   textured patchworks, while the numeric seam score called them fixed. It now runs only for the Brick and Ledge
   groups (16 products), where the cut follows irregular mortar joints. All others repeat as photographed and keep
   a visible seam until a tileable file exists.
4. **42 textures are under 400 px** on the short side (Milano 293x167, Egyptian 306x182, most series 369x209).
   Spread over a 1 m+ wall patch they cannot look sharp. This is an asset limit, not a renderer bug.

## Owner action: assets needed from Grazia

For a believable Live AR result each product needs **one tileable texture file**: a straight-on, evenly lit photo
or scan of the surface, at least 1024 px on the short side, whose right edge continues into its left edge and
bottom into top (one exact pattern repeat), plus the real size in mm that the file covers.

- Seam-free tileable file needed (78 products), by collection:
  - Alpine Series: Alpine Series
  - Cave Series: Cave Series
  - Classic Ledge Series: Classic Ledge Series
  - Egyptian Series: Egyptian Series
  - Exclusive Collection: Arctic Chevron Strata, Baroque Copper Patina, Botanical Copper Pattern, Brushed Alloy Reveal, Copper Fossil Pattern, Diamond Plate Matrix, Fleur Lattice Panel, Fluid Wave Panel, Golden Arc Rhythm, Golden Hexa Pattern, Golden Stud Matrix, Golden Terrain Mosaic, Indigo Linear Weave, Industrial Strata Pattern, Ivory Fossil Mosaic, Ivory Metallic Strata, Linear Alloy Strata, Lunar Nickel Pattern, Midnight Scallop Mosaic, Monochrome Hexa Pattern, Monochrome Texture Pattern, Mosaic Rhythm Grid, Nordic Mosaic Grid, Ornamental Stone Strata, Ornate Nickel Scales, Patina Strata, Perforated Metal Matrix, River Pebble Panel, Riveted Bronze Grid, Riveted Steel Patchwork, Sacred Bronze Tapestry, Textured Bronze Patchwork, Timber Flow Panel, Tribal Nickel Rhythm, Turquoise Fleur Heritage, Turquoise Floral Heritage, Turquoise Lava Panel, Turquoise Scallop Pattern, Verdigris Copper Bloom
  - Flora Series: Flora Series
  - Florentine Series: Florentine Series
  - Foliage Series: Foliage Series
  - Fossile Rock Series: Fossile Rock Series
  - Hexa Series: Hexa Series
  - Milano Series: Milano Series
  - Premium Surface Collection: 2-Barcode, 5-Barcode, Archo, Athena, Blanco, Cairo, Cosmic Flutes, Feather, Ferro, Flute Fusion, Granito, Hydes, Kite, Mobis, Pietra, Rover, S-Wave, Scale, Toran, Toran 2.0, Vegas, Verona
  - Rockface Series: Rockface Series
  - Sierra Series: Sierra Series
  - Sleepwood Series: Sleepwood Series
  - Tevoli Series: Tevoli Series
  - Travertine Series: Travertine Series
  - Veines Series: Veines Series
  - Vine Series: Vine Series

- Higher resolution needed (42): Alpine Series, Andorra Series, Athena, Baroque Copper Patina, Botanical Copper Pattern, Castle Ledge Series, Cave Series, Colonial Brick Series, Country Ledge Series, Cuarzo Series, Egyptian Series, European Stack Series, Feather, Flora Series, Florentine Series, Foliage Series, Fossile Rock Series, Golden Terrain Mosaic, Hexa Series, Lakhori Brick Series, Lunar Nickel Pattern, Milano Series, Modena Series, Patina Strata, Rockface Linear Series, Rockface Series, Rustic Brick Series, Sacred Bronze Tapestry, Sierra Series, Sleepwood Series, Tarnished Brick Series, Tevoli Series, Textured Bronze Patchwork, Travertine Series, Tribal Nickel Rhythm, Turquoise Floral Heritage, Turquoise Scallop Pattern, Veines Series, Venetian Series, Verdigris Copper Bloom, Vine Series, Weave Series
- Physical dimensions missing (11): Arctic Chevron Strata, European Stack Series, Fossile Rock Series, Golden Arc Rhythm, Indigo Linear Weave, Industrial Strata Pattern, Opus Ledge Series, Ornamental Stone Strata, Sierra Series, Textured Bronze Patchwork, Verdigris Copper Bloom

## Reproduce

```
# 1. catalogue: curl "$SUPABASE_URL/rest/v1/stones?select=*,collections(name)" -H "apikey: $ANON" > $DIR/stones_full.json
AUDIT_DIR=$DIR flutter test tool/live_ar_audit/resolve_textures_test.dart   # app resolver -> resolved.json
python3 tool/live_ar_audit/fetch_textures.py $DIR .                         # texture files
# 2. metrics + 2x2 sheets: seam score = mean |left - right column| / mean neighbour difference (same for top/bottom),
#    seam cut = tool/wall_lab/seam.py (same algorithm as SeamlessTile.kt), 8% border trim as in ARCoreManager.setTexture
```
