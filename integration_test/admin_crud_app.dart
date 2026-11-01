// Admin product CRUD check against the real backend (QA tool, not a unit test). Signs in as an admin, creates ONE
// hidden product "ZZ QA Test Product (delete me)", edits it, uploads one tiny photo, screenshots the admin screens,
// then permanently deletes the product and its photo and checks both are gone. Leaves no data behind.
//   flutter run -t integration_test/admin_crud_app.dart -d <simulator> \
//     --dart-define=QA_EMAIL=... --dart-define=QA_PASSWORD=...
// A host script screenshots the simulator on each "SWEEP SHOT <name>" log line.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/config/router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/repositories/admin_product_repository.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/features/admin/presentation/admin_product_form.dart';
import 'package:grazia_stones/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart' show SearchOptions;

const _email = String.fromEnvironment('QA_EMAIL');
const _password = String.fromEnvironment('QA_PASSWORD');
const _name = 'ZZ QA Test Product (delete me)';

Element? _appElement() {
  Element? hit;
  void visit(Element e) {
    if (hit != null) return;
    if (e.widget is GraziaApp) {
      hit = e;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return hit;
}

Future<Uint8List> _tinyPng() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = const Color(0xFFB99A5B));
  final img = await rec.endRecording().toImage(64, 64);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void _log(String s) => debugPrint('SWEEP $s');

Future<void> main() async {
  app.main();
  await Future.delayed(const Duration(seconds: 5));
  await SupabaseService.instance.ready.timeout(const Duration(seconds: 15), onTimeout: () {});
  final container = ProviderScope.containerOf(_appElement()!);
  await container.read(authRiverpodProvider.notifier).loginWithApi(_email, _password);
  await Future.delayed(const Duration(seconds: 3));
  final auth = container.read(authRiverpodProvider);
  _log('AUTH loggedIn=${auth.isLoggedIn} admin=${auth.isAdmin}');
  if (!auth.isAdmin) {
    _log('DONE (not an admin)');
    return;
  }

  final client = SupabaseService.instance.client;
  final repo = container.read(adminProductRepositoryProvider);
  final router = container.read(appRouterProvider);
  Future<void> shot(String route, String name) async {
    router.go(route);
    await Future.delayed(const Duration(milliseconds: 5000));
    _log('SHOT $name');
    await Future.delayed(const Duration(milliseconds: 2000));
  }

  String? id;
  String? photo;
  final results = <String, bool>{};
  try {
    // Leftovers from an earlier aborted run would collide on slug.
    final stale = await client.from('stones').select('id').eq('name', _name);
    for (final r in stale) {
      await repo.permanentlyDeleteProduct(r['id'].toString());
      _log('cleaned stale ${r['id']}');
    }

    final collection = (await client.from('collections').select('id').eq('active', true).limit(1)).first['id'] as String;
    Map<String, dynamic> form({String short = '', List<String> images = const []}) => ProductForm.row(
          name: _name, slug: '', code: 'ZZ-QA-01', collectionId: collection, category: 'QA', shortDescription: short,
          description: '', price: '', lengthCm: '60', widthCm: '15', thicknessMm: '', coverageSqft: '', finish: '',
          material: '', colors: 'Grey', tags: 'qa', sortOrder: '9999', featured: false, active: false, images: images,
        );

    id = await repo.saveProductRow(form());
    results['create'] = true;
    _log('CRUD create ok id=$id');

    await repo.saveProductRow(form(short: 'Edited by QA'), stoneId: id);
    results['edit'] = (await repo.getProductRow(id))['short_description'] == 'Edited by QA';
    _log('CRUD edit ${results['edit']}');

    photo = await repo.uploadProductImage(await _tinyPng(), 'qa.png');
    await repo.saveProductRow(form(short: 'Edited by QA', images: [photo]), stoneId: id);
    final row = await repo.getProductRow(id);
    results['upload'] = (row['images'] as List).contains(photo) && row['thumbnail_url'] == photo;
    _log('CRUD upload ${results['upload']} path=${AdminProductRepository.storagePath(photo)}');

    final hiddenFromPublic = (await client.from('stones').select('id').eq('id', id).eq('active', true)).isEmpty;
    results['stays hidden'] = hiddenFromPublic && row['active'] == false;

    await shot('/admin/products/edit/$id', 'crud_edit');
    await shot('/admin/products?status=archived', 'crud_list_hidden');
  } catch (e) {
    _log('CRUD ERROR $e');
  } finally {
    if (id != null) {
      try {
        await repo.permanentlyDeleteProduct(id); // also removes the products/ photo
        final left = await client.from('stones').select('id').eq('id', id);
        results['delete row'] = left.isEmpty;
      } catch (e) {
        _log('CRUD delete ERROR $e');
        results['delete row'] = false;
      }
    }
    if (photo != null) {
      final file = AdminProductRepository.storagePath(photo)!.split('/').last;
      final objs = await client.storage.from('stones').list(path: 'products', searchOptions: SearchOptions(search: file));
      results['delete photo'] = objs.where((o) => o.name == file).isEmpty;
      if (results['delete photo'] == false) await repo.deleteProductImage(photo);
    }
    _log('CRUD RESULT $results');
    await shot('/admin', 'crud_after_dashboard');
    _log('DONE');
  }
}
