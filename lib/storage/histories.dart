import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:file_selector/file_selector.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/utils/files.dart';
import 'package:network_proxy/utils/har.dart';
import 'package:path_provider/path_provider.dart';

///历史存储
class HistoryStorage {
  static HistoryStorage? _instance;

  HistoryStorage._internal();

  static final List<HistoryItem> _histories = [];

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
      try {
        var list = jsonDecode(content) as List<dynamic>;
        for (var entry in list) {
          _histories.add(HistoryItem.formJson(entry));
        }
      } catch (e) {
        print(e);
      }
    }
  }

  static Future<String> _homePath() async {
    final home = await getApplicationSupportDirectory();
    return '${home.path}${Platform.pathSeparator}history';
  }

  /// 获取历史记录
  List<HistoryItem> get histories {
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
    final homePath = await _homePath();
    var file = File('$homePath${Platform.pathSeparator}$name');
    return file.create(recursive: true);
  }

  /// 添加历史记录
  Future<HistoryItem> addHistory(String name, File file, int requestLength) async {
    var size = await file.length();
    var historyItem = HistoryItem(name, file.path, requestLength, size);
    _histories.add(historyItem);
    (await _path).writeAsString(jsonEncode(_histories));
    return historyItem;
  }

  int getIndex(HistoryItem item) {
    return _histories.indexOf(item);
  }

  //更新
  updateHistory(int index, HistoryItem item) async {
    _histories[index] = item;
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //获取
  HistoryItem getHistory(int index) {
    return _histories[index];
  }

  Future<void> refresh() async {
    (await _path).writeAsString(jsonEncode(_histories));
  }

  ///删除
  void removeHistory(int index) async {
    var history = _histories.removeAt(index);
    final homePath = await _homePath();
    var file = File('$homePath${Platform.pathSeparator}${Files.getName(history.path)}');
    file.delete();
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //获取请求列表
  Future<List<HttpRequest>> getRequests(HistoryItem history) async {
    if (history.requests == null) {
      final homePath = await _homePath();
      String path = '$homePath${Platform.pathSeparator}${Files.getName(history.path)}';
      var file = File(path);
      history.requests = await Har.readFile(file);
      history.requestLength = history.requests!.length;
      file.length().then((size) => history.fileSize = size);
    }

    return history.requests!;
  }

  ///刷新requests
  Future<void> flushRequests(HistoryItem history, List<HttpRequest> requests) async {
    logger.i("刷新历史记录 $history");
    final homePath = await _homePath();
    String path = '$homePath${Platform.pathSeparator}${Files.getName(history.path)}';
    var file = File(path);
    for (int i = 0; i < requests.length; i++) {
      var request = requests[i];
      var har = Har.toHar(request);
      await file.writeAsString("${jsonEncode(har)},\n", mode: i == 0 ? FileMode.write : FileMode.append);
    }

    history.requestLength = requests.length;
    await file.length().then((size) => history.fileSize = size);
    (await _path).writeAsString(jsonEncode(_histories));
  }

  //添加历史
  Future<HistoryItem> addHarFile(XFile file) async {
    var readAsBytes = await file.readAsString();
    var json = jsonDecode(readAsBytes);
    var log = json['log'];
    String name = formatDate(DateTime.now(), [mm, '-', d, ' ', HH, ':', nn, ':', ss]);
    List? pages = log['pages'] as List;
    if (pages.isNotEmpty) {
      name = pages.first['title'];
    }

    //解析请求
    List entries = log['entries'];
    var list = entries.map((e) => Har.toRequest(e)).toList();

    //保存文件
    var historyFile = await HistoryStorage.openFile("${DateTime.now().millisecondsSinceEpoch}.txt");
    var open = await historyFile.open(mode: FileMode.append);
    for (var request in list) {
      await open.writeString(jsonEncode(Har.toHar(request)));
      await open.writeString(",\n");
    }
    return addHistory(name, historyFile, list.length);
  }
}

/// 历史记录
class HistoryItem {
  String name;
  final String path; // 文件路径
  int requestLength = 0; // 请求数量
  int? fileSize; // 文件大小
  List<HttpRequest>? requests;

  HistoryItem(this.name, this.path, this.requestLength, this.fileSize);

  //json反序列化
  factory HistoryItem.formJson(Map<String, dynamic> map) {
    return HistoryItem(map['name'], map['path'], map['requestLength'], map['fileSize']);
  }

  //json序列化
  Map<String, dynamic> toJson() {
    return {
      'name': name,
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

  @override
  String toString() {
    return "$path $requestLength $fileSize";
  }
}
