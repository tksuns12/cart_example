import 'package:cart_example/features/cart/domain/cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return MockCartRepository();
});

abstract class CartRepository {
  Future<List<Map<String, dynamic>>> getCartItems();
  Future<void> addCartItem(CartItem item);
  Future<void> removeCartItem(String id);
  Future<void> updateCartItem(CartItem item);
}

class MockCartRepository implements CartRepository {
  @override
  Future<void> addCartItem(CartItem item) {
    return Future.value();
  }

  @override
  Future<List<Map<String, dynamic>>> getCartItems() {
    return Future.value([
      {
        'id': '1',
        'name': 'Item 1',
        'price': 100,
        'quantity': 1,
      },
      {
        'id': '2',
        'name': 'Item 2',
        'price': 200,
        'quantity': 2,
      },
    ]);
  }

  @override
  Future<void> removeCartItem(String id) {
    return Future.value();
  }

  @override
  Future<void> updateCartItem(CartItem item) {
    return Future.value();
  }
}
