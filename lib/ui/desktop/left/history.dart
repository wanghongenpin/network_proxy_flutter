import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/storage/histories.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/utils/har.dart';

import '../../content/panel.dart';
import 'domain.dart';

///历史记录
class HistoryPageWidget extends StatelessWidget {
  final ProxyServer proxyServer;
  final GlobalKey<DomainWidgetState> domainWidgetState;
  final NetworkTabController panel;

  const HistoryPageWidget({super.key, required this.proxyServer, required this.domainWidgetState, required this.panel});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case "/domain":
            return MaterialPageRoute(builder: (_) => domainWidget(settings.arguments as Map));
          default:
            return MaterialPageRoute(
                builder: (_) => futureWidget(
                      HistoryStorage.instance,
                      (storage) => _HistoryWidget(storage,
                          container: domainWidgetState.currentState!.container, proxyServer: proxyServer),
                    ));
        }
      },
    );
  }

  Widget domainWidget(Map arguments) {
    return Scaffold(
        appBar: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: AppBar(
              leading: BackButton(style: ButtonStyle(iconSize: MaterialStateProperty.all(15))),
              centerTitle: false,
              title: Text(arguments['title'], style: const TextStyle(fontSize: 14)),
            )),
        body: futureWidget(HistoryStorage.instance.then((value) => value.getRequests(arguments['name'])), (data) {
          return DomainWidget(panel: panel, proxyServer: proxyServer, list: data, shrinkWrap: false);
        }));
  }
}

class _HistoryWidget extends StatefulWidget {
  // 存储
  final HistoryStorage storage;
  final List<HttpRequest> container;
  final ProxyServer proxyServer;

  const _HistoryWidget(this.storage, {required this.container, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _HistoryState();
  }
}

class _HistoryState extends State<_HistoryWidget> implements EventListener {
  ///是否保存会话
  static bool _sessionSaved = false;
  static WriteTask? writeTask;

  // 存储
  late HistoryStorage storage;

  late List<HttpRequest> container;
  late ProxyServer proxyServer;

  @override
  void initState() {
    super.initState();
    storage = widget.storage;
    container = widget.container;
    proxyServer = widget.proxyServer;
  }

  @override
  Widget build(BuildContext context) {
    print("_HistoryState build");
    List<Widget> children = [];
    if (!_sessionSaved) {
      //当前会话未保存，是否保存当前会话
      children.add(buildSaveSession(container));
    }

    var entries = storage.histories.entries;
    for (int i = entries.length - 1; i >= 0; i--) {
      var entry = entries.elementAt(i);
      children.add(buildItem(context, entry.key, entry.value));
    }

    return ListView.separated(
      itemCount: children.length,
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, index) => const Divider(thickness: 0.3, height: 0),
    );
  }

  //构建保存会话
  Widget buildSaveSession(List<HttpRequest> container) {
    var name = formatDate(DateTime.now(), [mm, '-', d, ' ', HH, ':', nn, ':', ss]);

    return ListTile(
        dense: true,
        title: Text(name),
        subtitle: Text("当前会话未保存 记录数 ${container.length}"),
        trailing: TextButton.icon(
          icon: const Icon(Icons.save),
          label: const Text("保存"),
          onPressed: () async {
            await _writeHarFile(container, name);
            setState(() {
              _sessionSaved = true;
            });
          },
        ),
        onTap: () => ContextMenuController.removeAny());
  }

  //构建历史记录
  Widget buildItem(BuildContext context, String name, HistoryItem item) {
    return GestureDetector(
        onSecondaryTapDown: (details) => {
              showContextMenu(context, details.globalPosition, items: [
                CustomPopupMenuItem(
                    height: 35,
                    child: const Text('删除', style: TextStyle(fontSize: 13)),
                    onTap: () {
                      setState(() {
                        if (name == writeTask?.name) {
                          writeTask?.timer?.cancel();
                          writeTask?.open.close();
                        }
                        storage.removeHistory(name);
                      });
                    })
              ])
            },
        child: ListTile(
            dense: true,
            title: Text(name),
            subtitle: Text("记录数 ${item.requestLength}  文件 ${item.size}"),
            onTap: () {
              ContextMenuController.removeAny();
              Navigator.pushNamed(context, '/domain',
                      arguments: {'title': '$name 记录数 ${item.requestLength}', 'name': name})
                  .then((value) => Future.delayed(const Duration(seconds: 60), () => storage.removeCache(name)));
            }));
  }

  //写入文件
  _writeHarFile(List<HttpRequest> container, String name) async {
    var file = await HistoryStorage.openFile("${DateTime.now().millisecondsSinceEpoch}.txt");
    print(file);
    RandomAccessFile open = await file.open(mode: FileMode.append);
    storage.addHistory(name, file, 0);

    writeTask = WriteTask(name, open, storage, callback: () => setState(() {}));
    writeTask?.writeList.addAll(container);
    writeTask?.startTask();

    proxyServer.addListener(this);
  }

  @override
  void onRequest(Channel channel, HttpRequest request) {}

  @override
  void onResponse(Channel channel, HttpResponse response) async {
    if (response.request == null) {
      return;
    }
    writeTask?.writeList.add(response.request!);
  }
}

class WriteTask {
  final HistoryStorage historyStorage;
  final RandomAccessFile open;
  Queue writeList = Queue();
  Timer? timer;
  final Function? callback;
  final String name;

  WriteTask(this.name, this.open, this.historyStorage, {this.callback});

  //写入任务
  startTask() {
    timer = Timer.periodic(const Duration(seconds: 15), (it) => writeTask());
  }

  //写入任务
  writeTask() async {
    if (writeList.isEmpty) {
      return;
    }
    var history = historyStorage.getHistory(name);
    int length = history.requestLength;

    while (writeList.isNotEmpty) {
      var request = writeList.removeFirst();
      var har = Har.toHar(request);

      await open.writeString(jsonEncode(har));
      await open.writeString(",\n");
      length++;
    }

    await open.flush(); //刷新

    history.requestLength = length;
    history.fileSize = await open.length();
    historyStorage.updateHistory(name, history);
    callback?.call();
  }
}
