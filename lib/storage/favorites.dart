import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/http/http.dart';
import 'package:path_provider/path_provider.dart';

class FavoriteStorage {
  static Queue<HttpRequest>? _requests;

  /// 获取收藏列表
  static Future<Queue<HttpRequest>> get favorites async {
    if (_requests == null) {
      var file = await _path;
      print(file);
      _requests = ListQueue();
      if (await file.exists()) {
        var value = await file.readAsString();

        try {
          var list = jsonDecode(value) as List<dynamic>;
          for (var element in list) {
            _requests!.add(_Item.fromJson(element).request);
          }
        } catch (e) {
          print(e);
        }
      }
    }
    return _requests!;
  }

  static Future<File> get _path async {
    final directory = await getApplicationSupportDirectory();
    var file = File('${directory.path}${Platform.pathSeparator}favorites.json');
    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  /// 添加收藏
  static Future<void> addFavorite(HttpRequest request) async {
    var favorites = await FavoriteStorage.favorites;
    if (favorites.contains(request)) {
      return;
    }

    favorites.addFirst(request);
    _path.then((file) async {
      file.writeAsString(jsonEncode(toJson(favorites)));
    });
  }

  static Future<void> removeFavorite(HttpRequest request) async {
    var list = await favorites;
    list.remove(request);

    _path.then((file) => file.writeAsString(jsonEncode(toJson(list))));
  }

  static List toJson(Queue list) {
    return list.map((e) => _Item(e).toJson()).toList();
  }
}

class _Item {
  final HttpRequest request;
  HttpResponse? response;

  _Item(this.request, [this.response]) {
    response ??= request.response;
    request.response = response;
    response?.request = request;
  }

  factory _Item.fromJson(Map<String, dynamic> json) {
    return _Item(HttpRequest.fromJson(json['request']),
        json['response'] == null ? null : HttpResponse.fromJson(json['response']));
  }

  toJson() {
    return {
      'request': request.toJson(),
      'response': response?.toJson(),
    };
  }
}
