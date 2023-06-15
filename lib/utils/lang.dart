class ValueWrap<V> {
  V? _v;

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
}
