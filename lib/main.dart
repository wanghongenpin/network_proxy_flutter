import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network/network/bin/server.dart';
import 'package:network/ui/left.dart';
import 'package:network/ui/panel.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';
import 'network/util/AttributeKeys.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doraemon',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const NetworkHomePage(title: 'Network Proxy'),
    );
  }
}

class NetworkHomePage extends StatefulWidget {
  const NetworkHomePage({super.key, required this.title});

  final String title;

  @override
  State<NetworkHomePage> createState() => _NetworkHomePagePageState();
}

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
    return ListView.builder(itemBuilder: (BuildContext context, int index) => list.elementAt(index), itemCount: list.length );
  }

  ///添加请求
  void add(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.host);
    HeaderBody? headerBody = containerMap[hostAndPort];
    var listURI = RowURI(request, widget.panel);
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

  void clean() {
    setState(() {
      containerMap.clear();
    });
  }
}

class _NetworkHomePagePageState extends State<NetworkHomePage> implements EventListener {
  late DomainWidget domainWidget;
  final NetworkTabController panel = NetworkTabController();

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainWidget.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainWidget.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    domainWidget = DomainWidget(panel: panel);
    start(listener: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => domainWidget.clean(), icon: const Icon(Icons.cleaning_services)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Row(children: [
          SizedBox(width: 420, child: domainWidget),
          const Spacer(),
          Expanded(flex: 100,  child: domainWidget.panel),
        ]));
  }
}
