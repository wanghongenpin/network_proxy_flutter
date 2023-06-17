import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network/network/http/http.dart';
import 'package:network/ui/left/path.dart';

import '../../network/channel.dart';
import '../../network/util/attribute_keys.dart';
import '../panel.dart';

///左侧域名
class DomainWidget extends StatefulWidget {
  final NetworkTabController panel;

  DomainWidget({required this.panel}) : super(key: GlobalKey<_DomainWidgetState>());

  void add(Channel channel, HttpRequest request) {
    var state = key as GlobalKey<_DomainWidgetState>;
    state.currentState?.add(channel, request);
  }

  void addResponse(Channel channel, HttpResponse response) {
    var state = key as GlobalKey<_DomainWidgetState>;
    state.currentState?.addResponse(channel, response);
  }

  void clean() {
    var state = key as GlobalKey<_DomainWidgetState>;
    state.currentState?.clean();
    panel.request.set(null);
    panel.response.set(null);
  }

  @override
  State<StatefulWidget> createState() {
    return _DomainWidgetState();
  }
}

class _DomainWidgetState extends State<DomainWidget> {
  LinkedHashMap<HostAndPort, HeaderBody> containerMap = LinkedHashMap<HostAndPort, HeaderBody>();

  @override
  Widget build(BuildContext context) {
    var list = containerMap.values;
    return ListView.builder(
        itemBuilder: (BuildContext context, int index) => list.elementAt(index), itemCount: list.length);
  }

  ///添加请求
  void add(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    HeaderBody? headerBody = containerMap[hostAndPort];
    var listURI = PathRow(request, widget.panel);
    if (headerBody != null) {
      headerBody.addBody(channel.id, listURI);
      return;
    }

    headerBody = HeaderBody(hostAndPort.url);
    headerBody.addBody(channel.id, listURI);
    setState(() {
      containerMap[hostAndPort] = headerBody!;
    });
  }

  ///添加响应
  void addResponse(Channel channel, HttpResponse response) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    HeaderBody? headerBody = containerMap[hostAndPort];
    headerBody?.getBody(channel.id)?.add(response);
  }

  ///清理
  void clean() {
    setState(() {
      containerMap.clear();
    });
  }
}

///标题和内容布局 标题是域名 内容是域名下请求
class HeaderBody extends StatefulWidget {
  final Map<String, PathRow> map = HashMap<String, PathRow>();

  final String header;
  final Queue<PathRow> _body = Queue();
  final bool selected;

  HeaderBody(this.header, {this.selected = false}) : super(key: GlobalKey<_HeaderBodyState>());

  ///添加请求
  void addBody(String key, PathRow widget) {
    _body.addFirst(widget);
    map[key] = widget;
    var state = super.key as GlobalKey<_HeaderBodyState>;
    state.currentState?.changeState();
  }

  PathRow? getBody(String key) {
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
