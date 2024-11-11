import 'package:cart_example/features/cart/presentation/states/cart_items_provider.dart';
import 'package:cart_example/features/cart/presentation/states/selected_items_provider.dart';
import 'package:cart_example/features/cart/presentation/states/sum_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/payment_service.dart';
import '../../domain/cart_item.dart';

class ProceedPaymentButton extends ConsumerStatefulWidget {
  const ProceedPaymentButton({super.key});

  @override
  ConsumerState<ProceedPaymentButton> createState() =>
      _ProceedPaymentButtonState();
}

class _ProceedPaymentButtonState extends ConsumerState<ProceedPaymentButton> {
  Future<void>? _future;

  @override
  Widget build(BuildContext context) {
    final selectedCartItems = ref.watch(selectedItemsProvider);
    final totalAmount = ref.watch(sumProvider);
    final isSelectedEmpty = selectedCartItems.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          final bool isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final bool hasError = snapshot.hasError;
          final bool canPress = !isSelectedEmpty && !isLoading;

          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (canPress || hasError) {
                  _future = _handlePayment(selectedCartItems);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: hasError ? Colors.red : null,
              ),
              child: _ButtonChild(
                isLoading: isLoading,
                hasError: hasError,
                totalAmount: totalAmount,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handlePayment(List<CartItem> items) async {
    try {
      await ref.read(paymentServiceProvider).pay(items);
      ref.read(cartItemsProvider.notifier).clear();
    } catch (e) {
      rethrow;
    }
  }
}

class _ButtonChild extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final int totalAmount;

  const _ButtonChild({
    required this.isLoading,
    required this.hasError,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (hasError) {
      return Text(
        '다시 시도 (₩${NumberFormat('###,###,###').format(totalAmount)})',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return Text(
      totalAmount <= 0
          ? '물건을 담아주세요.'
          : '결제하기 (₩${NumberFormat('###,###,###').format(totalAmount)})',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
