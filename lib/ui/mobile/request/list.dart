import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/mobile/request/request.dart';

class RequestListWidget extends StatefulWidget {
  final ProxyServer proxyServer;

  const RequestListWidget({super.key, required this.proxyServer});

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

  GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();
  GlobalKey<DomainListState> domainListKey = GlobalKey<DomainListState>();

  static List<HttpRequest> container = [];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: tabs)),
          body: TabBarView(
            children: [
              RequestSequence(key: requestSequenceKey, list: container, proxyServer: widget.proxyServer),
              DomainList(key: domainListKey, list: container, proxyServer: widget.proxyServer, onRemove: remove),
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
  addResponse(Channel channel, HttpResponse response) {
    response.request?.response = response;
    requestSequenceKey.currentState?.addResponse(response);
    domainListKey.currentState?.addResponse(response);
  }

  remove(List<HttpRequest> list) {
    container.removeWhere((element) => list.contains(element));
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

  const RequestSequence({super.key, required this.list, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return RequestSequenceState();
  }
}

class RequestSequenceState extends State<RequestSequence> {
  Map<HttpRequest, GlobalKey<RequestRowState>> indexes = HashMap();

  late Queue<HttpRequest> list = Queue();
  bool changing = false;

  @override
  initState() {
    super.initState();
    list.addAll(widget.list.reversed);
  }

  ///添加请求
  add(HttpRequest request) {
    list.addFirst(request);

    //防止频繁刷新
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          changing = false;
        });
      });
    }
  }

  ///添加响应
  addResponse(HttpResponse response) {
    response.request?.response = response;
    var state = indexes.remove(response.request);
    state?.currentState?.change(response);
  }

  clean() {
    setState(() {
      list.clear();
      indexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        separatorBuilder: (context, index) => Divider(height: 0.5, color: Theme.of(context).focusColor),
        itemCount: list.length,
        itemBuilder: (context, index) {
          GlobalKey<RequestRowState> key = GlobalKey();
          indexes[list.elementAt(index)] = key;
          return RequestRow(key: key, request: list.elementAt(index), proxyServer: widget.proxyServer);
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

class DomainListState extends State<DomainList> {
  GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();

  //域名和对应请求列表的映射
  Map<HostAndPort, List<HttpRequest>> containerMap = {};

  //域名列表 为了维护插入顺序
  LinkedHashSet<HostAndPort> container = LinkedHashSet<HostAndPort>();

  //显示的域名 最新的在顶部
  List<HostAndPort> list = [];
  HostAndPort? showHostAndPort;
  bool changing = false;

  @override
  initState() {
    super.initState();
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

    this.list = [...container].reversed.toList();
    //防止频繁刷新
    if (!changing) {
      changing = true;
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          changing = false;
        });
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        separatorBuilder: (context, index) => Divider(height: 0.5, color: Theme.of(context).focusColor),
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          var time =
              formatDate(containerMap[list.elementAt(index)]!.last.requestTime, [m, '/', d, ' ', HH, ':', nn, ':', ss]);
          return ListTile(
              title: Text(list.elementAt(index).domain, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              subtitle: Text("最后请求时间: $time,  次数: ${containerMap[list.elementAt(index)]!.length}",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onLongPress: () => menu(index),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  showHostAndPort = list.elementAt(index);
                  return Scaffold(
                      appBar: AppBar(title: const Text("请求列表")),
                      body: RequestSequence(
                          key: requestSequenceKey,
                          list: containerMap[list.elementAt(index)]!,
                          proxyServer: widget.proxyServer));
                }));
              });
        });
  }

  ///菜单
  menu(int index) {
    var hostAndPort = list.elementAt(index);
    showModalBottomSheet(
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
                    widget.proxyServer.flushConfig();
                    FlutterToastr.show("已添加至黑名单", context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("添加白名单", textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.add(hostAndPort.host);
                    widget.proxyServer.flushConfig();
                    FlutterToastr.show("已添加至白名单", context);
                    Navigator.of(context).pop();
                  }),
              const Divider(thickness: 0.5),
              TextButton(
                  child: const SizedBox(width: double.infinity, child: Text("删除白名单", textAlign: TextAlign.center)),
                  onPressed: () {
                    HostFilter.whitelist.remove(hostAndPort.host);
                    widget.proxyServer.flushConfig();
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
                    height: 60,
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
