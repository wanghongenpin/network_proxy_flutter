import 'package:flutter/material.dart';
import 'package:network/network/http/http.dart';

class NetworkTabController extends StatefulWidget {
  final tabs = <Tab>[
    const Tab(child: Text('General', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Request', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Response', style: TextStyle(fontSize: 18))),
    const Tab(child: Text('Cookies', style: TextStyle(fontSize: 18))),
  ];

  final _NetworkTabState _state = _NetworkTabState();
  HttpRequest? request;
  HttpResponse? response;

  NetworkTabController({super.key});

  void change(HttpRequest request, HttpResponse? response) {
    _state.setState(() {
      this.request = request;
      this.response = response;
    });
  }

  @override
  State<StatefulWidget> createState() {
    return _state;
  }
}

class _NetworkTabState extends State<NetworkTabController> {
  @override
  Widget build(BuildContext context) {
    if (widget.request == null) {
      return const SizedBox();
    }

    return DefaultTabController(
        length: widget.tabs.length,
        child: Scaffold(
          appBar: AppBar(title: TabBar(tabs: widget.tabs)),
          body: TabBarView(
            children: [
              general(),
              request(),
              response(),
              ListView(children: const [Text("Cookies")])
            ],
          ),
        ));
  }

  Widget general() {
    return ExpansionTile(
        title: const Text("General", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            const Expanded(flex: 1, child: SelectableText("Request URL:")),
            Expanded(flex: 4, child: SelectableText(widget.request?.uri ?? ''))
          ]),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(flex: 1, child: SelectableText("Status Code:")),
            Expanded(flex: 4, child: SelectableText(widget.response?.status.code.toString() ?? ''))
          ])
        ]);
  }

  Widget request() {
    var headers = <Widget>[];
    widget.request?.headers.forEach((name, value) {
      headers.add(Row(children: [
        Expanded(flex: 2, child: SelectableText('$name:')),
        Expanded(flex: 4, child: SelectableText(value)),
        const SizedBox(height: 20),
      ]));
    });

    ExpansionTile? bodyWidgets;
    if (widget.request?.body?.isNotEmpty == true) {
      bodyWidgets = ExpansionTile(
          title: const Text("Request Body", style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(20),
          children: [
            SelectableText.rich(
                TextSpan(text: widget.request?.bodyAsString, style: const TextStyle(color: Colors.black)))
          ]);
    }

    return ListView(children: [
      ExpansionTile(
          title: const Text("Request Headers", style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(20),
          children: headers),
      const Divider(),
      bodyWidgets ?? const SizedBox()
    ]);
  }

  Widget response() {
    var headers = <Widget>[];
    widget.response?.headers.forEach((name, value) {
      headers.add(Row(children: [
        Expanded(flex: 2, child: SelectableText('$name:')),
        Expanded(flex: 4, child: SelectableText(value)),
        const SizedBox(height: 20),
      ]));
    });

    return ListView(children: [
      ExpansionTile(
          title: const Text("Response Headers", style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(20),
          children: headers),
      const Divider(),
      ExpansionTile(
          title: const Text("Response Body", style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(20),
          children: [
            SelectableText.rich(
                TextSpan(text: widget.response?.bodyAsString, style: const TextStyle(color: Colors.black))
            )
          ])
    ]);
  }
}
