Iterable<(T, S?)> zipIterable<T, S>(Iterable<T> keys, Iterable<S> values) sync* {
  final valueIt = values.iterator;
  for (final k in keys) {
    S? v;
    if (valueIt.moveNext()) {
      v = valueIt.current;
    }
    yield (k, v); // can't get length from iterable(((
  }
}

Iterable<MapEntry<T, S>> zipKeyValue<T, S>(Iterable<T> keys, Iterable<S> values) sync* {
  final keyIt = keys.iterator;
  final valIt = values.iterator;

  while (true) {
    final hasKey = keyIt.moveNext();
    final hasVal = valIt.moveNext();

    assert(hasKey == hasVal, 'Keys and values must have the same length');

    if (!hasKey || !hasVal) break;
    yield MapEntry(keyIt.current, valIt.current);
  }
}

extension IntNotZeroX on int? {
  bool get hasValue => this != null && this != 0;
}
