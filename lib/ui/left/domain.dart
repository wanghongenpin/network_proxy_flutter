import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/components.dart';
import 'package:network_proxy/ui/left/path.dart';

import '../../network/channel.dart';
import '../../network/util/attribute_keys.dart';
import '../panel.dart';

///左侧域名
class DomainWidget extends StatefulWidget {
  final NetworkTabController panel;

  const DomainWidget({super.key, required this.panel});

  @override
  State<StatefulWidget> createState() {
    return DomainWidgetState();
  }
}

class DomainWidgetState extends State<DomainWidget> {
  LinkedHashMap<HostAndPort, HeaderBody> containerMap = LinkedHashMap<HostAndPort, HeaderBody>();

  @override
  Widget build(BuildContext context) {
    var list = containerMap.values;
    return SingleChildScrollView(child: Column(children: list.toList()));
  }

  ///添加请求
  add(Channel channel, HttpRequest request) {
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
  addResponse(Channel channel, HttpResponse response) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    HeaderBody? headerBody = containerMap[hostAndPort];
    headerBody?.getBody(channel.id)?.add(response);
  }

  ///清理
  clean() {
    widget.panel.change(null, null);
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
  final GlobalKey<ColorTransitionState> transitionState = GlobalKey<ColorTransitionState>();

  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  changeState() {
    setState(() {});
    transitionState.currentState?.show();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _hostWidget(widget.header),
      Offstage(offstage: !selected, child: Column(children: widget._body.toList()))
    ]);
  }

  Widget _hostWidget(String title) {
    return ColorTransition(
        key: transitionState,
        duration: const Duration(milliseconds: 1500),
        begin: Colors.white30,
        child: ListTile(
            minLeadingWidth: 25,
            leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 16),
            dense: true,
            horizontalTitleGap: 0,
            visualDensity: const VisualDensity(vertical: -3.6),
            title: Text(title, textAlign: TextAlign.left),
            onTap: () {
              setState(() {
                selected = !selected;
              });
            }));
  }
}
