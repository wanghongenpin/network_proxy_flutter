import 'package:flutter/material.dart';

class NetworkTabController extends DefaultTabController {
  static const myTabs = <Tab>[
    Tab(child: Text('General', style: TextStyle(fontSize: 18))),
    Tab(child: Text('Request', style: TextStyle(fontSize: 18))),
    Tab(child: Text('Response', style: TextStyle(fontSize: 18))),
    Tab(child: Text('Cookies', style: TextStyle(fontSize: 18))),
  ];

  NetworkTabController({super.key})
      : super(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const TabBar(tabs: myTabs),
              ),
              body: TabBarView(
                children: [
                  ListView(children: const [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: "Home: "),
                      TextSpan(text: "https://flutterchina.club", style: TextStyle(color: Colors.blue)),
                    ]))
                  ]),
                  Container(
                      padding: const EdgeInsets.all(20),
                      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Row(children: [
                          Expanded(flex: 1, child: Text("Request URL:")),
                          Expanded(
                              flex: 4,
                              child: Text(
                                  "https://googleads.g.doubleclick.net/pagead/html/r20230601/r20190131/zrt_lookup.html"))
                        ]),
                        SizedBox(height: 10), //保留间距
                        Row(children: [
                          Expanded(flex: 1, child: Text("Request Method:")),
                          Expanded(flex: 4, child: Text("GET"))
                        ]),
                        SizedBox(height: 10), //保留间距
                        Row(children: [
                          Expanded(flex: 1, child: Text("Status Code:")),
                          Expanded(flex: 4, child: Text("200"))
                        ]),
                        SizedBox(height: 10), //保留间距
                        Row(children: [
                          Expanded(flex: 1, child: Text("Remote Address:")),
                          Expanded(flex: 4, child: Text("127.0.0.1:8080"))
                        ])
                      ])),
                  const ExpansionTile(
                      title: Text("General", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      initiallyExpanded: true,
                      childrenPadding: EdgeInsets.all(20),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(flex: 1, child: Text("Request URL:")),
                          Expanded(
                              flex: 4,
                              child: Text(
                                  "https://googleads.g.doubleclick.net/pagead/html/r20230601/r20190131/zrt_lookup.html"))
                        ]),
                        SizedBox(
                          height: 20,
                        ),
                        Row(children: [
                          Expanded(flex: 1, child: Text("Status Code:")),
                          Expanded(flex: 4, child: Text("200"))
                        ])
                      ]),
                  ListView(children: const [Text("Cookies")])
                ],
              ),
            ));
}
