import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/http_headers.dart';
import 'package:network_proxy/utils/lang.dart';

///复制cURL请求
String curlRequest(HttpRequest request) {
  List<String> headers = [];
  request.headers.forEach((key, values) {
    for (var val in values) {
      headers.add("  -H '$key: $val' ");
    }
  });

  String body = '';
  if (request.bodyAsString.isNotEmpty) {
    body = "  --data '${request.bodyAsString}' \\\n";
  }
  return "curl -X ${request.method.name} '${request.requestUrl}' \\\n"
      "${headers.join('\\\n')} \\\n $body  --compressed";
}

const String _h = "-H";
const String _header = "--header";
const String _x = "-X";
const String _request = "--request";
const String _data = "--data";
const String _dataRaw = "--data-raw";

///解析curl
HttpRequest parseCurl(String curl) {
  var lines = curl.trim().split('\n');

  HttpMethod method = HttpMethod.get;
  HttpHeaders headers = HttpHeaders();
  String requestUrl = '';
  String body = '';
  for (var it in lines) {
    it = it.trim();
    if (it.endsWith("\\")) {
      it = it.substring(0, it.length - 1);
    }

    //header
    if (it.startsWith(_h) || it.startsWith(_header)) {
      int index = it.startsWith(_h) ? _h.length : _header.length;
      var line = it.substring(index).trim();
      line = Strings.trimWrap(line, "'");
      var pair = _split(line, ":");
      if (pair != null) {
        headers.add(pair.key, pair.value);
      }
    } else if (it.startsWith(_data)) {
      //body
      String value;
      if (it.startsWith(_dataRaw)) {
        value = it.substring(_dataRaw.length).trim();
      } else {
        value = it.substring(_data.length).trim();
      }
      value = value.startsWith('\$') ? value.substring(1) : value;
      body = Strings.trimWrap(value, "'");
    } else if (it.startsWith(_x) || it.startsWith(_request)) {
      //method
      int index = it.startsWith(_x) ? _x.length : _request.length;
      var value = it.substring(index).trim();
      method = HttpMethod.valueOf(Strings.trimWrap(value, "'"));
    } else if (it.trim().startsWith("'http") || it.startsWith('curl') && it.contains("'http")) {
      var index = it.indexOf("'");
      var value = it.substring(index + 1).trim();
      if (value.endsWith("'")) {
        value = value.substring(0, value.length - 1);
      }
      requestUrl = value;
    }
  }

  if (body.isNotEmpty && method == HttpMethod.get) {
    method = HttpMethod.post;
  }
  HttpRequest request = HttpRequest(method, requestUrl);
  request.headers.addAll(headers);
  request.body = body.codeUnits;

  return request;
}

Pair<String, String>? _split(String line, String code) {
  try {
    var index = line.codeUnits.indexOf(code.codeUnits.first);
    var key = line.substring(0, index).trim();
    var value = line.substring(index + 1).trim();
    return Pair(key, value);
  } catch (e) {
    return null;
  }
}
