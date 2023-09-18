import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/utils/har.dart';
import 'package:path_provider/path_provider.dart';

///历史存储
class HistoryStorage {
  static HistoryStorage? _instance;

  HistoryStorage._internal();

  static final LinkedHashMap<String, HistoryItem> _histories = LinkedHashMap<String, HistoryItem>();

  static final Map<String, List<HttpRequest>> _requests = {};

  ///单例
  static Future<HistoryStorage> get instance async {
    if (_instance == null) {
      _instance = HistoryStorage._internal();
      await _init();
    }
    return _instance!;
  }

  //初始化
  static Future<void> _init() async {
    var file = await _path;
    if (await file.exists()) {
      var content = await file.readAsString();
      if (content.trim().isEmpty) {
        return;
      }
      final Map<dynamic, dynamic> data = jsonDecode(content);
      for (var entry in data.entries) {
        _histories[entry.key] = HistoryItem.formJson(entry.value);
      }
    }
  }

  /// 获取历史记录
  Map<String, HistoryItem> get histories {
    return _histories;
  }

  //获取配置路径
  static Future<File> get _path async {
    final directory = await getApplicationSupportDirectory();
    var file = File('${directory.path}${Platform.pathSeparator}histories.json');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  ///打开文件
  static Future<File> openFile(String name) async {
    final directory = await getApplicationSupportDirectory();
    var file = File('${directory.path}${Platform.pathSeparator}history${Platform.pathSeparator}$name');
    return file.create(recursive: true);
  }

  /// 添加历史记录
  Future<void> addHistory(String name, File file, int requestLength) async {
    var size = await file.length();
    _histories[name] = HistoryItem(file.path, requestLength, size);
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //更新
  updateHistory(String name, HistoryItem item) async {
    _histories[name] = item;
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //获取
  HistoryItem getHistory(String name) {
    return _histories[name]!;
  }

  ///删除
  void removeHistory(String name) async {
    var history = _histories.remove(name);
    if (history == null) {
      return;
    }
    var file = File(history.path);
    if (await file.exists()) {
      await file.delete();
    }
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //获取请求列表
  Future<List<HttpRequest>> getRequests(String name) async {
    var request = _requests[name];
    if (request == null) {
      HistoryItem history = _histories[name]!;
      var file = File(history.path);
      _requests[name] = await Har.readFile(file);
      histories[name]?.requestLength = _requests[name]!.length;
      file.length().then((size) => histories[name]?.fileSize = size);
    }
    return _requests[name]!;
  }

  void removeCache(String name) {
    _requests.remove(name);
  }
}

/// 历史记录
class HistoryItem {
  final String path; // 文件路径
  int requestLength = 0; // 请求数量
  int? fileSize; // 文件大小

  HistoryItem(this.path, this.requestLength, this.fileSize);

  //json反序列化
  factory HistoryItem.formJson(Map<String, dynamic> map) {
    return HistoryItem(map['path'], map['requestLength'], map['fileSize']);
  }

  //json序列化
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'requestLength': requestLength,
      'fileSize': fileSize,
    };
  }

  //获取文件大小
  String get size {
    if (this.fileSize == null) {
      return "";
    }

    int fileSize = this.fileSize!;
    if (fileSize > 1024 * 1024) {
      return "${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB";
    }

    return "${(fileSize / 1024).toStringAsFixed(1)}KB";
  }
}
