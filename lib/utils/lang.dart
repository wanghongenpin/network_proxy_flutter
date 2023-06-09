class ValueWrap<V> {
  V? _v;

  void set(V v) => this._v = v;

  V? get() => this._v;

  bool isNull() => this._v == null;
}
