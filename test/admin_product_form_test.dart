import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/repositories/admin_product_repository.dart';
import 'package:grazia_stones/features/admin/presentation/admin_product_form.dart';

Map<String, dynamic> _row({
  String name = 'Opus 15',
  String slug = '',
  String code = '',
  String price = '',
  String length = '',
  String colors = '',
  String sort = '',
  bool active = true,
  List<String> images = const ['https://x/storage/v1/object/public/stones/products/a.jpg'],
}) =>
    ProductForm.row(
      name: name,
      slug: slug,
      code: code,
      collectionId: 'c1',
      category: ' Ledge Stone ',
      shortDescription: '  ',
      description: 'Split face',
      price: price,
      lengthCm: length,
      widthCm: '',
      thicknessMm: '',
      coverageSqft: '',
      finish: '',
      material: 'Cultured Stone',
      colors: colors,
      tags: 'exterior, Exterior ,',
      sortOrder: sort,
      featured: false,
      active: active,
      images: images,
    );

void main() {
  group('ProductForm validators', () {
    test('name is required, bounded and needs a letter or number', () {
      expect(ProductForm.name(''), isNotNull);
      expect(ProductForm.name('   '), isNotNull);
      expect(ProductForm.name('---'), isNotNull);
      expect(ProductForm.name('x' * 121), isNotNull);
      expect(ProductForm.name('Opus 15'), isNull);
    });

    test('product code is optional but must be clean', () {
      expect(ProductForm.code(''), isNull);
      expect(ProductForm.code('GL-TA02'), isNull);
      expect(ProductForm.code('Classic 07'), isNull);
      expect(ProductForm.code('-bad'), isNotNull);
      expect(ProductForm.code('a<b>'), isNotNull);
      expect(ProductForm.code('A' * 41), isNotNull);
    });

    test('category and collection are required', () {
      expect(ProductForm.category(''), isNotNull);
      expect(ProductForm.category('Ledge Stone'), isNull);
      expect(ProductForm.collection(null), isNotNull);
      expect(ProductForm.collection(''), isNotNull);
      expect(ProductForm.collection('c1'), isNull);
    });

    test('price is optional (on request) but never negative or junk', () {
      expect(ProductForm.price(''), isNull);
      expect(ProductForm.price('0'), isNull);
      expect(ProductForm.price('395'), isNull);
      expect(ProductForm.price('395,50'), isNull);
      expect(ProductForm.price('-1'), isNotNull);
      expect(ProductForm.price('abc'), isNotNull);
    });

    test('sizes are optional, positive and bounded', () {
      expect(ProductForm.optionalPositive('', max: 1000), isNull);
      expect(ProductForm.optionalPositive('60', max: 1000), isNull);
      expect(ProductForm.optionalPositive('0', max: 1000), isNotNull);
      expect(ProductForm.optionalPositive('-5', max: 1000), isNotNull);
      expect(ProductForm.optionalPositive('6000', max: 1000), isNotNull);
      expect(ProductForm.optionalPositive('1.2.3', max: 1000), isNotNull);
    });

    test('sort order is a whole number 0..9999', () {
      expect(ProductForm.sortOrder(''), isNull);
      expect(ProductForm.sortOrder('3'), isNull);
      expect(ProductForm.sortOrder('-1'), isNotNull);
      expect(ProductForm.sortOrder('1.5'), isNotNull);
      expect(ProductForm.sortOrder('10000'), isNotNull);
    });

    test('a live product needs a photo, a hidden draft does not', () {
      expect(ProductForm.images(0, active: true), isNotNull);
      expect(ProductForm.images(0, active: false), isNull);
      expect(ProductForm.images(1, active: true), isNull);
    });

    test('description length limits', () {
      expect(ProductForm.maxLength('x' * 200, ProductForm.shortDescriptionMax), isNull);
      expect(ProductForm.maxLength('x' * 201, ProductForm.shortDescriptionMax), isNotNull);
    });
  });

  group('ProductForm.row', () {
    test('never invents values: empty price is 0 (on request), empty sizes and code are null', () {
      final r = _row();
      expect(r['price_per_sqft'], 0);
      expect(r['length_cm'], isNull);
      expect(r['coverage_sqft'], isNull);
      expect(r['product_code'], isNull);
      expect(r['finish'], isNull);
      expect(r['short_description'], isNull);
      expect(r['sort_order'], 0);
      expect(r.containsKey('stock_quantity'), isFalse, reason: 'form must not reset stock');
    });

    test('trims, parses numbers and dedups lists', () {
      final r = _row(price: '395', length: '60,5', colors: 'Beige, grey,, beige ', sort: '4', code: ' GL-TA02 ');
      expect(r['price_per_sqft'], 395);
      expect(r['length_cm'], 60.5);
      expect(r['colors'], ['Beige', 'grey']);
      expect(r['tags'], ['exterior']);
      expect(r['category'], 'Ledge Stone');
      expect(r['product_code'], 'GL-TA02');
      expect(r['sort_order'], 4);
    });

    test('slug comes from the name unless one exists; cover is the first photo', () {
      expect(_row(name: 'Opus Ledge 15!')['slug'], 'opus-ledge-15');
      expect(_row(slug: 'keep-old-slug')['slug'], 'keep-old-slug');
      final r = _row(images: ['a', 'b']);
      expect(r['thumbnail_url'], 'a');
      expect(_row(images: const [], active: false)['thumbnail_url'], isNull);
    });
  });

  group('storage paths', () {
    const base = 'https://p.supabase.co/storage/v1/object/public/stones';
    test('extracts the object path inside the stones bucket', () {
      expect(AdminProductRepository.storagePath('$base/products/1_a.jpg'), 'products/1_a.jpg');
      expect(AdminProductRepository.storagePath('$base/catalogue/grande/1.jpg'), 'catalogue/grande/1.jpg');
      expect(AdminProductRepository.storagePath('https://p.supabase.co/storage/v1/object/public/avatars/u/a.jpg'), isNull);
      expect(AdminProductRepository.storagePath('assets/images/athena_3d.png'), isNull);
    });

    test('only admin uploads are deletable; shared catalogue files are kept', () {
      expect(AdminProductRepository.isAdminUpload('$base/products/1_a.jpg'), isTrue);
      expect(AdminProductRepository.isAdminUpload('$base/catalogue/grande/1.jpg'), isFalse);
      expect(AdminProductRepository.isAdminUpload('assets/images/x.png'), isFalse);
    });
  });
}
