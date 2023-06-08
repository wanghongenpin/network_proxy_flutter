import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network/network/http/http.dart';
import 'package:network/ui/panel.dart';

///标题和内容布局 标题是域名 内容是域名下请求
class HeaderBody extends StatefulWidget {
  final Map<String, RowURI> map = HashMap<String, RowURI>();

  final String header;
  final Queue<RowURI> _body = Queue<RowURI>();
  final bool selected;

  HeaderBody(this.header, {Key? key, this.selected = false}) : super(key: key);

  ///添加请求
  void addBody(String key, RowURI widget) {
    _body.addFirst(widget);
    map[key] = widget;
  }

  RowURI? getBody(String key) {
    return map[key];
  }

  //复制
  HeaderBody copy() {
    var headerBody = HeaderBody(header, selected: selected);
    headerBody._body.addAll(_body);
    headerBody.map.addAll(map);
    return this;
  }

  @override
  State<StatefulWidget> createState() {
    return _HeaderBodyState();
  }
}

class _HeaderBodyState extends State<HeaderBody> {
  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _hostWidget(widget.header),
      Visibility(visible: selected, child: Column(children: widget._body.toList()))
    ]);
  }

  Widget _hostWidget(String title) {
    return ListTile(
        leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 16),
        dense: true,
        selected: selected,
        horizontalTitleGap: 0,
        visualDensity: const VisualDensity(vertical: -3.6),
        title: Text(title, textAlign: TextAlign.left),
        onTap: () {
          setState(() {
            selected = !selected;
          });
        });
  }
}

class RowURI extends StatefulWidget {
  final Color? color;
  final HttpRequest request;
  HttpResponse? response;
  final NetworkTabController panel;

  final _RowURIState _state = _RowURIState();

  RowURI(this.request, this.panel, {Key? key, this.color = Colors.green}) : super(key: key);

  @override
  State<RowURI> createState() => _state;

  void add(HttpResponse response) {
    this.response = response;
  }
}

class _RowURIState extends State<RowURI> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var leading = widget.response == null ? Icons.http : Icons.http;
    var title = '${request.method.name} ${Uri.parse(request.uri).path}';

    return ListTile(
        leading: Icon(leading, size: 15, color: widget.color),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
        trailing: const Icon(Icons.chevron_right),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
        onTap: () {
          selected = !selected;
          widget.panel.change(widget.request, widget.response);
        });
  }
}
