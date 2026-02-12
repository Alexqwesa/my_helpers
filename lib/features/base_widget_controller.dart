

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Type alias to clearly indicate the listen function signature.
typedef RefListener =
void Function <Y0>(ProviderListenable<Y0>, void Function (Y0?, Y0) , { void Function (Object, StackTrace) ? onError})  ;
// ProviderSubscription<T> Function<T>(
//     AlwaysAliveProviderListenable<T>, void Function(T?, T),
//     { void Function(Object, StackTrace)? onError});

typedef RefReader = T Function<T>(ProviderListenable<T> provider);
typedef RefRefreshFunction = T Function<T>(ProviderBase<T> provider);

class RefStub {
  RefStub({
    required this.read,
    required this.listen,
    required this.invalidate,
    required this.refresh,
  });

  RefReader read;
  RefListener listen;
  void Function(ProviderBase provider) invalidate;
  RefRefreshFunction refresh;

  factory RefStub.fromRef(dynamic ref) {
    if (ref is! Ref && ref is! WidgetRef) {
      throw ArgumentError('ref must be either a Ref or WidgetRef.');
    }
    return RefStub(
      read: ref.read,
      listen: ref.listen,
      invalidate: ref.invalidate,
      refresh: ref.refresh,
    );
  }

  void bind(dynamic ref) {
    if (ref is! Ref && ref is! WidgetRef) {
      throw ArgumentError('ref must be either a Ref or WidgetRef.');
    }
    read = ref.read;
    listen = ref.listen;
    invalidate = ref.invalidate;
    refresh = ref.refresh;
  }
}

class BaseWidgetController {
  BaseWidgetController(dynamic refOriginal) : ref = RefStub.fromRef(refOriginal);

  final RefStub ref;

  void bindRef(dynamic refNew) => ref.bind(refNew);
}