import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/utils/curl.dart';

import '../../network/channel.dart';
import '../content/panel.dart';

class RequestWidget extends StatefulWidget {
  final ProxyServer proxyServer;

  const RequestWidget({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return RequestWidgetState();
  }
}

class RequestWidgetState extends State<RequestWidget> {
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
              DomainList(key: domainListKey, list: container, proxyServer: widget.proxyServer),
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

  ///清理
  clean() {
    setState(() {
      domainListKey.currentState?.clean();
      requestSequenceKey.currentState?.clean();
      container.clear();
    });
  }
}

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
  // GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();
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

class RequestRow extends StatefulWidget {
  final HttpRequest request;
  final ProxyServer proxyServer;

  const RequestRow({super.key, required this.request, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return RequestRowState();
  }
}

///请求行
class RequestRowState extends State<RequestRow> {
  late HttpRequest request;
  HttpResponse? response;

  change(HttpResponse response) {
    setState(() {
      this.response = response;
    });
  }

  @override
  void initState() {
    request = widget.request;
    response = request.response;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var title = '${request.method.name} ${request.requestUrl}';
    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    return ListTile(
        leading: Icon(getIcon(response), size: 16, color: Colors.green),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
        subtitle: Text(
            '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} ',
            maxLines: 1),
        trailing: const Icon(Icons.chevron_right),
        onLongPress: () {
          menu(menuPosition(context));
        },
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return NetworkTabController(
                httpRequest: request,
                httpResponse: response,
                title: const Text("抓包详情", style: TextStyle(fontSize: 16)));
          }));
        });
  }

  ///右键菜单
  menu(RelativeRect position) {
    // Feedback.forLongPress(context);
    HapticFeedback.lightImpact();

    showMenu(
      context: context,
      position: position,
      items: <PopupMenuEntry>[
        PopupMenuItem(
            child: const Text("复制请求链接"),
            onTap: () {
              var requestUrl = widget.request.requestUrl;
              Clipboard.setData(ClipboardData(text: requestUrl))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            child: const Text("复制请求和响应"),
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyRequest(widget.request, response)))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            child: const Text("复制 cURL 请求"),
            onTap: () {
              Clipboard.setData(ClipboardData(text: curlRequest(widget.request)))
                  .then((value) => FlutterToastr.show('已复制到剪切板', context));
            }),
        PopupMenuItem(
            child: const Text("重放请求", style: TextStyle(fontSize: 14)),
            onTap: () {
              var request = widget.request.copy(uri: widget.request.requestUrl);
              HttpClients.proxyRequest("127.0.0.1", widget.proxyServer.port, request);
              FlutterToastr.show('已重新发送请求', context);
            }),
      ],
    );
  }
}

///域名列表
class DomainList extends StatefulWidget {
  final List<HttpRequest> list;
  final ProxyServer proxyServer;

  const DomainList({super.key, required this.list, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return DomainListState();
  }
}

class DomainListState extends State<DomainList> {
  GlobalKey<RequestSequenceState> requestSequenceKey = GlobalKey<RequestSequenceState>();

  Map<HostAndPort, List<HttpRequest>> containerMap = {};

  LinkedHashSet<HostAndPort> container = LinkedHashSet<HostAndPort>();
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
        itemBuilder: (context, index) {
          var time =
              formatDate(containerMap[list.elementAt(index)]!.last.requestTime, [m, '/', d, ' ', HH, ':', nn, ':', ss]);
          return ListTile(
              title: Text(list.elementAt(index).domain, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              subtitle: Text("最后请求时间: $time,  次数: ${containerMap[list.elementAt(index)]!.length}",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
}
