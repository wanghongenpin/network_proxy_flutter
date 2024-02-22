

import 'dart:async';

class ExpiringCache<K, V> {
  final Duration duration;
  final _cache = <K, V>{};
  final _expirationTimes = <K, Timer>{};

  ExpiringCache(this.duration);

  void set(K key, V value) {
    _expirationTimes[key]?.cancel();
    _cache[key] = value;
    _expirationTimes[key] = Timer(duration, () => remove(key));
  }

  V? get(K key) {
    return _cache[key];
  }

  remove(K key) {
    _expirationTimes[key]?.cancel();
    _expirationTimes.remove(key);
    _cache.remove(key);
  }

}