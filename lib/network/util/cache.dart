/*
 * Copyright 2023 WangHongEn
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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

  V? putIfAbsent(K key, V Function() ifAbsent) {
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final value = ifAbsent();
    set(key, value);
    return value;
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