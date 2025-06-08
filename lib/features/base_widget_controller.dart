

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
  final RefReader read;
  final RefListener listen;
  final void Function(ProviderBase provider) invalidate;
  final RefRefreshFunction refresh;

  const RefStub({
    required this.read,
    required this.listen,
    required this.invalidate,
    required this.refresh,
  });

  /// A factory constructor to easily create a RefStub from a Ref.
  factory RefStub.fromRef(dynamic ref) {
    if (!(ref is Ref || ref is WidgetRef)) {
      throw ArgumentError('ref must be either a Ref or WidgetRef.');
    }
    return RefStub(
      read: ref.read,
      listen: ref.listen,
      invalidate: ref.invalidate,
      refresh: ref.refresh,
    );
  }
}

class BaseWidgetController {
  late final RefStub ref;

  BaseWidgetController(dynamic refOriginal) {
    ref = RefStub.fromRef(refOriginal);
  }
}
