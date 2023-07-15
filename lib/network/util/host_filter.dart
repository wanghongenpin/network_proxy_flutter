void main() {
  print(HostFilter.filter("stackoverflow.com"));
}

class HostFilter {
  /// 白名单
  static final Whites whitelist = Whites();

  /// 黑名单
  static final Blacks blacklist = Blacks();

  /// 是否过滤
  static bool filter(String? host) {
    if (host == null) {
      return false;
    }

    //如果白名单不为空，不在白名单里都是黑名单
    if (whitelist.enabled) {
      return whitelist.list.every((element) => !element.hasMatch(host));
    }

    if (blacklist.enabled) {
      return blacklist.list.any((element) => element.hasMatch(host));
    }
    return false;
  }
}

abstract class HostList {
  /// 列表
  final List<RegExp> list = [];
  bool enabled = false;

  void load(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }
    List? list = map['list'];
    this.list.clear();
    list?.forEach((element) {
      this.list.add(RegExp(element));
    });
    enabled = map['enabled'] == true;
  }

  void add(String reg) {
    var regExp = RegExp(reg.replaceAll("*", ".*"));
    list.removeWhere((element) => element.pattern == regExp.pattern);
    list.add(regExp);
  }

  void remove(String reg) {
    list.removeWhere((element) => element.pattern == reg.replaceAll("*", ".*"));
  }

  void removeIndex(List<int> index) {
    for (var element in index) {
      list.removeAt(element);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'list': list.map((e) => e.pattern).toList(),
      'enabled': enabled,
    };
  }
}

class Whites extends HostList {}

class Blacks extends HostList {
  Blacks() {
    enabled = true;
    list.add(RegExp(".*.github.com"));
    list.add(RegExp("github.com"));
    list.add(RegExp(".*.google.com"));
    list.add(RegExp(".*.apple.com"));
    list.add(RegExp(".*.icloud.com"));
  }
}
