import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'logger.dart';

void main() {
  print(HostFilter.filter("www.apple.com"));
}

class HostFilter {
  /// 白名单
  static final Whites whites = Whites();

  /// 黑名单
  static final Blacks blacklist = Blacks();

  /// 是否过滤
  static bool filter(String? host) {
    if (host == null) {
      return false;
    }

    //如果白名单不为空，不在白名单里都是黑名单
    if (whites.enabled) {
      return whites.list.any((element) => !element.hasMatch(host));
    }
    if (blacklist.enabled) {
      return blacklist.list.any((element) => element.hasMatch(host));
    }
    return false;
  }
}

abstract class HostList {
  Future<String> get _homePath async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<File> get _configFile;

  /// 白名单
  final List<RegExp> list = [];
  bool enabled = false;

  List<Function> initListens = [];
  bool _inited = false;

  Future<void> _initList() async {
    if (_inited) {
      return;
    }
    final file = await _configFile;
    log.i('域名过滤初始化文件 $file');

    await file.exists().then((exist) async {
      if (exist) {
        Map<String, dynamic> map = json.decode(await file.readAsString());
        List? list = map['list'];
        list?.forEach((element) {
          this.list.add(RegExp(element));
        });
        enabled = map['enabled'] == true;
      }
    });
    _inited = true;
    for (var fun in initListens) {
      fun();
    }
  }

  void add(String reg) {
    list.add(RegExp(reg.replaceAll("*", ".*")));
  }

  void remove(String reg) {
    list.removeWhere((element) => element.pattern == reg.replaceAll("*", ".*"));
  }

  void removeIndex(List<int> index) {
    for (var element in index) {
      list.removeAt(element);
    }
  }

  void flush() async {
    final file = await _configFile;
    log.i('域名过滤刷新文件 $runtimeType ${toJson()}');
    var json = jsonEncode(toJson());
    file.writeAsString(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'list': list.map((e) => e.pattern).toList(),
      'enabled': enabled,
    };
  }
}

class Whites extends HostList {
  @override
  Future<File> get _configFile async {
    final path = await _homePath;
    File file = File('$path/host_whites.txt');
    return file;
  }

  Whites() {
    _initList();
  }
}

class Blacks extends HostList {
  @override
  Future<File> get _configFile async {
    final path = await _homePath;
    return File('$path/host_blacks.txt');
  }

  Blacks() {
    _initList();
  }
}
