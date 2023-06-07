import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:network/network/bin/server.dart';
import 'package:network/ui/widgets.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';
import 'network/util/AttributeKeys.dart';
import 'ui/components.dart';

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

class _NetworkHomePagePageState extends State<NetworkHomePage> implements EventListener {
  LinkedHashMap<HostAndPort, List<HttpRequest>> containerMap = LinkedHashMap<HostAndPort, List<HttpRequest>>();

  Set<String> expandedHosts = <String>{};

  @override
  void onRequest(Channel channel, HttpRequest request) {
    HostAndPort hostAndPort = channel.getAttribute(AttributeKeys.HOST_KEY);
    var list = containerMap[hostAndPort];
    if (list == null) {
      list = [request];
      setState(() {
        containerMap;
      });
      containerMap[hostAndPort] = list;
    } else {
      list.add(request);
    }
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {}

  @override
  void initState() {
    super.initState();
    print("initState");
    start(listener: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Row(children: [
          SizedBox(width: 420, child: ListView(children: _buildHosts())),
          const Spacer(),
          Expanded(flex: 100, child: NetworkTabController()),
        ]));
  }

  Widget _row(HostAndPort host) {
    bool selected = expandedHosts.contains(host.url);
    return ListTile(
        leading: Icon(selected ? Icons.arrow_drop_down : Icons.arrow_right, size: 16),
        dense: true,
        selected: selected,
        horizontalTitleGap: 0,
        visualDensity: const VisualDensity(vertical: -3.6),
        title: Text(host.url, textAlign: TextAlign.left),
        onTap: () {
          if (!expandedHosts.remove(host.url)) {
            expandedHosts.add(host.url);
          }
          setState(() {
            expandedHosts;
          });
        });
  }

  List<Widget> _buildHosts() {
    print(containerMap.keys);
    List<Widget> list = [];
    for (var host in containerMap.keys) {
      list.add(_row(host));

      if (expandedHosts.contains(host.url)) {
        containerMap[host]?.forEach((element) {
          print(element);
          list.add(ListURI(leading: Icons.html, text: '${element.method.name} ${Uri.parse(element.uri).path}'));
        });
      }
    }
    return list;
    // return [
    //   ListTile(
    //       leading: const Icon(Icons.arrow_drop_down),
    //       dense: true,
    //       title: const Text('https://dmall.com', textAlign: TextAlign.left),
    //       selected: true,
    //       onTap: () {}),
    //   const ListURI(leading: Icons.image_outlined, text: 'POST /private/browser/stats/haha'),
    //   const ListURI(leading: Icons.javascript_sharp, text: 'GET /private/browser/stats/haha'),
    //   const ListURI(leading: Icons.css, text: 'GET /private/browser/stats/haha'),
    //   ListTile(
    //       leading: const Icon(
    //         size: 15,
    //         Icons.document_scanner,
    //         color: Colors.red,
    //       ),
    //       title: const Text('POST /private/browser/stats', textAlign: TextAlign.left),
    //       textColor: Colors.red,
    //       trailing: const Icon(Icons.chevron_right),
    //       visualDensity: const VisualDensity(vertical: -4),
    //       dense: true,
    //       contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
    //       onTap: () {}),
    //   const Divider(),
    //   ListTile(
    //       leading: const Icon(Icons.expand_more),
    //       dense: true,
    //       title: const Text('https://baidu.com', textAlign: TextAlign.left),
    //       onTap: () {}),
    //   _buildRow(),
    //   const Divider(),
    // ];
  }

  Widget _buildRow() {
    final ScrollController scrollController = ScrollController();
    return Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Container(
              margin: const EdgeInsets.only(left: 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RowURI(leading: Icons.image, text: "POST /private/browser/stats/private/browser/stats"),
                  RowURI(leading: Icons.javascript_sharp, text: "GET /private/browser/stats.js"),
                  RowURI(leading: Icons.css, text: "GET /openapi/documents/oristartguid.css"),
                ],
              )),
        ));
  }
}
