# 매쓰튜터 프로젝트 상태 관리 가이드

## 서문

매쓰튜터 프로젝트에서 주된 상태 관리는 [riverpod](https://riverpod.dev/)로 합니다. 보다 자세한 사용법을 알고 싶으시면 [문서](https://riverpod.dev/ko/docs/introduction/why_riverpod)를 참조하시기 바랍니다.

`riverpod`을 사용하는 이유는, `riverpod`에서 상태를 제공하는 방법인 `Provider`들이 마지 Widget Tree처럼 `Ref` 트리 내에서 관리되어 상태 간의 참조가 매우 쉽습니다. 특정 상태가 다른 상태의 업데이트에 의존하는 경우 `bloc` 에서는 listener를 붙이는 식으로 일일이 대응해주어야 하는 문제점이 있었으나 `riverpod`에서는 그저 `watch` 해주는 것으로 끝입니다.

또, 상태의 `dispose`를 자동으로 관리하도록 맡길 수도 있고, 앱 전역에서 널리 쓰이는 상태나, 불러오기 비싼 상태는 수동으로 `dispose` 할 때까지 살려둘 수도 있어 캐싱도 쉽게 할 수 있습니다.

이 문서에서는 `riverpod` 패키지를 사용하여 상태를 관리하는 방법에 대해 하나의 예시를 들어 설명하겠습니다. 화면에 종속된 임시 상태(ephemeral state), 원격 호출로 불러온 상태, 그리고 이 상태들 간의 의존성에 의한 업데이트 등을 총 망라하여 설명하겠습니다.

## 준비

이 문서에서는 상태 관리에 대해 설명하기 위하여 화면을 하나 만들 것입니다. 이 화면은 다음과 같은 기능을 가지고 있습니다.

- 장바구니 화면
- 장바구니 항목 추가/삭제 가능
- 장바구니 항목 숫자 변경 가능
- 각 항목별 가격 표시
- 가격 총합 표시
- 주문할 항목 선택 가능
- 결제 가능

## 모델 정의

본격적인 구현에 앞서 필요한 데이터 모델을 정의하겠습니다. `domain` 폴더 내에 정의하면 되겠네요.

```dart
// domain/cart_item.dart

class CartItem {
  final String id;
  final String name;
  final int price;
  final int quantity;

  CartItem(
      {required this.id,
      required this.name,
      required this.price,
      this.quantity = 1});
}
```

`quantity`는 항상 0보다 커야 하기 때문에 initializer에 `assert`를 주겠습니다.

```dart
// domain/cart_item.dart
class CartItem {
  final String id;
  final String name;
  final int price;
  final int quantity;

  CartItem(
      {required this.id,
      required this.name,
      required this.price,
      this.quantity = 1})
      : assert(quantity > 0);
}

```

`CartItem` 의 동일성을 비교하고, json serialization도 해야 하는 등 추가 기능이 필요해서 VSCode 확장 플러그인 중 하나인 [Dart Data Class Generator](https://marketplace.cursorapi.com/items?itemName=hzgood.dart-data-class-generator)를 사용해서 기능을 추가해보겠습니다.

```dart
// domain/cart_item.dart

import 'dart:convert';

class CartItem {
  final String id;
  final String name;
  final int price;
  final int quantity;

  CartItem(
      {required this.id,
      required this.name,
      required this.price,
      this.quantity = 1})
      : assert(quantity > 0);

  CartItem copyWith({
    String? id,
    String? name,
    int? price,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: map['price'] as int,
      quantity: map['quantity'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory CartItem.fromJson(String source) =>
      CartItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, price: $price, quantity: $quantity)';
  }

  @override
  bool operator ==(covariant CartItem other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.name == name &&
        other.price == price &&
        other.quantity == quantity;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ price.hashCode ^ quantity.hashCode;
  }
}
```

## 서비스 정의

원격 서버에서 장바구니 내용을 불러오고 내용을 조작할 수 있는 서비스가 필요합니다. 정의해보도록 하겠습니다. `application` 폴더에 정의하면 되겠네요.

이 `service` 는 `riverpod`을 통해서 의존성 주입이 될 것이기 때문에 `Provider`로 객체를 제공할 수 있도록 합니다.

```dart
import 'package:cart_example/features/cart/data/cart_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cart_item.dart';

/// 이 변수를 통해 다른 [Provider] 내에서 [CartService]를 참조할 수 있습니다.
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService(ref);
});

class CartService {
  final Ref ref;
  late final repository = ref.read(cartRepositoryProvider);
  CartService(this.ref);

  Future<List<CartItem>> getCartItems() async {
    final response = await _client.getCartItems();
    return response.map((e) => CartItem.fromMap(e)).toList();
  }

  Future<void> addCartItem(CartItem item) async {
    await repository.addCartItem(item);
  }

  Future<void> removeCartItem(String id) async {
    await repository.removeCartItem(id);
  }

  Future<void> updateCartItem(CartItem item) async {
    await repository.updateCartItem(item);
  }
}
```

## 상태 정의

자 이제 본격적으로 상태를 정의해볼 겁니다. `riverpod`에서는 의존하는 상태가 변경되면 알아서 상태를 업데이트 할 수 있기 때문에 상태 관리가 매우 편합니다. 백문이 불여일견이니 바로 들어가보시죠. 상태를 가장 바닥부터 하나씩 쌓아올라 가보겠습니다.

### 장바구니

먼저, 장바구니 항목을 불러와 저장해두는 상태를 정의해보겠습니다. 원격 상태를 정의할 때에는 `FutureProvider`를 쓰거나 `Notifier`를 상속한 클래스를 만들면 편합니다.

그냥 불러오고 끝이면 `FutureProvider`를 쓰면 편합니다. 그러나 불러온 상태에 대해 추가/변경 등 업데이트가 이루어져야 하는, 말인 즉 Side-effect가 이루어져야 한다면 따로 메서드를 정의할 수 있는 `Notifier`가 좋습니다.

장바구니에는 추가/변경/삭제가 이루어져야 하기 때문에 `Notifier`를 써야 하지만, 일단 장바구니를 불러오기만 한다 치고 `FutureProvider` 를 쓰는 예를 작성해보겠습니다.

`presentation` 폴더 내, `states` 폴더에 정의하면 되겠죠.

```dart
// presentation/states/cart_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import './application/cart_service.dart';
import './domain/cart_item.dart';

final cartItemsProvider = FutureProvider<List<CartItem>>((ref) async {
  final cartService = ref.read(cartServiceProvider);
  return cartService.getCartItems();
});
```

이렇게 정의한 `FutureProvider`는

```dart
final AsyncValue<List<CartItem>> cartItemsState = ref.watch(cartItemsProvider);
```

와 같은 식으로 값을 참조할 수 있고, 최초로 참조되는 순간에 api를 호출합니다. `dispose` 되거나 `invalidate` 되기 전까지는 이 상태를 그대로 유지합니다.

`AsyncValue` 는 로딩 상태, 에러, 값을 담고 있어 원격 호출 상태를 쉽게 알 수 있습니다. 자세한 이야기는 뒤에서 하겠습니다.

자, 앞서 말했듯이 장바구니 내 아이템은 추가/변경/삭제가 가능해야 합니다. 그러나 우리나 `FutureProvider`에 대해서 할 수 있는 건 `ref.invalidate()` 호출을 통한 새로고침밖에 없습니다. 내용을 직접 바꾸는 것은 허용되지 않습니다.

이때 필요한 것이 바로 `Notifier` 입니다. `Notifier`는 코드 생성을 통해서만 생성됩니다. 좀 이상한 방식이긴 한데 편하긴 매우 편합니다. 위 `FutureProvider`를 `AsyncNotifierProvider`로 바꿔 보겠습니다.

```dart
// presentation/states/cart_items_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/cart_service.dart';
import '../domain/cart_item.dart';

part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  @override
  Future<List<CartItem>> build() async {
    final cartService = ref.read(cartServiceProvider);
    return cartService.getCartItems();
  }
}
```

이렇게 정의해주시면 됩니다. 차이점은

- 변수가 아니라 클래스로 정의됨
- 만들어지지 않은 가상 클래스를 미리 상속함. 가상 클래스의 이름은 반드시 `_${원래 클래스 이름}`이어야 함.
- `build` 메서드를 반드시 오버라이드해야 함.

이렇게 해두고 `fvm dart run build_runner build --delete-conflicting-outputs` 를 터미널에서 실행해주시면 `presentation/states/cart_items_provider.g.dart` 파일이 생성되고 그 파일 아래 `_$CartItems` 클래스가 정의됩니다.

이렇게만 구현하면 작동 방식은 `FutureProvider`와 정확히 똑같습니다. 다만 클래스로 정의되어 있기 때문에 클래스 내 메서드를 구현할 수 있습니다. 먼저 장바구니 아이템 추가 메서드를 만들어 보겠습니다.

```dart
// presentation/states/cart_items_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/cart_service.dart';
import '../domain/cart_item.dart';

part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  @override
  Future<List<CartItem>> build() async {
    ...
  }

  Future<void> addCartItem(CartItem item) async {
    final cartService = ref.read(cartServiceProvider);
    await cartService.addCartItem(item);
    state = AsyncValue.data([...state.valueOrNull ?? [], item]);
  }
}
```

`addCartItem()` 메서드에서는 두 가지 일을 했습니다.

- 원격 호출을 통해 서버에 장바구니 항목을 추가함
- `state`에 새로운 `item`을 추가해서 업데이트 함.

`state` 변수를 직접 변경하는 것은 통하지 않습니다. `state` 객체 자체의 해시값이 바뀌어야 업데이트가 전파되기 때문에 새로운 객체를 대입해주어야 합니다.

그러면 나머지 메서드도 구현해보겠습니다.

```dart

// presentation/states/cart_items_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/cart_service.dart';
import '../../domain/cart_item.dart';
part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  ...

  Future<void> removeCartItem(String id) async {
    final cartService = ref.read(cartServiceProvider);
    await cartService.removeCartItem(id);
    state = AsyncValue.data(
        state.valueOrNull?.where((e) => e.id != id).toList() ?? []);
  }

  Future<void> updateCartItem(CartItem item) async {
    final cartService = ref.read(cartServiceProvider);
    await cartService.updateCartItem(item);
    state = AsyncValue.data(
        state.valueOrNull?.map((e) => e.id == item.id ? item : e).toList() ??
            []);
  }
}

```

잠깐 약간의 refactoring을 하겠습니다. 메서드에서 매번

```dart
final cartService = ref.read(cartServiceProvider);
```

하니까 보기가 매우 안 좋고 귀찮습니다. 클래스의 멤버변수로 한번 선언해보겠습니다.

```dart

// presentation/states/cart_items_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/cart_service.dart';
import '../domain/cart_item.dart';

part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  final cartService = ref.read(cartServiceProvider);
  @override
  Future<List<CartItem>> build() async {
    ...
  }

  Future<void> addCartItem(CartItem item) async {
    ...
  }

    Future<void> removeCartItem(CartItem item) async {
    ...
  }

  Future<void> updateCartItem(CartItem item) async {
    ...
  }
}
```

그런데 이렇게 하면 에러를 뿜습니다. 왜냐하면 `ref` 는 클래스의 초기화가 끝난 다음에야 참조가 가능하기 때문입니다.

이럴 때는 `late` 키워드를 사용해 `service`를 lazy하게 선언해주면 됩니다.

```dart

// presentation/states/cart_items_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/cart_service.dart';
import '../domain/cart_item.dart';

part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  late final cartService = ref.read(cartServiceProvider);
  @override
  Future<List<CartItem>> build() async {
    ...
  }

  Future<void> addCartItem(CartItem item) async {
    ...
  }

    Future<void> removeCartItem(CartItem item) async {
    ...
  }

  Future<void> updateCartItem(CartItem item) async {
    ...
  }
}
```

이렇게 하면 `service`가 처음 호출되는 순간에 선언이 이루어지고, 우리는 항상 `service`를 메서드에서 참조하고 있기 때문에 언제나 초기화가 이루어진 후에 호출된다는 걸 압니다. 이렇게 하면 매번 `service`를 선언하고 호출할 필요가 없습니다.

장바구니 아이템을 불러 왔으니 다른 상태들도 한번 살펴보겠습니다.

### 주문할 항목

장바구니 항목을 항상 모두 주문하는 건 아닙니다. 주문할 항목을 선택할 수 있으면 편하겠죠. 주문할 항목의 요구사양을 한번 정의해보겠습니다.

- 처음 장바구니를 불러올 때는 모두 선택
- 장바구니 항목이 변경되어도 선택 상태는 유지
- 장바구니 항목이 삭제되었을 때는 삭제된 항목이 선택되어 있다면 삭제
- 선택 항목 추가 변경이 가능해야 함.

`Notifier` 정의를 통해 한번 만들어 보겠습니다. 원격 호출이 없기 때문에 기본 구현은 매우 간단합니다.

```dart
// presentation/states/selected_items_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/cart_item.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  @override
  List<CartItem> build() {
    return [];
  }
}
```

너무 간단합니다. 그러나 몇 가지 기능들을 추가해야 합니다. 선택 항목 추가 변경 메서드를 만들어 보겠습니다.

```dart
// presentation/states/selected_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/cart_item.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  @override
  List<CartItem> build() {
    return [];
  }

  void addItem(CartItem item) {
    state = [...state, item];
  }

  void removeItem(CartItem item) {
    state = state.where((item) => item.id != item.id).toList();
  }
}
```

앞에서 해봤던 것과 마찬가지입니다. 이제 장바구니 항목이 변경되었을 때에 대비해야 합니다. 만약 장바구니 항목 중에 삭제된 항목이 있는데 이게 선택된 항목에 계속 남아 있으면 안 됩니다.

장바구니 항목의 변경 상황을 구독해야 합니다.

상태를 구독하는 방법은 2가지가 있습니다.

- `build()` 메서드 내에서 `ref.watch()` 를 통해 구독하기
- `build()` 메서드 내에서 `ref.listen()` 을 통해 구독하기

첫 번째 경우에는 장바구니 상태가 변할 때마다 `build()` 메서드가 다시 실행될 겁니다. 이러면 기존에 있던 선택 항목이 모두 사라지겠죠? 그래서 안 쓸 겁니다.

두 번째는 그냥 `build()` 메서드 내에서 리스너만 하나 선언해주는 겁니다. 이 리스너는 `Notifier` 내에 있는 멤버 변수들에 접근할 수 있기 때문에 상태를 업데이트 해줄 수 있습니다.

```dart
// presentation/states/selected_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/cart_item.dart';
import 'cart_items_provider.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  @override
  List<CartItem> build() {
    ref.listen(cartItemsProvider, (previous, next) {
    /// 만약 현재 상태에 값이 존재하고
    /// 이전 상태 값 배열의 길이보다 현재 상태 값 배열의 길이가 짧으면
      if (next.hasValue && (previous?.valueOrNull?.length ?? 0) > next.value.length) {
        /// 장바구니 항목에 없는 항목은 선택된 항목에서도 제외한다.
        state = state.where((item) => next.value.contains(item)).toList();
      }
    });
    return [];
  }
  ...
}
```

`listen` 내 콜백 함수의 패러미터는 이전 상태과 현재 상태를 보여줍니다. 둘을 비교해서 어느 경우에 어떤 행동을 취할지 결정할 수 있습니다.

장바구니의 현재 상태가 값을 가지고 있고(에러나 로딩 상태가 아니고), 이전 상태보다 현재 상태의 길이가 짧을 때(항목이 삭제되었을 때) 현재 선택 항목 중, 현재 장바구니 항목에 포함되어 있는 선택 항목만 남기도록 업데이트 하는 코드입니다.

앗! 그런데 하나 빠뜨린 게 있군요. 처음 장바구니 항목이 로드되었을 때에는 모두 선택을 하도록 해야 합니다.

그러면 장바구니의 이전 상태가 로딩이고, 현재 상태에 값이 존재하고, 선택 항목 상태가 `[]`이라면 최초에 장바구니가 불러와진 상태일 것이니 모든 항목을 선택 항목에 넣어주도록 합시다!

하나 더, 이미 선택 항목이 있는 경우에도, 장바구니를 새로고침 했을 때 혹시 서버에서 다른 데이터를 내려줄 수도 있으니, 서버에서 없다고 한 항목은 선택 항목에서도 없애주도록 합시다.

```dart
// presentation/states/selected_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/cart_item.dart';
import 'cart_items_provider.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  @override
  List<CartItem> build() {
    ref.listen(cartItemsProvider, (previous, next) {
        if (next.hasValue &&
        (previous?.valueOrNull?.length ?? 0) > next.value!.length) {
          state =
        state.where((item) => currentCartItems.value!.contains(item)).toList();

    }
    // 만약 이전 상태가 로딩이었고 현재 상태에 값이 있으면
    if (previous?.isLoading == true && next.hasValue) {
        // 완전 처음 상태라면 모두 선택된 항목에 추가
      if (state.isEmpty) {
        state = next.value ?? [];
      } else {
        // 그게 아니라면 아까처럼 장바구니 항목에 없는 항목은 삭제
            state =
        state.where((item) => currentCartItems.value!.contains(item)).toList();

      }
    }
    });
    return [];
  }
...
}

```

흠... 그런데 `listen()`에 들어가는 콜백함수가 너무 길어진 것 같군요. 그리고 장바구니 항목에 없는 항목은 지우도록 하는 라인이 중복되고 있습니다. 각각 private 메서드로 빼주도록 합시다.

```dart
// presentation/states/selected_items_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/cart_item.dart';
import 'cart_items_provider.dart';

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
...
}
```

좋습니다. 깔끔하게 된 것 같습니다. 주문할 항목이 생겼으니 가격의 총합도 매겨봅시다.

### 주문 금액 총합

물론 가격의 총합을 UI 내에서 계산해서 계산된 값을 보여줘도 좋지만 최대한 로직을 UI에서 분리하기 위해 이것도 하나의 `Provider`로 표현해보겠습니다.

이 `Provider`는 순수하게 다른 `Provider`에게 의존하여 값을 제공하고 외부에서 업데이트 할 필요가 없기 때문에 그냥 `Provider`로 선언하겠습니다.

```dart
// presentation/states/sum_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selected_items_provider.dart';

final sumProvider = Provider<int>((ref) {
  return ref
      .watch(selectedItemsProvider)
      .fold<int>(0, (acc, current) => acc + (current.price * current.quantity));
});
```

이제 `selectedItemsProvider`의 값이 바뀔 때마다 `sumProvider`도 업데이트 될 겁니다.

## 정리

자 이제 상태는 모두 준비되었습니다.

- A. 서버에서 불러온 장바구니 상태
- B. 주문하기 위해 선택한 항목 상태
- C. 선택한 항목의 가격 총합 상태

C는 B에 의존하고 B는 A에 의존합니다. 하나가 업데이트 될 때 의존하고 있는 상태도 수동으로 업데이트 해줄 필요 없이 편하게 업데이트 하면 됩니다.

상태가 모두 준비되었으니 이 상태들을 화면에 멋지게 표현해봅시다.

## 화면 구현

이 챕터에서는 화면에서 어떻게 `Provider`의 값들을 참조하여 화면에 보여줄 수 있는지 확인해보고, 상태가 변할 때 필요한 UI 컴포넌트만 업데이트하여 퍼포먼스 최적화를 어떻게 이루어내는지에 대해 알아보겠습니다.

또한, 업데이트 작업 같은 **Side-effect** 는 어떻게 처리하는지도 같이 보여드리겠습니다.

기본적인 컴포넌트 위젯은 미리 `presentation/widgets/` 폴더 아래에 만들어 두었으니 참고 바랍니다.

먼저 스켈레톤 화면을 만들어 보겠습니다.

```dart
// presentation/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          children: [],
        ));
  }
}
```

앱바는 구색 갖추기용으로 그냥 장바구니라고 이름 붙인 `AppBar`를 달아주었습니다.

본격적인 작업은 `Column` 위젯 내에서 해보겠습니다.

맨 위에 장바구니 목록의 헤더를 만들어 보겠습니다. 헤더는 따로 역할은 없고 그냥 전체 선택 체크 박스를 하나 만들어줄 생각입니다.

일단 오른쪽에 붙은 체크 박스를 하나 만들어 봅시다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Checkbox(value: false, onChanged: (value) {}),
            ],
          )
        ],
      ),
    );
  }
}
```

이게 작동할 리는 없겠죠. 이 체크박스에 필요한 것은 무엇일까요?

- 선택한 항목
- 장바구니 항목
- 선택한 항목을 변경할 수 있는 기능 (장바구니 항목 전체를 넣거나 완전히 비우거나)

`CartScreen` 내에서도 그냥 `ref.watch()`를 해서 상태를 가져올 수 있지만, 그렇게 되면 가져온 상태가 변경될 때마다 `CartScreen` 전체를 `rebuild` 하려고 할 겁니다.

국소적인 업데이트를 하려면 `Consumer` 위젯으로 한 번 감싸주면 됩니다. 그러면 `Consumer` 위젯 내의 `builder` 안에서 참조된 상태에 대해서만 반응하여 `rebuild` 합니다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../states/cart_items_provider.dart';
import '../states/selected_items_provider.dart';

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
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final selectedItems = ref.watch(selectedItemsProvider);
                  final cartItems = ref.watch(cartItemsProvider);
                  final allSelected = const DeepCollectionEquality()
                      .equals(selectedItems, cartItems.valueOrNull ?? []);
                  return Checkbox(
                    value: allSelected,
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(selectedItemsProvider.notifier).toggleAll(value);
                    },
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
```

