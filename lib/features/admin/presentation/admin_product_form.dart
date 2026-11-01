/// Validation + row building for the admin product form. Pure Dart so it is unit-tested
/// (test/admin_product_form_test.dart) without Supabase or widgets.
library;

class ProductForm {
  ProductForm._();

  static const nameMax = 120;
  static const codeMax = 40;
  static const categoryMax = 60;
  static const shortDescriptionMax = 200;
  static const descriptionMax = 4000;
  static const sortOrderMax = 9999;

  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter the product name';
    if (t.length > nameMax) return 'Keep the name under $nameMax characters';
    if (slugify(t).isEmpty) return 'Use at least one letter or number';
    return null;
  }

  static final _codeChars = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._/-]*$');

  /// Optional. Unique in the table, so an empty code is stored as null, never invented.
  static String? code(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length > codeMax) return 'Keep the code under $codeMax characters';
    if (!_codeChars.hasMatch(t)) return 'Use letters, numbers, space, - _ . /';
    return null;
  }

  static String? category(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter a category';
    if (t.length > categoryMax) return 'Keep the category under $categoryMax characters';
    return null;
  }

  static String? collection(String? id) => (id == null || id.isEmpty) ? 'Choose a collection' : null;

  static String? maxLength(String? v, int max) =>
      (v?.trim().length ?? 0) > max ? 'Keep this under $max characters' : null;

  /// Optional positive number with an upper sanity bound (catches cm/mm mix-ups like 6000).
  static String? optionalPositive(String? v, {required double max, String unit = ''}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null) return 'Enter a number';
    if (n <= 0) return 'Must be more than 0';
    if (n > max) return 'Too large (max ${_fmt(max)}${unit.isEmpty ? '' : ' $unit'})';
    return null;
  }

  /// Optional. Empty or 0 means 'Price on request'; nothing is ever filled in for the admin.
  static String? price(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null) return 'Enter a number, or leave empty for price on request';
    if (n < 0) return 'Price cannot be negative';
    if (n > 1000000) return 'Too large';
    return null;
  }

  static String? sortOrder(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0) return 'Whole number, 0 or more';
    if (n > sortOrderMax) return 'Max $sortOrderMax';
    return null;
  }

  /// A live product needs a photo: the catalogue, AR and wall visualizer all use it.
  static String? images(int count, {required bool active}) =>
      active && count == 0 ? 'Add at least one photo before publishing' : null;

  static String slugify(String v) =>
      v.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

  /// "Beige, grey,, Beige " -> [Beige, grey]; trims, drops blanks and case-insensitive duplicates.
  static List<String> splitList(String v) {
    final seen = <String>{};
    return [
      for (final s in v.split(',').map((s) => s.trim()))
        if (s.isNotEmpty && seen.add(s.toLowerCase())) s,
    ];
  }

  static double? number(String v) {
    final t = v.trim();
    return t.isEmpty ? null : double.tryParse(t.replaceAll(',', '.'));
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Formats a stored numeric for a text field: 60.0 -> '60', null -> ''.
  static String text(dynamic v) => v is num ? _fmt(v.toDouble()) : '';

  /// The `stones` columns this form owns. Columns it does not show (stock, model_3d_url, meta…) are left out
  /// so an edit never resets them.
  static Map<String, dynamic> row({
    required String name,
    required String slug,
    required String code,
    required String collectionId,
    required String category,
    required String shortDescription,
    required String description,
    required String price,
    required String lengthCm,
    required String widthCm,
    required String thicknessMm,
    required String coverageSqft,
    required String finish,
    required String material,
    required String colors,
    required String tags,
    required String sortOrder,
    required bool featured,
    required bool active,
    required List<String> images,
  }) {
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    final s = slugify(slug.trim().isEmpty ? name : slug);
    return {
      'name': name.trim(),
      'slug': s,
      'product_code': orNull(code),
      'collection_id': collectionId,
      'category': category.trim(),
      'short_description': orNull(shortDescription),
      'description': orNull(description),
      'price_per_sqft': number(price) ?? 0, // column is NOT NULL; 0 = price on request
      'length_cm': number(lengthCm),
      'width_cm': number(widthCm),
      'thickness_mm': number(thicknessMm),
      'coverage_sqft': number(coverageSqft),
      'finish': orNull(finish),
      'material': orNull(material),
      'colors': splitList(colors),
      'tags': splitList(tags),
      'sort_order': int.tryParse(sortOrder.trim()) ?? 0,
      'featured': featured,
      'active': active,
      'images': images,
      'thumbnail_url': images.isEmpty ? null : images.first,
    };
  }
}
