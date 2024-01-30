import 'dart:collection';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/transition.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/ui/desktop/left/request.dart';
import 'package:network_proxy/ui/desktop/left/search.dart';
import 'package:network_proxy/utils/har.dart';
import 'package:network_proxy/utils/listenable_list.dart';

/// 左侧域名
/// @author wanghongen
/// 2023/10/8
class DomainList extends StatefulWidget {
  final ProxyServer proxyServer;
  final NetworkTabController panel;

  final ListenableList<HttpRequest> list;
  final bool shrinkWrap;

  const DomainList({super.key, required this.proxyServer, required this.list, this.shrinkWrap = true, required this.panel});

  @override
  State<StatefulWidget> createState() {
    return DomainWidgetState();
  }
}

class DomainWidgetState extends State<DomainList> with AutomaticKeepAliveClientMixin {
  late ListenableList<HttpRequest> container;

  final LinkedHashMap<String, DomainRequests> containerMap = LinkedHashMap<String, DomainRequests>();

  //搜索视图
  LinkedHashMap<String, DomainRequests> searchView = LinkedHashMap<String, DomainRequests>();

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
  void initState() {
    super.initState();
    container = widget.list;
    for (var request in container.source) {
      var host = request.remoteDomain()!;
      DomainRequests domainRequests = getDomainRequests(host);
      domainRequests.addRequest(request.requestId, request);
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

    Widget body = widget.shrinkWrap
        ? SingleChildScrollView(child: Column(children: list.toList()))
        : ListView.builder(itemCount: list.length, itemBuilder: (_, index) => list.elementAt(index));

    return Scaffold(
        body: body,
        bottomNavigationBar: Search(onSearch: (val) {
          setState(() {
            searchModel = val;
          });
        }));
  }

  ///搜索过滤
  LinkedHashMap<String, DomainRequests> searchFilter(SearchModel searchModel) {
    LinkedHashMap<String, DomainRequests> result = LinkedHashMap<String, DomainRequests>();

    containerMap.forEach((key, domainRequests) {
      var body = domainRequests.search(searchModel);
      if (body.isNotEmpty) {
        result[key] = domainRequests.copy(body: body, selected: searchView[key]?.currentSelected);
      }
    });

    return result;
  }

  ///添加请求
  add(Channel channel, HttpRequest request) {
    container.add(request);
    String? host = request.remoteDomain();
    if (host == null) {
      return;
    }

    //按照域名分类
    DomainRequests domainRequests = getDomainRequests(host);
    var isNew = domainRequests.body.isEmpty;
    domainRequests.addRequest(request.requestId, request);
    //搜索视图
    if (searchModel?.isNotEmpty == true && searchModel?.filter(request, null) == true) {
      searchView[host]?.addRequest(request.requestId, request);
    }

    if (isNew) {
      setState(() {
        containerMap[host] = domainRequests;
      });
    }
  }

  DomainRequests getDomainRequests(String host) {
    DomainRequests? domainRequests = containerMap[host];
    if (domainRequests == null) {
      domainRequests = DomainRequests(host,
          proxyServer: widget.panel.proxyServer, onDelete: deleteHost, onRequestRemove: (req) => container.remove(req));
      containerMap[host] = domainRequests;
    }

    return domainRequests;
  }

  ///移除域名
  deleteHost(String host) {
    setState(() {
      containerMap.remove(host);
      container.removeWhere((element) => element.remoteDomain() == host);
    });
  }

  ///添加响应
  addResponse(ChannelContext channelContext, HttpResponse response) {
    String domain = channelContext.host!.domain;
    DomainRequests? domainRequests = containerMap[domain];
    var pathRow = domainRequests?.getRequest(response);
    pathRow?.setResponse(response);
    if (pathRow == null) {
      return;
    }

    //搜索视图
    if (searchModel?.isNotEmpty == true && searchModel?.filter(pathRow.request, response) == true) {
      var requests = searchView[domain];
      if (requests?.getRequest(response) == null) {
        requests?.addRequest(response.requestId, pathRow.request);
      }
      requests?.getRequest(response)?.setResponse(response);
    }
  }

  ///清理
  clean() {
    widget.panel.change(null, null);
    setState(() {
      container.clear();
      containerMap.clear();
    });
  }

  export(String fileName) async {
    final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);
    if (result == null) {
      return;
    }

    //获取请求
    List<HttpRequest> requests = searchView.values.expand((list) => list.body.map((it) => it.request)).toList();
    var file = await File(result.path).create();
    await Har.writeFile(requests, file, title: fileName);

    if (mounted) FlutterToastr.show(AppLocalizations.of(context)!.exportSuccess, context);
  }
}