만들고 보니 선택된 항목을 한번에 다 바꾸는 방법이 없어 `SelectedItems` 클래스 내에 `toggleAll` 함수를 하나 추가해줬습니다.

```dart
// presentation/states/selected_items_provider.dart

import 'package:cart_example/features/cart/presentation/states/cart_items_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/cart_item.dart';

part 'selected_items_provider.g.dart';

@riverpod
class SelectedItems extends _$SelectedItems {
  ......
  ......

  void toggleAll(bool value) {
    state = value ? ref.watch(cartItemsProvider).valueOrNull ?? [] : [];
  }
}

```

`CheckBox` 하나 만들었는데 코드가 많이 길어졌습니다. `ConsumerWidget`으로 따로 분리하면 깔끔할 것 같군요. 앞으로도 특정 상태에 의존하는 하나의 덩어리 컴포넌트는 `ConsumerWidget`으로 따로 빼서 관리하도록 하겠습니다.

```dart
//presentation/widgets/select_all_checkbox.dart

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
    final allSelected = const DeepCollectionEquality()
        .equals(selectedItems, cartItems.valueOrNull ?? []);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Checkbox(
          value: allSelected,
          onChanged: (value) {
            if (value == null) return;
            ref.read(selectedItemsProvider.notifier).toggleAll(value);
          },
        ),
      ],
    );
  }
}
```

