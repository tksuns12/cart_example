import 'package:cart_example/features/cart/presentation/states/cart_items_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/cart_item.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  @override
  List<CartItem> build() {
    ref.listen(cartItemsProvider, _listenToCartItemsProvider);
    return [];
  }

  /// 장바구니 상태를 구독하는 메서드
  void _listenToCartItemsProvider(
      AsyncValue<List<CartItem>>? previous, AsyncValue<List<CartItem>> next) {
    if (next.hasValue &&
        (previous?.valueOrNull?.length ?? 0) > next.value!.length) {
      _removeAbsentItem(next);
    }
    if (previous?.isLoading == true && next.hasValue) {
      if (state.isEmpty) {
        state = next.value ?? [];
      } else {
        _removeAbsentItem(next);
      }
    }
  }

  /// 장바구니에 없는 항목은 빼도록 하는 메서드
  void _removeAbsentItem(AsyncValue<List<dynamic>> currentCartItems) {
    state =
        state.where((item) => currentCartItems.value!.contains(item)).toList();
  }

  Future<void> addItem(CartItem item) async {
    state = [...state, item];
  }

  Future<void> removeItem(String id) async {
    state = state.where((item) => item.id != id).toList();
  }

  void toggleAll(bool value) {
    state = value ? ref.watch(cartItemsProvider).valueOrNull ?? [] : [];
  }
}
