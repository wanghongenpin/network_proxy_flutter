import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/storage/histories.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/mobile/request/list.dart';

import '../../../utils/har.dart';

class MobileHistory extends StatefulWidget {
  final ProxyServer proxyServer;
  final GlobalKey<RequestListState> requestStateKey;

  const MobileHistory({Key? key, required this.proxyServer, required this.requestStateKey}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _MobileHistoryState();
  }
}

class _MobileHistoryState extends State<MobileHistory> {
  ///是否保存会话
  static bool _sessionSaved = false;
  static WriteTask? writeTask;

  @override
  Widget build(BuildContext context) {
    return futureWidget(HistoryStorage.instance, (data) {
      List<Widget> children = [];

      var container = widget.requestStateKey.currentState?.container;
      if (container?.isNotEmpty == true && !_sessionSaved) {
        //当前会话未保存，是否保存当前会话
        children.add(buildSaveSession(data, container!));
      }

      var histories = data.histories;
      for (int i = histories.length - 1; i >= 0; i--) {
        var entry = histories.elementAt(i);
        children.add(buildItem(data, i, entry));
      }

      if (children.isEmpty) {
        return const Center(child: Text("暂无历史记录"));
      }
      return ListView.separated(
        itemCount: children.length,
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, index) => const Divider(thickness: 0.3, height: 0),
      );
    });
  }

  //构建保存会话
  Widget buildSaveSession(HistoryStorage storage, List<HttpRequest> container) {
    var name = formatDate(DateTime.now(), [mm, '-', d, ' ', HH, ':', nn, ':', ss]);

    return ListTile(
        dense: true,
        title: Text(name),
        subtitle: Text("当前会话未保存 记录数 ${container.length}"),
        trailing: TextButton.icon(
          icon: const Icon(Icons.save),
          label: const Text("保存"),
          onPressed: () async {
            await _writeHarFile(storage, container, name);
            setState(() {
              _sessionSaved = true;
            });
          },
        ),
        onTap: () {});
  }

  //写入文件
  _writeHarFile(HistoryStorage storage, List<HttpRequest> container, String name) async {
    var file = await HistoryStorage.openFile("${DateTime.now().millisecondsSinceEpoch}.txt");
    print(file);
    RandomAccessFile open = await file.open(mode: FileMode.append);
    HistoryItem history = await storage.addHistory(name, file, 0);

    writeTask = WriteTask(history, open, storage);
    writeTask?.writeList.addAll(container);
    widget.proxyServer.addListener(writeTask!);
    await writeTask?.writeTask();
    writeTask?.startTask();
    setState(() {});
  }

  //构建历史记录
  Widget buildItem(HistoryStorage storage, int index, HistoryItem item) {
    return ListTile(
        dense: true,
        title: Text(item.name),
        subtitle: Text("记录数 ${item.requestLength}  文件 ${item.size}"),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
            return Scaffold(
                appBar:
                    AppBar(title: Text('${item.name} 记录数 ${item.requestLength}', style: const TextStyle(fontSize: 16))),
                body: futureWidget(
                    loading: true,
                    storage.getRequests(item),
                    (data) => RequestListWidget(proxyServer: widget.proxyServer, list: data)));
          })).then((value) => Future.delayed(const Duration(seconds: 60), () => item.requests = null));
        },
        onLongPress: () => deleteHistory(storage, index));
  }

  //删除
  deleteHistory(HistoryStorage storage, int index) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text("是否删除该历史记录？", style: TextStyle(fontSize: 18)),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("取消")),
              TextButton(
                  onPressed: () {
                    setState(() {
                      if (storage.getHistory(index) == writeTask?.history) {
                        writeTask?.timer?.cancel();
                        writeTask?.open.close();
                        writeTask = null;
                      }
                      storage.removeHistory(index);
                    });
                    FlutterToastr.show('删除成功', context);
                    Navigator.pop(context);
                  },
                  child: const Text("删除")),
            ],
          );
        });
  }
}

class WriteTask implements EventListener {
  final HistoryStorage historyStorage;
  final RandomAccessFile open;
  Queue writeList = Queue();
  Timer? timer;
  final HistoryItem history;

  WriteTask(this.history, this.open, this.historyStorage);

  //写入任务
  startTask() {
    timer = Timer.periodic(const Duration(seconds: 15), (it) => writeTask());
  }

  @override
  void onRequest(Channel channel, HttpRequest request) {}

  @override
  void onResponse(Channel channel, HttpResponse response) {
    if (response.request == null) {
      return;
    }
    writeList.add(response.request!);
  }

  //写入任务
  writeTask() async {
    if (writeList.isEmpty) {
      return;
    }
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
    await historyStorage.refresh();
  }
}