```dart
// presentation/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        ],
      ),
    );
  }
}

```

앗, 그런데 이런 비슷한 위젯을 다른 곳에서도 쓰면 어떻게 하냐고요? 그러면 상태와 상관 없는 껍데기 체크박스 컴포넌트를 따로 분리해서 공유해서 쓰면 됩니다. 여기서는 화면이 하나이기 때문에 굳이 그러지 않은 것입니다.

---

이제 드디어 장바구니 항목 목록을 표시해봅시다. 장바구니 항목에 일단 필요한 것은 장바구니 항목 상태겠죠? `ConsumerWidget`을 따로 분리해서 만들어 봅시다. 일단 상태까지 불러와봅시다.

```dart
// presentation/widgets/cart_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/cart_items_provider.dart';

class CartList extends ConsumerWidget {
  const CartList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    return Container();
  }
}
```

`cartItems`는 그냥 `List`가 아니라 `AsyncValue<List<CartItem>>`입니다. 고로 값이 있을 수도, 없을 수도 있다는 것이죠. 이 각각의 상태들을 표시하는 것을 도와주는 메서드가 있습니다. 바로 `AsyncValue` 클래스의 `when` 메서드입니다. 한번 보시죠.

```dart
// presentation/widgets/cart_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/cart_items_provider.dart';

class CartList extends ConsumerWidget {
  const CartList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    cartItems.when(data: data, error: error, loading: loading);
    return Container();
  }
}
```

