import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:path_provider/path_provider.dart';

/// @author wanghongen
/// 2023/10/06
/// js脚本
class ScriptManager {
  static String template = """
// 在请求到达服务器之前,调用此函数,您可以在此处修改请求数据
// 例如Add/Update/Remove：Queries、Headers、Body
async function onRequest(context, request) {
  console.log(request.url);
  //URL参数
  //request.queries["name"] = "value";
  // 更新或添加新标头
  //request.headers["X-New-Headers"] = "My-Value";
  
  // Update Body 使用fetch API请求接口，具体文档可网上搜索fetch API
  //request.body = await fetch('https://www.baidu.com/').then(response => response.text());
  return request;
}

// 在将响应数据发送到客户端之前,调用此函数,您可以在此处修改响应数据
async function onResponse(context, request, response) {
  // 更新或添加新标头
  // response.headers["Name"] = "Value";
  // response.statusCode = 200;

  //var body = JSON.parse(response.body);
  //body['key'] = "value";
  //response.body = JSON.stringify(body);
  return response;
}
  """;

  static String separator = Platform.pathSeparator;
  static ScriptManager? _instance;
  bool enabled = true;
  List<ScriptItem> list = [];

  final Map<ScriptItem, String> _scriptMap = {};

  static JavascriptRuntime flutterJs = getJavascriptRuntime();

  ScriptManager._();

  ///单例
  static Future<ScriptManager> get instance async {
    if (_instance == null) {
      _instance = ScriptManager._();
      await _instance?.reloadScript();
      print('init script manager');
    }
    return _instance!;
  }

  ///重新加载脚本
  Future<void> reloadScript() async {
    List<ScriptItem> scripts = [];
    var file = await _path;
    print("reloadScript ${file.path}");
    if (await file.exists()) {
      var content = await file.readAsString();
      if (content.isEmpty) {
        return;
      }
      var config = jsonDecode(content);
      enabled = config['enabled'] == true;
      for (var entry in config['list']) {
        scripts.add(ScriptItem.fromJson(entry));
      }
    }
    list = scripts;
    _scriptMap.clear();
  }

  static String? _homePath;

  static Future<String> homePath() async {
    if (_homePath != null) {
      return _homePath!;
    }

    if (Platform.isMacOS) {
      _homePath = await DesktopMultiWindow.invokeMethod(0, "getApplicationSupportDirectory");
    } else {
      _homePath = await getApplicationSupportDirectory().then((it) => it.path);
    }
    return _homePath!;
  }

