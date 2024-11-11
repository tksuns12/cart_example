import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../states/cart_items_provider.dart';
import '../states/selected_items_provider.dart';

class SelectAllCheckbox extends ConsumerWidget {
  const SelectAllCheckbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedItems = ref.watch(selectedItemsProvider);
    final cartItems = ref.watch(cartItemsProvider);
    final allSelected = const DeepCollectionEquality().equals(
        selectedItems.map((item) => item.id),
        (cartItems.valueOrNull ?? []).map((e) => e.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (value) {
              if (value == null) return;
              ref.read(selectedItemsProvider.notifier).toggleAll(value);
            },
          ),
          const Text('전체 선택'),
        ],
      ),
    );
  }
}