///标题和内容布局 标题是域名 内容是域名下请求
class DomainRequests extends StatefulWidget {
  //请求ID和请求的映射
  final Map<String, RequestWidget> requestMap = HashMap<String, RequestWidget>();

  final String domain;
  final ProxyServer proxyServer;

  //请求列表
  final Queue<RequestWidget> body = Queue();

  //是否选中
  final bool selected;

  //移除回调
  final Function(String host)? onDelete;
  final Function(HttpRequest request)? onRequestRemove;

  DomainRequests(this.domain, {this.selected = false, this.onDelete, required this.proxyServer, this.onRequestRemove})
      : super(key: GlobalKey<_DomainRequestsState>());

  ///添加请求
  void addRequest(String? requestId, HttpRequest request) {
    if (requestMap.containsKey(requestId)) return;

    var requestWidget = RequestWidget(request, proxyServer: proxyServer, remove: (it) => _remove(it));
    body.addFirst(requestWidget);
    if (requestId == null) {
      return;
    }
    requestMap[requestId] = requestWidget;
    changeState();
  }

  RequestWidget? getRequest(HttpResponse response) {
    return requestMap[response.request?.requestId ?? response.requestId];
  }

  _remove(RequestWidget requestWidget) {
    if (body.remove(requestWidget)) {
      onRequestRemove?.call(requestWidget.request);
      changeState();
    }
  }

  ///根据文本过滤
  Iterable<RequestWidget> search(SearchModel searchModel) {
    return body
        .where((element) => searchModel.filter(element.request, element.response.get() ?? element.request.response));
  }

  ///复制
  DomainRequests copy({Iterable<RequestWidget>? body, bool? selected}) {
    var state = key as GlobalKey<_DomainRequestsState>;
    var headerBody = DomainRequests(domain,
        selected: selected ?? state.currentState?.selected == true,
        onDelete: onDelete,
        onRequestRemove: onRequestRemove,
        proxyServer: proxyServer);
    if (body != null) {
      headerBody.body.addAll(body);
    }
    return headerBody;
  }

  bool get currentSelected {
    var state = key as GlobalKey<_DomainRequestsState>;
    return state.currentState?.selected == true;
  }

  changeState() {
    var state = key as GlobalKey<_DomainRequestsState>;
    state.currentState?.changeState();
  }

  @override
  State<StatefulWidget> createState() {
    return _DomainRequestsState();
  }
}

class _DomainRequestsState extends State<DomainRequests> {
  final GlobalKey<ColorTransitionState> transitionState = GlobalKey<ColorTransitionState>();
  late Configuration configuration;
  late bool selected;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

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
      _hostWidget(widget.domain),
      Offstage(offstage: !selected, child: Column(children: widget.body.toList()))
    ]);
  }

  Widget _hostWidget(String title) {
    var host = GestureDetector(
        onSecondaryTapDown: menu,
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
  menu(TapDownDetails details) {
    showContextMenu(
      context,
      details.globalPosition,
      items: <PopupMenuEntry>[
        CustomPopupMenuItem(
            height: 35,
            child: Text(localizations.domainBlacklist, style: const TextStyle(fontSize: 13)),
            onTap: () {
              HostFilter.blacklist.add(Uri.parse(widget.domain).host);
              configuration.flushConfig();
              FlutterToastr.show(localizations.addSuccess, context);
            }),
        CustomPopupMenuItem(
            height: 35,
            child: Text(localizations.domainWhitelist, style: const TextStyle(fontSize: 13)),
            onTap: () {
              HostFilter.whitelist.add(Uri.parse(widget.domain).host);
              configuration.flushConfig();
              FlutterToastr.show(localizations.addSuccess, context);
            }),
        CustomPopupMenuItem(
            height: 35,
            child: Text(localizations.deleteWhitelist, style: const TextStyle(fontSize: 13)),
            onTap: () {
              HostFilter.whitelist.remove(Uri.parse(widget.domain).host);
              configuration.flushConfig();
              FlutterToastr.show(localizations.deleteSuccess, context);
            }),
        const PopupMenuDivider(height: 0.3),
        CustomPopupMenuItem(
            height: 35,
            child: Text(localizations.delete, style: const TextStyle(fontSize: 13)),
            onTap: () => _delete()),
      ],
    );
  }

  _delete() {
    widget.requestMap.clear();
    widget.body.clear();
    widget.onDelete?.call(widget.domain);
    FlutterToastr.show(localizations.deleteSuccess, context);
  }
}
