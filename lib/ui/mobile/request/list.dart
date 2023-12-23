import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/components/host_filter.dart';
import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/ui/mobile/request/request.dart';
import 'package:network_proxy/ui/ui_configuration.dart';
import 'package:network_proxy/utils/lang.dart';

class RequestListWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final List<HttpRequest>? list;

  const RequestListWidget({super.key, required this.proxyServer, this.list});

  @override
  State<StatefulWidget> createState() {
    return RequestListState();
  }
}

class RequestListState extends State<RequestListWidget> {
  final tabs = <Tab>[
    const Tab(child: Text('全部请求')),
    const Tab(child: Text('域名列表')),
  ];

  final GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();
  final GlobalKey<DomainListState> domainListKey = GlobalKey<DomainListState>();

  //请求列表容器
  static List<HttpRequest> container = [];

  @override
  void initState() {
    super.initState();
    if (widget.list != null) {
      container.addAll(widget.list!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pictureInPictureNotifier.value) {
      if (container.isEmpty) {
        return const Center(child: Text("暂无请求", style: TextStyle(color: Colors.grey)));
      }

      return ListView.separated(
          padding: const EdgeInsets.only(left: 2),
          itemCount: container.length,
          separatorBuilder: (context, index) => const Divider(thickness: 0.3, height: 0.5),
          itemBuilder: (context, index) {
            return Text.rich(
                overflow: TextOverflow.ellipsis,
                TextSpan(
                    text: container[container.length - index - 1].requestUrl.fixAutoLines(),
                    style: const TextStyle(fontSize: 9)),
                maxLines: 2);
          });
    }

    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: tabs), automaticallyImplyLeading: false),
          body: TabBarView(
            children: [
              RequestSequence(
                  key: requestSequenceKey, list: container, proxyServer: widget.proxyServer, onRemove: remove),
              DomainList(key: domainListKey, list: container, proxyServer: widget.proxyServer, onRemove: remove),
            ],
          ),
        ));
  }

  ///添加请求
  add(Channel channel, HttpRequest request) {
    if (pictureInPictureNotifier.value) {
      setState(() {
        container.add(request);
      });
      return;
    }

    container.add(request);
    requestSequenceKey.currentState?.add(request);
    domainListKey.currentState?.add(request);
  }

  ///添加响应
  addResponse(Channel channel, HttpResponse response) {
    response.request?.response = response;
    requestSequenceKey.currentState?.addResponse(response);
    domainListKey.currentState?.addResponse(response);
  }

  ///移除
  remove(List<HttpRequest> list) {
    container.removeWhere((element) => list.contains(element));
  }

  search(SearchModel searchModel) {
    requestSequenceKey.currentState?.search(searchModel);
    domainListKey.currentState?.search(searchModel.keyword?.trim());
  }

  ///清理
  clean() {
    setState(() {
      domainListKey.currentState?.clean();
      requestSequenceKey.currentState?.clean();
      container.clear();
    });
  }
}

///请求序列 列表
class RequestSequence extends StatefulWidget {
  final List<HttpRequest> list;
  final ProxyServer proxyServer;
  final bool displayDomain;
  final Function(List<HttpRequest>)? onRemove;

  const RequestSequence(
      {super.key, required this.list, required this.proxyServer, this.displayDomain = true, this.onRemove});

  @override
  State<StatefulWidget> createState() {
    return RequestSequenceState();
  }
}

class RequestSequenceState extends State<RequestSequence> with AutomaticKeepAliveClientMixin {
  ///请求和对应的row的映射
  Map<HttpRequest, GlobalKey<RequestRowState>> indexes = HashMap();

  late List<HttpRequest> list = [];

  ///显示的请求列表 最新的在前面
  late Queue<HttpRequest> view = Queue();
  bool changing = false;

  //搜索的内容
  SearchModel? searchModel;

  @override
  initState() {
    super.initState();
    list = widget.list;
    view.addAll(list.reversed);
  }

  ///添加请求
  add(HttpRequest request) {
    list.add(request);

    ///过滤
    if (searchModel?.isNotEmpty == true && !searchModel!.filter(request, request.response)) {
      return;
    }

    view.addFirst(request);
    changeState();
  }

  ///添加响应
  addResponse(HttpResponse response) {
    response.request?.response = response;
    var state = indexes.remove(response.request);
    state?.currentState?.change(response);

    if (searchModel == null || searchModel!.isEmpty || response.request == null) {
      return;
    }

    //搜索视图
    if (searchModel?.filter(response.request!, response) == true && state == null) {
      if (!view.contains(response.request)) {
        view.addFirst(response.request!);
        changeState();
      }
    }
  }

  clean() {
    setState(() {
      list.clear();
      view.clear();
      indexes.clear();
    });
  }

  ///过滤
  void search(SearchModel searchModel) {
    this.searchModel = searchModel;
    if (searchModel.isEmpty) {
      view = Queue.of(list.reversed);
    } else {
      view = Queue.of(list.where((it) => searchModel.filter(it, it.response)).toList().reversed);
    }
    changeState();
  }

