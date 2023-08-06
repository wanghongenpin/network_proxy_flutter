import 'package:network_proxy/network/http/http.dart';

/// @author wanghongen
/// 2023/8/4
class SearchModel {
  String? keyword;

  //搜索范围
  Set<Option> searchOptions = {Option.url};

  //请求方法
  HttpMethod? requestMethod;
  ContentType? requestContentType;
  ContentType? responseContentType;

  //状态码
  int? statusCode;

  SearchModel([this.keyword]);

  bool get isNotEmpty {
    return keyword?.trim().isNotEmpty == true || requestMethod != null ||
        requestContentType != null || responseContentType != null || statusCode != null;
  }

  of(SearchModel searchModel) {
    keyword = searchModel.keyword;
    searchOptions = searchModel.searchOptions;
    requestContentType = searchModel.requestContentType;
    requestMethod = searchModel.requestMethod;
    requestContentType = searchModel.requestContentType;
    statusCode = searchModel.statusCode;
  }

  ///清空对象
  clear() {
    keyword = null;
    requestContentType = null;
    searchOptions.clear();
    requestMethod = null;
    requestContentType = null;
    statusCode = null;
  }

  ///复制对象
  SearchModel clone() {
    var searchModel = SearchModel(keyword);
    searchModel.searchOptions = searchOptions;
    searchModel.requestMethod = requestMethod;
    searchModel.requestContentType = requestContentType;
    searchModel.responseContentType = responseContentType;
    searchModel.statusCode = statusCode;
    return searchModel;
  }

  @override
  String toString() {
    return 'SearchModel{keyword: $keyword, searchOptions: $searchOptions, responseContentType: $responseContentType, requestMethod: $requestMethod, requestContentType: $requestContentType, statusCode: $statusCode}';
  }
}

enum Option {
  url,
  method,
  responseContentType,
  requestHeader,
  requestBody,
  responseHeader,
  responseBody,
}
