import 'dart:collection';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';

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
              RequestSequence(key: requestSequenceKey, list: container),
              DomainList(key: domainListKey, list: container),
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

  const RequestSequence({super.key, required this.list});

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
    // listKey.currentState?.insertItem(0);

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
      // listKey.currentState?.removeAllItems((context, animation) => Container());
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
          return RequestRow(key: key, request: list.elementAt(index));
        });
  }
}

class RequestRow extends StatefulWidget {
  final HttpRequest request;

  const RequestRow({super.key, required this.request});

  @override
  State<StatefulWidget> createState() {
    return RequestRowState();
  }
}

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
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return NetworkTabController(
                httpRequest: request,
                httpResponse: response,
                title: const Text("抓包详情", style: TextStyle(fontSize: 16)));
          }));
        });
  }

  IconData getIcon(HttpResponse? response) {
    var map = {
      ContentType.json: Icons.data_object,
      ContentType.html: Icons.html,
      ContentType.js: Icons.javascript,
      ContentType.image: Icons.image,
      ContentType.text: Icons.text_fields,
      ContentType.css: Icons.css,
      ContentType.font: Icons.font_download,
    };
    if (response == null) {
      return Icons.question_mark;
    }
    var contentType = response.contentType;
    return map[contentType] ?? Icons.http;
  }
}

class DomainList extends StatefulWidget {
  final List<HttpRequest> list;

  const DomainList({super.key, required this.list});

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
              title: Text(list.elementAt(index).url, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              subtitle: Text("最后请求时间: $time,  次数: ${containerMap[list.elementAt(index)]!.length}",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  showHostAndPort = list.elementAt(index);
                  return Scaffold(
                      appBar: AppBar(title: const Text("请求列表")),
                      body: RequestSequence(key: requestSequenceKey, list: containerMap[list.elementAt(index)]!));
                }));
              });
        });
  }
}