  static Future<File> get _path async {
    final path = await homePath();
    var file = File('$path${separator}script.json');
    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  Future<String> getScript(ScriptItem item) async {
    if (_scriptMap.containsKey(item)) {
      return _scriptMap[item]!;
    }
    var script = await File(item.scriptPath!).readAsString();
    _scriptMap[item] = script;
    return script;
  }

  ///添加脚本
  Future<void> addScript(ScriptItem item, String script) async {
    final path = await homePath();
    var file = File('$path${separator}scripts$separator${DateTime.now().millisecondsSinceEpoch}.js');
    await file.create(recursive: true);
    file.writeAsString(script);
    item.scriptPath = file.path;
    list.add(item);
    _scriptMap[item] = script;
  }

  ///更新脚本
  Future<void> updateScript(ScriptItem item, String script) async {
    if (_scriptMap[item] == script) {
      return;
    }

    File(item.scriptPath!).writeAsString(script);
    _scriptMap[item] = script;
  }

  ///删除脚本
  Future<void> removeScript(int index) async {
    var item = list.removeAt(index);
    File(item.scriptPath!).delete();
  }

  ///刷新配置
  Future<void> flushConfig() async {
    _path.then((value) => value.writeAsString(jsonEncode({'enabled': enabled, 'list': list})));
  }

  ///脚本上下文
  Map<String, dynamic> scriptContext(ScriptItem item) {
    return {
      'scriptName': item.name,
      'os': Platform.operatingSystem,
    };
  }

  ///运行脚本
  Future<HttpRequest> runScript(HttpRequest request) async {
    if (!enabled) {
      return request;
    }
    var url = request.requestUrl;
    for (var item in list) {
      if (item.enabled && item.match(url)) {
        var context = jsonEncode(scriptContext(item));
        var jsRequest = jsonEncode(convertJsRequest(request));
        String script = await getScript(item);
        var jsResult = await flutterJs.evaluateAsync(
            """var request = $jsRequest, context = $context;  request['context'] = context; $script\n  onRequest(context, request)""");
        var result = await jsResultResolve(jsResult);

        request.attributes['scriptContext'] = result['context'];
        return convertHttpRequest(request, result);
      }
    }
    return request;
  }

  ///运行脚本
  Future<HttpResponse> runResponseScript(HttpResponse response) async {
    if (!enabled || response.request == null) {
      return response;
    }

    var request = response.request!;
    var url = request.requestUrl;
    for (var item in list) {
      if (item.enabled && item.match(url)) {
        var context = jsonEncode(request.attributes['scriptContext'] ?? scriptContext(item));
        var jsRequest = jsonEncode(convertJsRequest(request));
        var jsResponse = jsonEncode(convertJsResponse(response));
        String script = await getScript(item);
        var jsResult = await flutterJs.evaluateAsync("""$script\n  onResponse($context, $jsRequest,$jsResponse);""");
        // print("response: ${jsResult.isPromise} ${jsResult.isError} ${jsResult.rawResult}");
        var result = await jsResultResolve(jsResult);
        return convertHttpResponse(response, result);
      }
    }
    return response;
  }

  /// js结果转换
  static Future<dynamic> jsResultResolve(JsEvalResult jsResult) async {
    if (jsResult.isPromise) {
      jsResult = await flutterJs.handlePromise(jsResult);
    }
    var result = jsResult.rawResult;
    if (Platform.isMacOS || Platform.isIOS) {
      result = flutterJs.convertValue(jsResult);
    }
    if (result is Future) {
      flutterJs.executePendingJob();
      result = await (jsResult.rawResult as Future);
    }
    if (result is String) {
      result = jsonDecode(result);
    }
    if (jsResult.isError) {
      throw SignalException(jsResult.stringResult);
    }
    return result;
  }

  //转换js request
  Map<String, dynamic> convertJsRequest(HttpRequest request) {
    var requestUri = request.requestUri;
    return {
      'host': requestUri?.host,
      'url': request.requestUrl,
      'path': requestUri?.path,
      'queries': requestUri?.queryParameters,
      'headers': request.headers.toMap(),
      'method': request.method.name,
      'body': request.bodyAsString
    };
  }

  //转换js response
  Map<String, dynamic> convertJsResponse(HttpResponse response) {
    return {'headers': response.headers.toMap(), 'statusCode': response.status.code, 'body': response.bodyAsString};
  }

  //http request
  HttpRequest convertHttpRequest(HttpRequest request, Map<dynamic, dynamic> map) {
    request.headers.clean();
    request.method = HttpMethod.values.firstWhere((element) => element.name == map['method']);
    String query = '';
    map['queries']?.forEach((key, value) {
      query += '$key=$value&';
    });

    request.uri = Uri.parse('${request.remoteDomain()}${map['path']}?$query').toString();

    map['headers'].forEach((key, value) {
      request.headers.add(key, value);
    });
    request.body = map['body']?.toString().codeUnits;
    return request;
  }

  //http response
  HttpResponse convertHttpResponse(HttpResponse response, Map<dynamic, dynamic> map) {
    response.headers.clean();
    response.status = HttpStatus.valueOf(map['statusCode']);
    map['headers'].forEach((key, value) {
      response.headers.add(key, value);
    });
    response.body = map['body']?.toString().codeUnits;
    return response;
  }

}

class ScriptItem {
  bool enabled = true;
  String? name;
  String url;
  String? scriptPath;
  RegExp? urlReg;

  ScriptItem(this.enabled, this.name, this.url, {this.scriptPath});

  //匹配url
  bool match(String url) {
    if (!this.url.startsWith('http://') && !this.url.startsWith('https://')) {
      //不是http开头的url 需要去掉协议
      url = url.substring(url.indexOf('://') + 3);
    }
    urlReg ??= RegExp(this.url.replaceAll("*", ".*"));
    return urlReg!.hasMatch(url);
  }

  factory ScriptItem.fromJson(Map<String, dynamic> json) {
    return ScriptItem(json['enabled'], json['name'], json['url'], scriptPath: json['scriptPath']);
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'name': name, 'url': url, 'scriptPath': scriptPath};
  }

  @override
  String toString() {
    return 'ScriptItem{enabled: $enabled, name: $name, url: $url, scriptPath: $scriptPath}';
  }
}
