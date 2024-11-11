import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/cart_list.dart';
import '../widgets/proceed_payment_button.dart';
import '../widgets/select_all_checkbox.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
      ),
      body: const Column(
        children: [
          SelectAllCheckbox(),
          Expanded(child: CartList()),
          ProceedPaymentButton(),
        ],
      ),
    );
  }
}
