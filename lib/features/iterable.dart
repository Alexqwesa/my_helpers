Iterable<(T, S?)> zipIterable<T, S>(List<T> keys, List<S> values) sync* {
  assert(keys.length == values.length, 'Keys and values must have the same length');
  final len = keys.length;
  for (var i = 0; i < len; i++) {
    yield (keys[i], values.length > i ? values[i] : null);
  }
}

Iterable<MapEntry<T, S>> zipKeyValue<T, S>(List<T> keys, List<S> values) sync* {
  assert(keys.length == values.length, 'Keys and values must have the same length');
  for (var i = 0; i < keys.length; i++) {
    yield MapEntry(keys[i], values[i]);
  }
}