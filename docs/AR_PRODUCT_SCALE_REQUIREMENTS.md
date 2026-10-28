# Live AR: product scale requirements

Generated 2026-10-27 from `lib/core/data/catalogue_specs.dart` and `docs/live_ar_texture_audit.csv`.

**Status: no product's texture-repeat size is measured.** The AR wall distance can now be measured (A4 sheet, four corners of a known object, ARCore plane), but the size of the stone pattern drawn on that wall comes from `patchHeightM`, which is an estimate for every product:

- Stone series: estimated by counting stone courses in the catalogue photo (`scripts/gen_catalogue_specs.py`, `SERIES_PATCH_M`).
- Premium 3D Surface: one fixed 1.0 m for all 22 designs.
- Exclusive Patina: one fixed 0.6 m for all 39 designs.

Texture aspect ratios do not match the catalogue panel sizes (only Feather and Scale come close, and their photos show many pieces, not one panel), so the repeat size cannot be derived from the catalogue. The app therefore shows *stone size est.* instead of *true size*.

## What is needed from Grazia, per product

One of:
1. The real width x height (cm) of the area shown in the AR texture photo, or
2. A new straight-on photo of an installed sample with a tape measure or an A4 sheet in the same plane, or
3. A seamless texture of exactly one panel (then the catalogue panel size is the repeat size).

Plus, where marked, a higher-resolution photo (short side under 400 px looks soft on a wall).