와우, 완료 시, 에러 시, 로딩 중일 시 어떤 위젯을 반환할지 모두 콜백 함수로 구현할 수 있게 제공하고 있습니다! 그러면 이렇게 경우의 수를 나눠서 구현해보겠습니다.

- 로딩 중일 때 -> 로딩 인디케이터 보여줌
- 로드에 실패했을 때 -> 에러 화면 보여주고 다시 시도할 수 있게 해줌.
- 로드했는데 데이터가 없을 때 -> 안내 문구와 함께 빈 화면 보여줌
- 로드했고 데이터도 있을 때 -> 드디어! `CartItemView`를 사용하여 리스트 보여줌

```dart
// presentation/widgets/cart_list.dart

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
              cartItem: item,
              onQuantityChanged: ,
              onDelete: ,
              isSelected: ,
              onSelectedChanged: ,
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
```
좋습니다. 그런데 `CartItemView`가 많은 걸 요구하고 있습니다. 기능(함수, 메서드)들은 `CartList` 위젯 내에서 참조해서 넘겨줘도 무방합니다. 그러나 `isSelected` 상태를 넘겨주려면 또 `selectedItemsProvider`를 참조해야 하는데 이러면 `selectedItemsProvider`가 업데이트 될 때마다 리스트 전체가 업데이트 되는 수가 있습니다. 아주 안 좋은 거죠. 어쩔 수 없이 `CartItemView`도 `ConsumerStatefulWidget`으로 바꿔줍시다.(원래 `StatefulWidget`이었기 때문에 그렇게 하는 겁니다.)

