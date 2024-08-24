import 'dart:collection';
import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/desktop/request/model/search_model.dart';
import 'package:network_proxy/ui/mobile/request/request_sequence.dart';
import 'package:network_proxy/utils/har.dart';
import 'package:network_proxy/utils/listenable_list.dart';
import 'package:share_plus/share_plus.dart';

/// 请求列表
/// @auth wanghongen
class RequestListWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final ListenableList<HttpRequest>? list;

  const RequestListWidget({super.key, required this.proxyServer, this.list});

  @override
  State<StatefulWidget> createState() {
    return RequestListState();
  }
}

class RequestListState extends State<RequestListWidget> {
  final GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();
  final GlobalKey<DomainListState> domainListKey = GlobalKey<DomainListState>();

  //请求列表容器
  ListenableList<HttpRequest> container = ListenableList();

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.list != null) {
      container = widget.list!;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Tab> tabs = [
      Tab(child: Text(localizations.sequence)),
      Tab(child: Text(localizations.domainList)),
    ];
    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: tabs), automaticallyImplyLeading: false),
          body: TabBarView(
            children: [
              RequestSequence(
                  key: requestSequenceKey,
                  container: container,
                  proxyServer: widget.proxyServer,
                  onRemove: sequenceRemove),
              DomainList(key: domainListKey, list: container, proxyServer: widget.proxyServer, onRemove: domainListRemove),
            ],
          ),
        ));
  }

  ///添加请求
  add(Channel channel, HttpRequest request) {
    container.add(request);
    requestSequenceKey.currentState?.add(request);
    domainListKey.currentState?.add(request);
  }

  ///添加响应
  addResponse(ChannelContext channelContext, HttpResponse response) {
    requestSequenceKey.currentState?.addResponse(response);
    domainListKey.currentState?.addResponse(response);
  }

  ///移除
  domainListRemove(List<HttpRequest> list) {
    container.removeWhere((element) => list.contains(element));
    requestSequenceKey.currentState?.remove(list);
  }

  ///全部请求删除
  sequenceRemove(List<HttpRequest> list) {
    container.removeWhere((element) => list.contains(element));
    domainListKey.currentState?.remove(list);
  }

  search(SearchModel searchModel) {
    requestSequenceKey.currentState?.search(searchModel);
    domainListKey.currentState?.search(searchModel.keyword?.trim());
  }

  Iterable<HttpRequest>? currentView() {
    return requestSequenceKey.currentState?.currentView();
  }

  ///清理
  clean() {
    setState(() {
      domainListKey.currentState?.clean();
      requestSequenceKey.currentState?.clean();
      container.clear();
    });
  }

  //导出har
  export(String title) async {
    //文件名称
    String fileName =
        '${title.contains("ProxyPin") ? '' : 'ProxyPin'}$title.har'.replaceAll(" ", "_").replaceAll(":", "_");
    //获取请求
    var view = currentView()!;
    var json = await Har.writeJson(view.toList(), title: title);
    var file = XFile.fromData(utf8.encode(json), name: fileName, mimeType: "har");
    Share.shareXFiles([file], fileNameOverrides: [fileName]);
  }
}

///域名列表
class DomainList extends StatefulWidget {
  final ListenableList<HttpRequest> list;
  final ProxyServer proxyServer;
  final Function(List<HttpRequest>)? onRemove;

  const DomainList({super.key, required this.list, required this.proxyServer, this.onRemove});

  @override
  State<StatefulWidget> createState() {
    return DomainListState();
  }
}