| Group | Product | Catalogue panel size | Patch height used (m) | Texture px | Needs |
|---|---|---|---|---|---|
| Stone series | alpine | 640 × 290 mm | 0.9 | 259x458 | repeat size, hi-res photo |
| Stone series | andorra | 500 × 130 mm | 1.3 | 369x209 | repeat size, hi-res photo |
| Stone series | castle | 305 × 165 mm | 0.55 | - | repeat size |
| Stone series | cave | 300 × 300 mm | 1.0 | 369x209 | repeat size, hi-res photo |
| Stone series | classic | 340 × 100 mm | 0.9 | - | repeat size |
| Stone series | colonial brick | 235 × 65 mm | 0.65 | 460x260 | repeat size, hi-res photo |
| Stone series | country | 500 × 100 mm | 1.1 | - | repeat size |
| Stone series | cuarzo | 500 × 125 mm | 1.25 | 369x209 | repeat size, hi-res photo |
| Stone series | egyptian | 600 × 100 mm | 0.35 | 306x182 | repeat size, hi-res photo |
| Stone series | european stack | missing | 0.9 | 460x260 | repeat size, panel size, hi-res photo |
| Stone series | flora | 450 × 300 mm | 0.6 | 460x260 | repeat size, hi-res photo |
| Stone series | florentine | 755 × 125 mm | 1.1 | 460x260 | repeat size, hi-res photo |
| Stone series | foliage | 600 × 300 mm | 0.6 | 369x208 | repeat size, hi-res photo |
| Stone series | fossile rock | missing | 0.35 | 238x202 | repeat size, panel size, hi-res photo |
| Stone series | grande | 490 × 195 mm | 1.3 | - | repeat size |
| Stone series | hexa | 230 × 200 mm | 0.7 | 460x260 | repeat size, hi-res photo |
| Stone series | lakhori brick | 535 × 160 mm | 0.6 | 458x254 | repeat size, hi-res photo |
| Stone series | milano | 895 × 595 mm | 0.6 | 293x167 | repeat size, hi-res photo |
| Stone series | modena | 600 × 150 mm | 0.9 | 369x209 | repeat size, hi-res photo |
| Stone series | mountain | 500 × 100 mm | 1.1 | - | repeat size |
| Stone series | opus | missing | 1.2 | - | repeat size, panel size |
| Stone series | rockface linear | 445 × 110 mm | 1.0 | 460x260 | repeat size, hi-res photo |
| Stone series | rustic brick | 195 × 60 mm | 0.56 | 460x260 | repeat size, hi-res photo |
| Stone series | sierra | missing | 0.8 | 369x209 | repeat size, panel size, hi-res photo |
| Stone series | sleepwood | 580 × 130 mm | 1.3 | 460x260 | repeat size, hi-res photo |
| Stone series | tarnished brick | 190 × 65 mm | 0.6 | 460x260 | repeat size, hi-res photo |
| Stone series | tevoli | 600 × 150 mm | 0.9 | 369x209 | repeat size, hi-res photo |
| Stone series | travertine | 755 × 500 mm | 1.0 | 369x208 | repeat size, hi-res photo |
| Stone series | vantage | 410 × 150 mm | 1.0 | 800x453 | repeat size |
| Stone series | veines | 510 × 250 mm | 1.0 | 460x260 | repeat size, hi-res photo |
| Stone series | venetian | 500 × 120 mm | 1.3 | 369x209 | repeat size, hi-res photo |
| Stone series | vine | 600 × 200 mm | 0.8 | 216x373 | repeat size, hi-res photo |
| Stone series | weave | 300 × 300 mm | 0.75 | 321x183 | repeat size, hi-res photo |
| Premium 3D Surface | 2-barcode | 1066 × 281 mm | 1.0 | 1023x612 | repeat size |
| Premium 3D Surface | 5-barcode | 1066 × 381 mm | 1.0 | 1024x788 | repeat size |
| Premium 3D Surface | archo | 609.6 × 457.2 mm | 1.0 | 1024x663 | repeat size |
| Premium 3D Surface | athena | 200 × 100 mm | 1.0 | 1024x386 | repeat size, hi-res photo |
| Premium 3D Surface | blanco | 400 × 100 mm | 1.0 | 990x701 | repeat size |
| Premium 3D Surface | cairo | 424 × 248 mm | 1.0 | 1024x736 | repeat size |
| Premium 3D Surface | cosmic flutes | 762 × 381 mm | 1.0 | 1024x960 | repeat size |
| Premium 3D Surface | feather | 400 × 100 mm | 1.0 | 1024x260 | repeat size, hi-res photo |
| Premium 3D Surface | ferro | 609.60 × 152.40 mm | 1.0 | 957x795 | repeat size |
| Premium 3D Surface | flute fusion | 300 × 300 mm | 1.0 | 1024x525 | repeat size |
| Premium 3D Surface | granito | 450 × 950 mm | 1.0 | 1023x577 | repeat size |
| Premium 3D Surface | hydes | 651 × 336 mm | 1.0 | 1024x870 | repeat size |
| Premium 3D Surface | kite | 152.4 × 304.8 mm | 1.0 | 1024x451 | repeat size |
| Premium 3D Surface | mobis | 609.60 × 152.40 mm | 1.0 | 990x819 | repeat size |
| Premium 3D Surface | pietra | 400 × 100 mm | 1.0 | 908x748 | repeat size |
| Premium 3D Surface | rover | 508 × 101.6 mm | 1.0 | 1024x714 | repeat size |
| Premium 3D Surface | s-wave | 1250 × 250 mm | 1.0 | 1024x696 | repeat size |
| Premium 3D Surface | scale | 300 × 300 mm | 1.0 | 962x1024 | repeat size |
| Premium 3D Surface | toran | 900 × 300 mm | 1.0 | 1024x515 | repeat size |
| Premium 3D Surface | toran 2.0 | 900 × 300 mm | 1.0 | 1024x508 | repeat size |
| Premium 3D Surface | vegas | 400 × 100 mm | 1.0 | 1024x684 | repeat size |
| Premium 3D Surface | verona | 300 × 80 mm | 1.0 | 1024x619 | repeat size |
| Exclusive Patina | arctic chevron strata | missing | 0.6 | 582x1024 | repeat size, panel size |
| Exclusive Patina | baroque copper patina | 600 × 1200 mm | 0.6 | 291x529 | repeat size, hi-res photo |
| Exclusive Patina | botanical copper pattern | 300 × 450 mm | 0.6 | 291x529 | repeat size, hi-res photo |
| Exclusive Patina | brushed alloy reveal | 150 × 600 mm | 0.6 | 609x1024 | repeat size |
| Exclusive Patina | copper fossil pattern | 300 × 300 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | diamond plate matrix | 300 × 600 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | fleur lattice panel | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | fluid wave panel | 600 × 1200 mm | 0.6 | 543x987 | repeat size |
| Exclusive Patina | golden arc rhythm | missing | 0.6 | 555x1009 | repeat size, panel size |
| Exclusive Patina | golden hexa pattern | 200 × 230.94 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | golden stud matrix | 30 × 60 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | golden terrain mosaic | 200 × 200 mm | 0.6 | 267x485 | repeat size, hi-res photo |
| Exclusive Patina | indigo linear weave | missing | 0.6 | 582x1024 | repeat size, panel size |
| Exclusive Patina | industrial strata pattern | missing | 0.6 | 512x930 | repeat size, panel size |
| Exclusive Patina | ivory fossil mosaic | 300 × 300 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | ivory metallic strata | 100 × 600 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | linear alloy strata | 75 × 600 mm | 0.6 | 595x1024 | repeat size |
| Exclusive Patina | lunar nickel pattern | 200 × 200 mm | 0.6 | 291x529 | repeat size, hi-res photo |
| Exclusive Patina | midnight scallop mosaic | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | monochrome hexa pattern | 200 × 230.94 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | monochrome texture pattern | 300 × 300 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | mosaic rhythm grid | 300 × 300 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | nordic mosaic grid | 48 × 98 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | ornamental stone strata | missing | 0.6 | 582x1024 | repeat size, panel size |
| Exclusive Patina | ornate nickel scales | 600 × 1200 mm | 0.6 | 500x909 | repeat size |
| Exclusive Patina | patina strata | 100 × 600 mm | 0.6 | 290x527 | repeat size, hi-res photo |
| Exclusive Patina | perforated metal matrix | 300 × 600 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | river pebble panel | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | riveted bronze grid | 300 × 600 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | riveted steel patchwork | 300 × 300 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | sacred bronze tapestry | 300 × 300 mm | 0.6 | 244x443 | repeat size, hi-res photo |
| Exclusive Patina | textured bronze patchwork | missing | 0.6 | 267x485 | repeat size, panel size, hi-res photo |
| Exclusive Patina | timber flow panel | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | tribal nickel rhythm | 200 × 400 mm | 0.6 | 291x529 | repeat size, hi-res photo |
| Exclusive Patina | turquoise fleur heritage | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | turquoise floral heritage | 300 × 300 mm | 0.6 | 303x550 | repeat size, hi-res photo |
| Exclusive Patina | turquoise lava panel | 600 × 1200 mm | 0.6 | 582x1024 | repeat size |
| Exclusive Patina | turquoise scallop pattern | 600 × 1200 mm | 0.6 | 289x525 | repeat size, hi-res photo |
| Exclusive Patina | verdigris copper bloom | missing | 0.6 | 320x581 | repeat size, panel size, hi-res photo |
