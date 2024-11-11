import 'package:cart_example/features/cart/data/cart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cart_item.dart';

/// 이 변수를 통해 다른 [Provider] 내에서 [CartService]를 참조할 수 있습니다.
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService(ref);
});

class CartService {
  final Ref ref;
  late final _client = ref.read(cartRepositoryProvider);
  CartService(this.ref);

  Future<List<CartItem>> getCartItems() async {
    final response = await _client.getCartItems();
    return response.map((e) => CartItem.fromMap(e)).toList();
  }

  Future<void> addCartItem(CartItem item) async {
    await _client.addCartItem(item);
  }

  Future<void> removeCartItem(String id) async {
    await _client.removeCartItem(id);
  }

  Future<void> updateCartItem(CartItem item) async {
    await _client.updateCartItem(item);
  }
}
