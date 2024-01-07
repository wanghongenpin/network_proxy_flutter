/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/storage/histories.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/mobile/mobile.dart';
import 'package:network_proxy/ui/mobile/request/list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../utils/har.dart';

class MobileHistory extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileHistory({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _MobileHistoryState();
  }
}

class _MobileHistoryState extends State<MobileHistory> {
  ///是否保存会话
  static bool _sessionSaved = false;
  static WriteTask? writeTask;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return futureWidget(HistoryStorage.instance, (data) {
      List<Widget> children = [];

      var container = MobileHomeState.requestStateKey.currentState!.container;
      if (container.isNotEmpty == true && !_sessionSaved) {
        //当前会话未保存，是否保存当前会话
        children.add(buildSaveSession(data, container));
      }

      var histories = data.histories;
      for (int i = histories.length - 1; i >= 0; i--) {
        var entry = histories.elementAt(i);
        children.add(buildItem(data, i, entry));
      }

      return Scaffold(
          appBar: AppBar(
            title: Text(localizations.history, style: const TextStyle(fontSize: 16)),
            centerTitle: true,
            actions: [TextButton(onPressed: () => import(data), child: Text(localizations.import))],
          ),
          body: children.isEmpty
              ? Center(child: Text(localizations.emptyData))
              : ListView.separated(
                  itemCount: children.length,
                  itemBuilder: (context, index) => children[index],
                  separatorBuilder: (_, index) => const Divider(thickness: 0.3, height: 0),
                ));
    });
  }

  //构建保存会话
  Widget buildSaveSession(HistoryStorage storage, List<HttpRequest> container) {
    var name = formatDate(DateTime.now(), [mm, '-', d, ' ', HH, ':', nn, ':', ss]);

    return ListTile(
        dense: true,
        title: Text(name),
        subtitle: Text(localizations.historyUnSave(container.length)),
        trailing: TextButton.icon(
          icon: const Icon(Icons.save),
          label: Text(localizations.save),
          onPressed: () async {
            await _writeHarFile(storage, container, name);
            setState(() {
              _sessionSaved = true;
            });
          },
        ),
        onTap: () {});
  }

  //导入har
  import(HistoryStorage storage) async {
    const XTypeGroup typeGroup =
        XTypeGroup(label: 'har', extensions: <String>['har'], uniformTypeIdentifiers: ["public.item"]);
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return;
    }

    try {
      var historyItem = await storage.addHarFile(file);
      setState(() {
        toRequestsView(historyItem, storage);
        FlutterToastr.show(localizations.importSuccess, context);
      });
    } catch (e, t) {
      logger.e("导入失败", error: e, stackTrace: t);
      if (context.mounted) {
        FlutterToastr.show("${localizations.importFailed} $e", context);
      }
    }
  }

  //写入文件
  _writeHarFile(HistoryStorage storage, List<HttpRequest> container, String name) async {
    var file = await HistoryStorage.openFile("${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}.txt");
    RandomAccessFile open = await file.open(mode: FileMode.append);
    HistoryItem history = await storage.addHistory(name, file, 0);

    writeTask = WriteTask(history, open, storage);
    writeTask?.writeList.addAll(container);
    widget.proxyServer.addListener(writeTask!);
    await writeTask?.writeTask();
    writeTask?.startTask();
    setState(() {});
  }

  int selectIndex = -1;

  //构建历史记录
  Widget buildItem(HistoryStorage storage, int index, HistoryItem item) {
    return InkWell(
        onTapDown: (detail) async {
          HapticFeedback.heavyImpact();
          showContextMenu(context, detail.globalPosition.translate(-50, index == 0 ? -100 : 100), items: [
            PopupMenuItem(child: Text(localizations.rename), onTap: () => renameHistory(storage, item)),
            PopupMenuItem(child: Text(localizations.share), onTap: () => export(storage, item)),
            const PopupMenuDivider(height: 0.3),
            PopupMenuItem(child: Text(localizations.delete), onTap: () => deleteHistory(storage, index))
          ]);
        },
        child: ListTile(
          dense: true,
          selected: selectIndex == index,
          title: Text(item.name),
          subtitle: Text(localizations.historySubtitle(item.requestLength, item.size)),
          onTap: () => toRequestsView(item, storage),
        ));
  }

  toRequestsView(HistoryItem item, HistoryStorage storage) {
    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
      bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');
      return Scaffold(
          appBar: AppBar(
              title: Text('${item.name} ${isCN ? "记录数" : "Records"} ${item.requestLength}',
                  style: const TextStyle(fontSize: 16))),
          body: futureWidget(
              loading: true,
              storage.getRequests(item),
              (data) => RequestListWidget(proxyServer: widget.proxyServer, list: data)));
    })).then((value) async {
      if (item != writeTask?.history && item.requests != null && item.requestLength != item.requests?.length) {
        await storage.flushRequests(item, item.requests!);
        setState(() {});
      }
      Future.delayed(const Duration(seconds: 60), () => item.requests = null);
    });
  }

  //导出har
  export(HistoryStorage storage, HistoryItem item) async {
    //文件名称
    String fileName =
        '${item.name.contains("ProxyPin") ? '' : 'ProxyPin'}${item.name}.har'.replaceAll(" ", "_").replaceAll(":", "_");
    //获取请求
    List<HttpRequest> requests = await storage.getRequests(item);
    var json = await Har.writeJson(requests, title: item.name);
    var file = XFile.fromData(utf8.encode(json), name: fileName, mimeType: "har");
    Share.shareXFiles([file], subject: fileName);
    Future.delayed(const Duration(seconds: 30), () => item.requests = null);
  }

  //重命名
  renameHistory(HistoryStorage storage, HistoryItem item) {
    String name = "";
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            content: TextField(
              decoration: InputDecoration(label: Text(localizations.name)),
              onChanged: (val) => name = val,
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context), child: Text(localizations.cancel)),
              TextButton(
                child: Text(localizations.save),
                onPressed: () {
                  if (name.isEmpty) {
                    FlutterToastr.show(localizations.historyEmptyName, context, position: 2);
                    return;
                  }
                  Navigator.of(context).pop();
                  setState(() {
                    item.name = name;
                    storage.refresh();
                  });
                },
              ),
            ],
          );
        });
  }

  //删除
  deleteHistory(HistoryStorage storage, int index) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(localizations.historyDeleteConfirm, style: const TextStyle(fontSize: 18)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(localizations.cancel)),
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
                    FlutterToastr.show(localizations.deleteSuccess, context);
                    Navigator.pop(context);
                  },
                  child: Text(localizations.delete)),
            ],
          );
        });
  }
}

class WriteTask extends EventListener {
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
  void onResponse(ChannelContext channelContext, HttpResponse response) {
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
