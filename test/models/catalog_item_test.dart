import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/catalog_item.dart';

void main() {
  group('CatalogItemType', () {
    test('fromString parses service', () {
      expect(CatalogItemType.fromString('service'), CatalogItemType.service);
    });

    test('fromString maps legacy booking to service', () {
      expect(CatalogItemType.fromString('booking'), CatalogItemType.service);
    });

    test('fromString defaults to product', () {
      expect(CatalogItemType.fromString('product'), CatalogItemType.product);
      expect(CatalogItemType.fromString(null), CatalogItemType.product);
      expect(CatalogItemType.fromString('unknown'), CatalogItemType.product);
    });
  });

  group('CatalogItem - formattedPrice', () {
    CatalogItem makeItem({double? price, String currency = 'INR'}) {
      return CatalogItem(
        id: 'item-1',
        userId: 'user-1',
        name: 'Test Item',
        price: price,
        currency: currency,
      );
    }

    test('null price returns Contact for price', () {
      expect(makeItem(price: null).formattedPrice, 'Contact for price');
    });

    test('INR uses rupee symbol', () {
      expect(makeItem(price: 500).formattedPrice, '\u20B9500');
    });

    test('USD uses dollar symbol', () {
      expect(
        makeItem(price: 25, currency: 'USD').formattedPrice,
        '\$25',
      );
    });

    test('whole number omits decimals', () {
      expect(makeItem(price: 100.0).formattedPrice, '\u20B9100');
    });

    test('fractional price shows 2 decimals', () {
      expect(makeItem(price: 99.99).formattedPrice, '\u20B999.99');
    });

    test('unknown currency uses currency code', () {
      expect(
        makeItem(price: 50, currency: 'EUR').formattedPrice,
        'EUR50',
      );
    });
  });

  group('CatalogItem - copyWith', () {
    test('preserves unchanged fields', () {
      final original = CatalogItem(
        id: 'item-1',
        userId: 'user-1',
        name: 'Original',
        price: 100,
        currency: 'INR',
        type: CatalogItemType.product,
        isAvailable: true,
        tags: ['tag1'],
      );
      final copy = original.copyWith(name: 'Updated');
      expect(copy.name, 'Updated');
      expect(copy.id, 'item-1');
      expect(copy.price, 100);
      expect(copy.currency, 'INR');
      expect(copy.tags, ['tag1']);
      expect(copy.isAvailable, isTrue);
    });

    test('can update multiple fields', () {
      final original = CatalogItem(
        id: 'item-1',
        userId: 'user-1',
        name: 'Test',
      );
      final copy = original.copyWith(
        price: 200,
        currency: 'USD',
        isAvailable: false,
      );
      expect(copy.price, 200);
      expect(copy.currency, 'USD');
      expect(copy.isAvailable, isFalse);
    });
  });

  group('CatalogItem - defaults', () {
    test('default values are correct', () {
      final item = CatalogItem(
        id: 'id',
        userId: 'uid',
        name: 'Test',
      );
      expect(item.currency, 'INR');
      expect(item.type, CatalogItemType.product);
      expect(item.isAvailable, isTrue);
      expect(item.viewCount, 0);
      expect(item.isFeatured, isFalse);
      expect(item.tags, isEmpty);
    });
  });
}