class DomainListState extends State<DomainList> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();
  late Configuration configuration;

  //域名和对应请求列表的映射
  Map<HostAndPort, List<HttpRequest>> containerMap = {};

  //域名列表 为了维护插入顺序
  LinkedHashSet<HostAndPort> domainList = LinkedHashSet<HostAndPort>();

  //显示的域名 最新的在顶部
  List<HostAndPort> view = [];

  HostAndPort? showHostAndPort;

  //搜索关键字
  String? searchText;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;

    for (var request in widget.list) {
      var hostAndPort = request.hostAndPort!;
      domainList.add(hostAndPort);
      var list = containerMap[hostAndPort] ??= [];
      list.add(request);
    }

    view = domainList.toList();
  }

  add(HttpRequest request) {
    var hostAndPort = request.hostAndPort!;
    domainList.remove(hostAndPort);
    domainList.add(hostAndPort);

    var list = containerMap[hostAndPort] ??= [];
    list.add(request);
    if (showHostAndPort == request.hostAndPort) {
      requestSequenceKey.currentState?.add(request);
    }

    if (!filter(request.hostAndPort!)) {
      return;
    }

    view = [...domainList.where(filter)].reversed.toList();
    setState(() {});
  }

  addResponse(HttpResponse response) {
    if (showHostAndPort == response.request?.hostAndPort) {
      requestSequenceKey.currentState?.addResponse(response);
    }
  }

  clean() {
    setState(() {
      view.clear();
      domainList.clear();
      containerMap.clear();
    });
  }

  remove(List<HttpRequest> list) {
    for (var request in list) {
      containerMap[request.hostAndPort]?.remove(request);
      if (containerMap[request.hostAndPort]!.isEmpty) {
        domainList.remove(request.hostAndPort);
        view.remove(request.hostAndPort);
      }
    }

    setState(() {});
  }

  ///搜索域名
  void search(String? text) {
    if (text == null) {
      setState(() {
        view = List.of(domainList.toList().reversed);
        searchText = null;
      });
      return;
    }

    text = text.toLowerCase();
    setState(() {
      var contains = text!.contains(searchText ?? "");
      searchText = text.toLowerCase();
      if (contains) {
        //包含从上次结果过滤
        view.retainWhere(filter);
      } else {
        view = List.of(domainList.where(filter).toList().reversed);
      }
    });
  }

  bool filter(HostAndPort hostAndPort) {
    if (searchText?.isNotEmpty == true) {
      return hostAndPort.domain.toLowerCase().contains(searchText!);
    }
    return true;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scrollbar(
        controller: _scrollController,
        child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            separatorBuilder: (context, index) =>
                Divider(thickness: 0.2, height: 0.5, color: Theme.of(context).dividerColor),
            itemCount: view.length,
            itemBuilder: (ctx, index) => title(index)));
  }

  Widget title(int index) {
    var value = containerMap[view.elementAt(index)];
    var time = value == null ? '' : formatDate(value.last.requestTime, [m, '/', d, ' ', HH, ':', nn, ':', ss]);

    return ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        title: Text(view.elementAt(index).domain, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        subtitle: Text(localizations.domainListSubtitle(value?.length ?? '', time),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        onLongPress: () => menu(index),
        // show menus
        contentPadding: const EdgeInsets.only(left: 10),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            showHostAndPort = view.elementAt(index);
            return Scaffold(
                appBar: AppBar(title: Text(view.elementAt(index).domain, style: const TextStyle(fontSize: 16))),
                body: RequestSequence(
                    key: requestSequenceKey,
                    displayDomain: false,
                    container: ListenableList(containerMap[view.elementAt(index)]!),
                    onRemove: widget.onRemove,
                    proxyServer: widget.proxyServer));
          }));
        });
  }

  ///菜单
  menu(int index) {
    var hostAndPort = view.elementAt(index);
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        context: context,
        enableDrag: true,
        builder: (ctx) {
          return Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                  child: SizedBox(
                      width: double.infinity, child: Text(localizations.copyHost, textAlign: TextAlign.center)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hostAndPort.host));
                    FlutterToastr.show(localizations.copied, context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: SizedBox(
                      width: double.infinity, child: Text(localizations.addBlacklist, textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.blacklist.add(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show(localizations.addSuccess, context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: SizedBox(
                      width: double.infinity, child: Text(localizations.addWhitelist, textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.add(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show(localizations.addSuccess, context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: SizedBox(
                      width: double.infinity, child: Text(localizations.deleteWhitelist, textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.remove(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show(localizations.deleteSuccess, context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: SizedBox(
                      width: double.infinity,
                      child: Text(localizations.repeatDomainRequests, textAlign: TextAlign.center)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    repeatDomainRequests(hostAndPort);
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child:
                      SizedBox(width: double.infinity, child: Text(localizations.delete, textAlign: TextAlign.center)),
                  onPressed: () {
                    setState(() {
                      var requests = containerMap.remove(hostAndPort);
                      domainList.remove(hostAndPort);
                      view.removeAt(index);
                      if (requests != null) {
                        widget.onRemove?.call(requests);
                      }
                      FlutterToastr.show(localizations.deleteSuccess, context);
                      Navigator.of(context).pop();
                    });
                  }),
              Container(
                color: Theme.of(context).hoverColor,
                height: 8,
              ),
              TextButton(
                child: Container(
                    height: 50,
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(localizations.cancel, textAlign: TextAlign.center)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  //重复域名下请求
  void repeatDomainRequests(HostAndPort hostAndPort) async {
    var requests = containerMap[hostAndPort];
    if (requests == null) return;

    for (var httpRequest in requests.toList()) {
      var request = httpRequest.copy(uri: httpRequest.requestUrl);
      var proxyInfo = widget.proxyServer.isRunning ? ProxyInfo.of("127.0.0.1", widget.proxyServer.port) : null;
      try {
        await HttpClients.proxyRequest(request, proxyInfo: proxyInfo);
        if (mounted) FlutterToastr.show(localizations.reSendRequest, rootNavigator: true, context);
      } catch (e) {
        if (mounted) FlutterToastr.show('${localizations.fail}$e', rootNavigator: true, context);
      }
    }
  }
}
