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
  final _DomainWidgetState _state = _DomainWidgetState();
  final NetworkTabController panel;

  DomainWidget({super.key, required this.panel});

  void add(Channel channel, HttpRequest request) {
    _state.add(channel, request);
  }

  void addResponse(Channel channel, HttpResponse response) {
    _state.addResponse(channel, response);
  }

  void clean() {
    _state.clean();
  }

  @override
  State<StatefulWidget> createState() {
    return _state;
  }
}

class _DomainWidgetState extends State<DomainWidget> {
  LinkedHashMap<HostAndPort, ValueNotifier<HeaderBody>> containerMap =
      LinkedHashMap<HostAndPort, ValueNotifier<HeaderBody>>();

  @override
  Widget build(BuildContext context) {
    var map = containerMap.values.map((e) => ValueListenableBuilder<HeaderBody>(
        valueListenable: e,
        builder: (context, value, child) {
          return _show(value);
        }));

    return ListView(children: map.toList());
  }

  ///添加请求
  void add(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.HOST_KEY);
    ValueNotifier<HeaderBody>? valueNotifier = containerMap[hostAndPort];
    var listURI = RowURI(request, widget.panel);
    if (valueNotifier != null) {
      valueNotifier.value.addBody(channel.id, listURI);
      valueNotifier.value = valueNotifier.value.copy();
      return;
    }

    var headerBody = HeaderBody(hostAndPort.url);
    valueNotifier = ValueNotifier<HeaderBody>(headerBody);
    headerBody.addBody(channel.id, listURI);

    setState(() {
      containerMap[hostAndPort] = valueNotifier!;
    });
  }

  ///添加响应
  void addResponse(Channel channel, HttpResponse response) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.HOST_KEY);
    ValueNotifier<HeaderBody>? valueNotifier = containerMap[hostAndPort];
    if (valueNotifier != null && valueNotifier.value.getBody(channel.id) != null) {
      var body = valueNotifier.value.getBody(channel.id);
      body?.add(response);
      return;
    }
  }

  void clean() {
    setState(() {
      containerMap.forEach((key, value) {
        value.dispose();
      });
      containerMap.clear();
    });
  }

  Widget _show(Widget widget) {
    return AnimatedOpacity(opacity: 1.0, duration: const Duration(seconds: 2), child: widget);
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
    print("initState");
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
          Expanded(flex: 100, child: Visibility(visible: true, child: domainWidget.panel)),
        ]));
  }
}
