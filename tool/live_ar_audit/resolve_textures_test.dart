// Resolves every catalogue row's Live AR texture with the app's own code.
// AUDIT_DIR=<dir with stones_full.json> flutter test tool/live_ar_audit/resolve_textures_test.dart
// stones_full.json: GET <SUPABASE_URL>/rest/v1/stones?select=*,collections(name)  (anon key, read-only)
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/data/catalogue_specs.dart';
import 'package:grazia_stones/core/repositories/stone_repository.dart';

void main() {
  test('resolve AR textures like the app', () {
    final dir = Platform.environment['AUDIT_DIR'] ?? '.';
    final rows = jsonDecode(File('$dir/stones_full.json').readAsStringSync()) as List;
    final out = rows.map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      final col = (row['collections']?['name'] ?? '') as String;
      final spec = CatalogueSpecs.forStone(col, row['name'] as String);
      final images = List<String>.from(row['images'] ?? const []);
      final main = row['thumbnail_url'] ?? (images.isNotEmpty ? images.first : null);
      final ar = StoneRepository.arTextureFor(row, spec);
      return {
        'id': row['id'], 'code': row['product_code'], 'name': row['name'], 'collection': col,
        'main_image': main, 'ar_bundled': ar, 'ar_source': ar ?? main,
        'spec_size': spec?.size, 'spec_patch_m': spec?.patchHeightM,
        'db_length_cm': row['length_cm'], 'db_width_cm': row['width_cm'],
      };
    }).toList();
    File('$dir/resolved.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
