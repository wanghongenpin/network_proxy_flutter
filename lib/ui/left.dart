import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:network/network/http/http.dart';
import 'package:network/ui/panel.dart';

import '../utils/lang.dart';

///标题和内容布局 标题是域名 内容是域名下请求
class HeaderBody extends StatefulWidget {
  final Map<String, RowURI> map = HashMap<String, RowURI>();

  final String header;
  final Queue<RowURI> _body = Queue();
  final bool selected;

  HeaderBody(this.header, {this.selected = false}) : super(key: GlobalKey<_HeaderBodyState>());

  ///添加请求
  void addBody(String key, RowURI widget) {
    _body.addFirst(widget);
    map[key] = widget;
    var state = super.key as GlobalKey<_HeaderBodyState>;
    state.currentState?.changeState();
  }

  RowURI? getBody(String key) {
    return map[key];
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

  changeState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _hostWidget(widget.header),
      Offstage(offstage: !selected, child: Column(children: widget._body.toList()))
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

Widget show(Widget child) {
  return AnimatedOpacity(opacity: 1.0, duration: const Duration(seconds: 3), child: child);
}

class RowURI extends StatefulWidget {
  final Color? color;
  final HttpRequest request;
  final ValueWrap<HttpResponse> response = ValueWrap();

  final NetworkTabController panel;

  RowURI(this.request, this.panel, {Key? key, this.color = Colors.green}) : super(key: GlobalKey<_RowURIState>());

  @override
  State<RowURI> createState() => _RowURIState();

  void add(HttpResponse response) {
    this.response.set(response);
    var state = key as GlobalKey<_RowURIState>;
    state.currentState?.changeState();
  }
}

class _RowURIState extends State<RowURI> {
  static _RowURIState? selectedState;

  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var response = widget.response.get();
    var title = '${request.method.name} ${Uri.parse(request.uri).path}';
    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    return ListTile(
        leading: Icon(getIcon(), size: 16, color: widget.color),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
        subtitle: Text(
            '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name ?? ''} ${response?.costTime() ?? ''} '),
        selected: selected,
        // trailing: const Icon(Icons.chevron_right),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
        onTap: onClick);
  }

  void changeState() {
    setState(() {});
  }

  void onClick() {
    if (selected) {
      return;
    }
    setState(() {
      selected = true;
    });
    if (selectedState?.mounted == true && selectedState != this) {
      selectedState?.setState(() {
        selectedState?.selected = false;
      });
    }
    selectedState = this;
    widget.panel.change(widget.request, widget.response.get());
  }

  IconData getIcon() {
    var map = {
      ContentType.json: Icons.data_object,
      ContentType.html: Icons.html,
      ContentType.js: Icons.javascript,
      ContentType.image: Icons.image,
      ContentType.text: Icons.text_fields,
      ContentType.css: Icons.css
    };
    if (widget.response.isNull()) {
      return Icons.http;
    }
    var contentType = widget.response.get()?.contentType;
    return map[contentType] ?? Icons.http;
  }
}