최종적으로 `CartItemView`는 이렇게 생기게 됩니다. 대부분의 로직이 내부로 숨었습니다.

```dart
// presentation/widgets/cart_item_view.dart

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
```

여기서 `Notifier` 내부의 메서드를 호출하는 방법이 나옵니다.

```dart
ref.read(cartItemsProvider.notifier).addItem();
```

이 구문을 보시면 되는데요. 일단 `watch`가 아니라 `read`를 쓴 이유는, 이 참조가 이루어진 곳에서 변경사항에 대응하여 `rebuild` 하는 것을 방지하는 것입니다. `notifier` 를 참조하면 클래스 내부에 있는 퍼블릭 멤버 변수들과 퍼블릭 메서드들을 참조할 수 있습니다.

그러면 이 리스트를 화면에 추가해봅시다.

```dart
// presentation/screens/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/cart_list.dart';
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
          
        ],
      ),
    );
  }
}
```

---

이제 마지막으로 결제하기 버튼도 구현하겠습니다. 원리는 같습니다.

```dart
// presentation/widgets/proceed_payment_button.dart

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
              style: ElevatedButton.styleFrom(....),
              child: _ButtonChild(.....),
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
...
```

복잡한 부분은 싹 날리고 핵심만 간추려 봤습니다.

여기서 가장 눈여겨 보셔야 할 부분이 바로 `handlePayment()`와 `_future` 입니다.

