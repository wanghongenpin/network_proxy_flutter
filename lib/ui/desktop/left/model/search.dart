import 'package:network_proxy/network/http/http.dart';

class SearchModel {
  String? keyword;
  ContentType? contentType;

  SearchModel(this.keyword, this.contentType);

  bool get isNotEmpty {
    return keyword?.trim().isNotEmpty == true || contentType != null;
  }

  @override
  String toString() {
    return 'SearchModel{keyword: $keyword, contentType: $contentType}';
  }
}
