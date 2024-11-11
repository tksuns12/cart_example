import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../domain/cart_item.dart';
import '../states/cart_items_provider.dart';
import '../states/selected_items_provider.dart';

class CartItemView extends ConsumerStatefulWidget {
  final CartItem cartItem;

  const CartItemView({super.key, required this.cartItem});

  @override
  ConsumerState<CartItemView> createState() => _CartItemViewState();
}

class _CartItemViewState extends ConsumerState<CartItemView> {
  Timer? _debounce;
  final TextEditingController _quantityController = TextEditingController();
  late final selectedItemsNotifier = ref.read(selectedItemsProvider.notifier);
  late final cartItemsNotifier = ref.read(cartItemsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.cartItem.quantity.toString();
  }

  @override
  void didUpdateWidget(CartItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartItem.quantity != widget.cartItem.quantity) {
      _quantityController.text = widget.cartItem.quantity.toString();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quantityController.dispose();
    super.dispose();
  }

  void _onQuantityChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final newQuantity = int.tryParse(value);
      if (newQuantity != null && newQuantity > 0) {
        cartItemsNotifier.updateCartItem(
          widget.cartItem.copyWith(quantity: newQuantity),
        );
      } else if (newQuantity != null && newQuantity <= 0) {
        cartItemsNotifier.removeCartItem(widget.cartItem.id);
      } else {
        // Reset to previous valid value if input is invalid
        _quantityController.text = widget.cartItem.quantity.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Consumer(builder: (context, ref, child) {
              final isSelected = ref.watch(selectedItemsProvider.select(
                (state) => state.contains(widget.cartItem),
              ));
              return Checkbox(
                value: isSelected,
                onChanged: (value) {
                  if (value == null) return;
                  if (value) {
                    selectedItemsNotifier.addItem(widget.cartItem);
                  } else {
                    selectedItemsNotifier.removeItem(widget.cartItem.id);
                  }
                },
              );
            }),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cartItem.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(widget.cartItem.price / 100).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (widget.cartItem.quantity <= 1) {
                      cartItemsNotifier.removeCartItem(widget.cartItem.id);
                    } else {
                      cartItemsNotifier.updateCartItem(
                        widget.cartItem.copyWith(
                          quantity: widget.cartItem.quantity - 1,
                        ),
                      );
                    }
                  },
                ),
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _onQuantityChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    cartItemsNotifier.updateCartItem(
                      widget.cartItem.copyWith(
                        quantity: widget.cartItem.quantity + 1,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    cartItemsNotifier.removeCartItem(widget.cartItem.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
