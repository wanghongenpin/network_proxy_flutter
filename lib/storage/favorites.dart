import 'dart:collection';
import 'dart:convert';

import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/storage/path.dart';

class FavoriteStorage {
  static Queue<Favorite>? list;

  /// 获取收藏列表
  static Future<Queue<Favorite>> get favorites async {
    if (list == null) {
      list = ListQueue();
      var file = await Paths.getPath("favorites.json");
      if (await file.exists()) {
        var value = await file.readAsString();
        if (value.isEmpty) {
          return list!;
        }
        try {
          var config = jsonDecode(value) as List<dynamic>;
          for (var element in config) {
            list?.add(Favorite.fromJson(element));
          }
        } catch (e, t) {
          logger.e('收藏列表解析失败', error: e, stackTrace: t);
        }
      }
    }
    return list!;
  }

  /// 添加收藏
  static Future<void> addFavorite(HttpRequest request) async {
    var favorites = await FavoriteStorage.favorites;
    if (favorites.any((element) => element.request == request)) {
      return;
    }

    favorites.addFirst(Favorite(request));
    flushConfig();
  }

  static Future<void> removeFavorite(Favorite favorite) async {
    var list = await favorites;
    list.remove(favorite);
    flushConfig();
  }

  //刷新配置
  static void flushConfig() async {
    var list = await favorites;
    Paths.getPath("favorites.json").then((file) => file.writeAsString(toJson(list)));
  }

  static String toJson(Queue<Favorite> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }
}

class Favorite {
  String? name;
  final HttpRequest request;
  HttpResponse? response;

  Favorite(this.request, {this.name, this.response}) {
    response ??= request.response;
    request.response = response;
    response?.request = request;
  }

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(HttpRequest.fromJson(json['request']),
        name: json['name'], response: json['response'] == null ? null : HttpResponse.fromJson(json['response']));
  }

  toJson() {
    return {
      'name': name,
      'request': request.toJson(),
      'response': response?.toJson(),
    };
  }
}
