import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/cart_service.dart';
import '../../domain/cart_item.dart';
part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  late final cartService = ref.read(cartServiceProvider);
  @override
  Future<List<CartItem>> build() async {
    return cartService.getCartItems();
  }

  Future<void> addCartItem(CartItem item) async {
    await cartService.addCartItem(item);
    update((state) => [...state, item]);
  }

  Future<void> removeCartItem(String id) async {
    await cartService.removeCartItem(id);
    update((state) => state.where((e) => e.id != id).toList());
  }

  Future<void> updateCartItem(CartItem item) async {
    await cartService.updateCartItem(item);
    update((state) => state.map((e) => e.id == item.id ? item : e).toList());
  }

  void clear() {
    update((state) => []);
  }
}
