import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/component/transition.dart';
import 'package:network_proxy/ui/desktop/left/path.dart';
import 'package:network_proxy/ui/content/panel.dart';

///左侧域名
class DomainWidget extends StatefulWidget {
  final NetworkTabController panel;
  final ProxyServer proxyServer;

  const DomainWidget({super.key, required this.panel, required this.proxyServer});

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
    //按照域名分类
    HeaderBody? headerBody = containerMap[hostAndPort];
    var listURI = PathRow(request, widget.panel, proxyServer: widget.proxyServer);
    if (headerBody != null) {
      headerBody.addBody(channel.id, listURI);
      return;
    }

    headerBody = HeaderBody(hostAndPort, proxyServer: widget.proxyServer, onRemove: () => remove(hostAndPort));
    headerBody.addBody(channel.id, listURI);
    setState(() {
      containerMap[hostAndPort] = headerBody!;
    });
  }

  remove(HostAndPort hostAndPort) {
    setState(() {
      containerMap.remove(hostAndPort);
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
  final Map<String, PathRow> channelIdPathMap = HashMap<String, PathRow>();

  final HostAndPort header;
  final ProxyServer proxyServer;
  final Queue<PathRow> _body = Queue();
  final bool selected;
  final Function()? onRemove;

  HeaderBody(this.header, {this.selected = false, this.onRemove, required this.proxyServer})
      : super(key: GlobalKey<_HeaderBodyState>());

  ///添加请求
  void addBody(String key, PathRow widget) {
    _body.addFirst(widget);
    channelIdPathMap[key] = widget;
    var state = super.key as GlobalKey<_HeaderBodyState>;
    state.currentState?.changeState();
  }

  PathRow? getBody(String key) {
    return channelIdPathMap[key];
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
      _hostWidget(widget.header.domain),
      Offstage(offstage: !selected, child: Column(children: widget._body.toList()))
    ]);
  }

  Widget _hostWidget(String title) {
    return ColorTransition(
        key: transitionState,
        duration: const Duration(milliseconds: 1800),
        begin: Theme.of(context).focusColor,
        child: GestureDetector(
            onSecondaryLongPressDown: menu,
            child: ListTile(
                minLeadingWidth: 25,
                leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 16),
                dense: true,
                horizontalTitleGap: 0,
                visualDensity: const VisualDensity(vertical: -3.6),
                title: Text(title,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () {
                  setState(() {
                    selected = !selected;
                  });
                })));
  }

  //域名右键菜单
  menu(LongPressDownDetails details) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: <PopupMenuEntry>[
        PopupMenuItem(
            height: 38,
            child: const Text("添加黑名单", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.blacklist.add(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("添加白名单", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.add(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("删除白名单", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.remove(widget.header.host);
              widget.proxyServer.flushConfig();
            }),
        PopupMenuItem(height: 38, child: const Text("删除", style: TextStyle(fontSize: 14)), onTap: () => _delete()),
      ],
    );
  }

  _delete() {
    widget.channelIdPathMap.clear();
    widget._body.clear();
    widget.onRemove?.call();
  }
}