결제하기 버튼을 누를 때 `_future`에다가 `handlerPayment()`을 호출해서 넣어주는데요 이렇게 하면 `FutureBuilder`에서 해당 `Future`의 상태를 받아올 수 있습니다.

그리고 `handlePayment()`에서 결제가 성공한 후 장바구니를 비워주는 로직까지 확인해주시면 되겠습니다. `clear()` 메서드 원래 없지 않았냐고요? 살포시 추가해주면 되겠습니다 ㅎㅎㅎ

```dart
// presentation/states/cart_items_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/cart_service.dart';
import '../../domain/cart_item.dart';
part 'cart_items_provider.g.dart';

@riverpod
class CartItems extends _$CartItems {
  late final cartService = ref.read(cartServiceProvider);
  @override
  Future<List<CartItem>> build() async {...
  }

  Future<void> addCartItem(CartItem item) async {...
  }

  Future<void> removeCartItem(String id) async {...
  }

  Future<void> updateCartItem(CartItem item) async {...
  }
    // 만들었습니다 ㅎㅎㅎ
  void clear() {
    state = const AsyncValue.data([]);
  }
}
```

그렇게 해서 화면을 구현한 위젯인 `CartScreen`은 다음과 같이 깔끔하게 구현되었습니다.

```dart
// presentation/screens/cart_screen.dart

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
```

## 마무리

매쓰튜터 프로젝트에서는 이런 방식으로 상태를 관리해 나가려고 합니다. `OOController`를 선언하거나 `Animation`을 다루는 경우, 혹은 `Side-effect` 관리를 위해 `Future` 선언이 필요한 경우가 아니라면 웬만하면 `StatefulWidget`을 쓰지 않으려고 합니다. 웬만한 상태는 `Provider`를 통해 제공하고, 업데이트 하고, 서로 간의 의존성을 관리하려 합니다.

긴 글 읽어주셔서 감사하고, 문의 사항이 있으시면 [Discussion](https://github.com/tksuns12/cart_example/discussions)쪽에 올려주시면 감사하겠습니다.