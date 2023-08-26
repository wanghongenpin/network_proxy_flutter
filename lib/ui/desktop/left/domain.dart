import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/attribute_keys.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/component/transition.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/ui/desktop/left/path.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/search.dart';

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

class DomainWidgetState extends State<DomainWidget> with AutomaticKeepAliveClientMixin{
  LinkedHashMap<HostAndPort, HeaderBody> containerMap = LinkedHashMap<HostAndPort, HeaderBody>();
  LinkedHashMap<HostAndPort, HeaderBody> searchView = LinkedHashMap<HostAndPort, HeaderBody>();

  //搜索的内容
  SearchModel? searchModel;
  bool changing = false; //是否存在刷新任务

  changeState() {
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        setState(() {
          changing = false;
        });
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var list = containerMap.values;

    //根究搜素文本过滤
    if (searchModel?.isNotEmpty == true) {
      searchView = searchFilter(searchModel!);
      list = searchView.values;
    } else {
      searchView.clear();
    }

    return Scaffold(
        body: SingleChildScrollView(child: Column(children: list.toList())),
        bottomNavigationBar: Search(onSearch: (val) {
          setState(() {
            searchModel = val;
          });
        }));
  }

  ///搜索过滤
  LinkedHashMap<HostAndPort, HeaderBody> searchFilter(SearchModel searchModel) {
    LinkedHashMap<HostAndPort, HeaderBody> result = LinkedHashMap<HostAndPort, HeaderBody>();

    containerMap.forEach((key, headerBody) {
      var body = headerBody.search(searchModel);
      if (body.isNotEmpty) {
        result[key] = headerBody.copy(body: body, selected: searchView[key]?.currentSelected);
      }
    });

    return result;
  }

  ///添加请求
  add(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    //按照域名分类
    HeaderBody? headerBody = containerMap[hostAndPort];
    if (headerBody != null) {
      var listURI = PathRow(request, widget.panel, proxyServer: widget.proxyServer, remove: (it) => headerBody!.remove(it));
      headerBody.addBody(channel.id, listURI);

      //搜索视图
      if (searchModel?.isNotEmpty == true && searchModel?.filter(request, null) == true) {
        searchView[hostAndPort]?.addBody(channel.id, listURI);
      }
      return;
    }

    headerBody = HeaderBody(hostAndPort, proxyServer: widget.proxyServer, onRemove: () => remove(hostAndPort));
    var listURI = PathRow(request, widget.panel, proxyServer: widget.proxyServer, remove: (it) => headerBody!.remove(it));
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
    var pathRow = headerBody?.getBody(channel.id);
    pathRow?.add(response);
    if (pathRow == null) {
      return;
    }

    //搜索视图
    if (searchModel?.isNotEmpty == true && searchModel?.filter(pathRow.request, response) == true) {
      var header = searchView[hostAndPort];
      if (header?.getBody(channel.id) == null) {
        header?.addBody(channel.id, pathRow);
      }
      headerBody?.getBody(channel.id)?.add(response);
    }
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
  final stateKey = GlobalKey<_HeaderBodyState>();

  //请求ID和请求的映射
  final Map<String, PathRow> channelIdPathMap = HashMap<String, PathRow>();

  final HostAndPort header;
  final ProxyServer proxyServer;

  //请求列表
  final Queue<PathRow> _body = Queue();

  //是否选中
  final bool selected;

  //移除回调
  final Function()? onRemove;

  HeaderBody(this.header, {this.selected = false, this.onRemove, required this.proxyServer})
      : super(key: GlobalKey<_HeaderBodyState>());

  ///添加请求
  void addBody(String key, PathRow widget) {
    _body.addFirst(widget);
    channelIdPathMap[key] = widget;
    changeState();
  }

  PathRow? getBody(String key) {
    return channelIdPathMap[key];
  }

  remove(PathRow pathRow) {
    if (_body.remove(pathRow)) {
      changeState();
    }
  }

  ///根据文本过滤
  Iterable<PathRow> search(SearchModel searchModel) {
    return _body.where((element) => searchModel.filter(element.request, element.response.get()));
  }

  ///复制
  HeaderBody copy({Iterable<PathRow>? body, bool? selected}) {
    var state = key as GlobalKey<_HeaderBodyState>;
    var headerBody = HeaderBody(header,
        selected: selected ?? state.currentState?.selected == true, onRemove: onRemove, proxyServer: proxyServer);
    if (body != null) {
      headerBody._body.addAll(body);
    }
    return headerBody;
  }

  bool get currentSelected {
    var state = key as GlobalKey<_HeaderBodyState>;
    return state.currentState?.selected == true;
  }

  changeState() {
    var state = key as GlobalKey<_HeaderBodyState>;
    state.currentState?.changeState();
  }

  @override
  State<StatefulWidget> createState() {
    return _HeaderBodyState();
  }
}

class _HeaderBodyState extends State<HeaderBody> {
  final GlobalKey<ColorTransitionState> transitionState = GlobalKey<ColorTransitionState>();
  late Configuration configuration;
  late bool selected;

  @override
  void initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;
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
    var host = GestureDetector(
        onSecondaryLongPressDown: menu,
        child: ListTile(
            minLeadingWidth: 25,
            leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 18),
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
            }));

    return ColorTransition(
        key: transitionState,
        duration: const Duration(milliseconds: 1800),
        begin: Theme.of(context).focusColor,
        startAnimation: false,
        child: host);
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
              configuration.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("添加白名单", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.add(widget.header.host);
              configuration.flushConfig();
            }),
        PopupMenuItem(
            height: 38,
            child: const Text("删除白名单", style: TextStyle(fontSize: 14)),
            onTap: () {
              HostFilter.whitelist.remove(widget.header.host);
              configuration.flushConfig();
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
