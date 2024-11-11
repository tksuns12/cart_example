import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selected_items_provider.dart';

final sumProvider = Provider<int>((ref) {
  return ref
      .watch(selectedItemsProvider)
      .fold<int>(0, (acc, current) => acc + (current.price * current.quantity));
});
