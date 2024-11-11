import 'package:cart_example/features/cart/domain/cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

class PaymentService {
  Future<void> pay(List<CartItem> items) async {
    await Future.delayed(const Duration(seconds: 2));
  }
}
