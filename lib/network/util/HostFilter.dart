import 'dart:collection';

void main() {
  print(HostFilter.filter("www.apple.com"));
}

class HostFilter {
  /// 白名单
  static final Set<RegExp> _whitelist = buildWhitelist();

  /// 黑名单
  static final Set<RegExp> _blacklist = buildBlacks();

  /// 构建白名单
  static Set<RegExp> buildWhitelist() {
    List<String> whites = [];
    // whites.add("*.google.com");
    // whites.add("www.baidu.com");

    Set<RegExp> whitelist = HashSet<RegExp>();
    for (var white in whites) {
      whitelist.add(RegExp(white));
    }

    return whitelist;
  }

  /// 构建黑名单
  static Set<RegExp> buildBlacks() {
    List<String> blacks = [];
    blacks.add(r"*.google.*");
    blacks.add(r"*\.github\.com");
    blacks.add(r"*.apple.*");
    blacks.add(r"*.qq.com");
    // blacks.add(r"www.baidu.com");

    Set<RegExp> blacklist = HashSet<RegExp>();
    for (var black in blacks) {
      blacklist.add(RegExp(black.replaceAll("*", ".*")));
    }

    return blacklist;
  }

  /// 是否过滤
  static bool filter(String host) {
    //如果白名单不为空，不在白名单里都是黑名单
    if (_whitelist.isNotEmpty) {
      return _whitelist.any((element) => !element.hasMatch(host));
    }
    return _blacklist.any((element) => element.hasMatch(host));
  }
}
