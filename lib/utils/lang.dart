class ValueWrap<V> {
  V? _v;
  ValueWrap();

  factory ValueWrap.of(V v) {
     var valueWrap = ValueWrap<V>();
      valueWrap._v = v;
      return valueWrap;
  }

  void set(V? v) => this._v = v;

  V? get() => this._v;

  bool isNull() => this._v == null;
}

class Strings {
  static MapEntry<String, String>? splitFirst(String str, Pattern pattern) {
    var index = str.indexOf(pattern);
    if (index > 0) {
      return MapEntry(str.substring(0, index), str.substring(index + 1));
    }

    return null;
  }

  static String trimWrap(String str, String wrap) {
    if (str.startsWith(wrap) && str.endsWith(wrap)) {
      return str.substring(1, str.length - 1);
    }
    return str;
  }
}

class Pair<K, V> {
  final K key;
  final V value;

  Pair(this.key, this.value);
}

class Maps {
  static K? getKey<K, V>(Map<K, V> map, V? value) {
    for (var entry in map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return null;
  }
}
