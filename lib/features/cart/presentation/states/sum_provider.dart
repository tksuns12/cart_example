import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selected_items_provider.dart';

final sumProvider = Provider<int>((ref) {
  final selectedItems = ref.watch(selectedItemsProvider);
  return selectedItems.fold<int>(
      0, (acc, current) => acc + (current.price * current.quantity));
});
