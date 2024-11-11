import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/cart_items_provider.dart';
import 'cart_item_view.dart';

class CartList extends ConsumerWidget {
  const CartList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    return cartItems.when<Widget>(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('장바구니가 비었습니다.'));
        }
        return ListView.builder(
          itemBuilder: (context, index) {
            final item = items[index];
            return CartItemView(
              key: ValueKey(item.id),
              cartItem: item,
            );
          },
          itemCount: items.length,
        );
      },
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(cartItemsProvider),
          child: const Text('에러 발생! 다시 시도하기'),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