  changeState() {
    //防止频繁刷新
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 50), () {
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

    return ListView.separated(
        cacheExtent: 1000,
        separatorBuilder: (context, index) => Divider(thickness: 0.2, height: 0, color: Theme.of(context).dividerColor),
        itemCount: view.length,
        itemBuilder: (context, index) {
          GlobalKey<RequestRowState> key = GlobalKey();
          indexes[view.elementAt(index)] = key;
          return RequestRow(
              index: view.length - index,
              key: key,
              request: view.elementAt(index),
              proxyServer: widget.proxyServer,
              displayDomain: widget.displayDomain,
              onRemove: (request) {
                widget.onRemove?.call([request]);
                setState(() {
                  list.remove(request);
                  view.remove(request);
                });
              });
        });
  }
}

///域名列表
class DomainList extends StatefulWidget {
  final List<HttpRequest> list;
  final ProxyServer proxyServer;
  final Function(List<HttpRequest>)? onRemove;

  const DomainList({super.key, required this.list, required this.proxyServer, this.onRemove});

  @override
  State<StatefulWidget> createState() {
    return DomainListState();
  }
}

class DomainListState extends State<DomainList> with AutomaticKeepAliveClientMixin {
  GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();
  late Configuration configuration;

  //域名和对应请求列表的映射
  Map<HostAndPort, List<HttpRequest>> containerMap = {};

  //域名列表 为了维护插入顺序
  LinkedHashSet<HostAndPort> container = LinkedHashSet<HostAndPort>();

  //显示的域名 最新的在顶部
  List<HostAndPort> list = [];
  HostAndPort? showHostAndPort;

  //搜索关键字
  String? searchText;

  @override
  initState() {
    super.initState();
    configuration = widget.proxyServer.configuration;

    for (var request in widget.list) {
      var hostAndPort = request.hostAndPort!;
      container.add(hostAndPort);
      var list = containerMap[hostAndPort];
      if (list == null) {
        list = [];
        containerMap[hostAndPort] = list;
      }
      list.add(request);
    }

    list = container.toList();
  }

  add(HttpRequest request) {
    var hostAndPort = request.hostAndPort!;
    container.remove(hostAndPort);
    container.add(hostAndPort);
    var list = containerMap[hostAndPort];
    if (list == null) {
      list = [];
      containerMap[hostAndPort] = list;
    }
    list.add(request);
    if (showHostAndPort == request.hostAndPort) {
      requestSequenceKey.currentState?.add(request);
    }

    if (!filter(request.hostAndPort!)) {
      return;
    }

    this.list = [...container.where(filter)].reversed.toList();
    setState(() {});
  }

  addResponse(HttpResponse response) {
    if (showHostAndPort == response.request?.hostAndPort) {
      requestSequenceKey.currentState?.addResponse(response);
    }
  }

  clean() {
    setState(() {
      list.clear();
      container.clear();
      containerMap.clear();
    });
  }

  ///搜索域名
  void search(String? text) {
    if (text == null) {
      setState(() {
        list = List.of(container.toList().reversed);
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
        list.retainWhere(filter);
      } else {
        list = List.of(container.where(filter).toList().reversed);
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
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.separated(
        padding: EdgeInsets.zero,
        separatorBuilder: (context, index) =>
            Divider(thickness: 0.2, height: 0.5, color: Theme.of(context).dividerColor),
        itemCount: list.length,
        itemBuilder: (ctx, index) => title(index));
  }

  Widget title(int index) {
    var value = containerMap[list.elementAt(index)];
    var time = value == null ? '' : formatDate(value.last.requestTime, [m, '/', d, ' ', HH, ':', nn, ':', ss]);
    return ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        title: Text(list.elementAt(index).domain, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        subtitle: Text("最后请求时间: $time,  次数: ${value?.length}", maxLines: 1, overflow: TextOverflow.ellipsis),
        onLongPress: () => menu(index),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            showHostAndPort = list.elementAt(index);
            return Scaffold(
                appBar: AppBar(title: Text(list.elementAt(index).domain, style: const TextStyle(fontSize: 16))),
                body: RequestSequence(
                    key: requestSequenceKey,
                    displayDomain: false,
                    list: containerMap[list.elementAt(index)]!,
                    onRemove: widget.onRemove,
                    proxyServer: widget.proxyServer));
          }));
        });
  }

  ///菜单
  menu(int index) {
    var hostAndPort = list.elementAt(index);
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        context: context,
        enableDrag: true,
        builder: (ctx) {
          return Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("添加黑名单", textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.blacklist.add(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show("已添加至黑名单", context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("添加白名单", textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.add(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show("已添加至白名单", context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("删除白名单", textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.remove(hostAndPort.host);
                    configuration.flushConfig();
                    FlutterToastr.show("已删除白名单", context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("删除", textAlign: TextAlign.center)),
                  onPressed: () {
                    setState(() {
                      var requests = containerMap.remove(hostAndPort);
                      container.remove(hostAndPort);
                      list.removeAt(index);
                      if (requests != null) {
                        widget.onRemove?.call(requests);
                      }
                      FlutterToastr.show("删除成功", context);
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
                    child: const Text("取消", textAlign: TextAlign.center)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}
