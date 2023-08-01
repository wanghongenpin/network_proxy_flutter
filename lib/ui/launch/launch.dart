import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class SocketLaunch extends StatefulWidget {
  final ProxyServer proxyServer;
  final int size;
  final bool startup;
  final Function? onStart;
  final Function? onStop;

  const SocketLaunch(
      {super.key, required this.proxyServer, this.size = 25, this.onStart, this.onStop, this.startup = true});

  @override
  State<StatefulWidget> createState() {
    return _SocketLaunchState();
  }
}

class _SocketLaunchState extends State<SocketLaunch> with WindowListener, WidgetsBindingObserver {
  bool started = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    //启动代理服务器
    if (widget.startup) {
      start();
    }
    if (Platforms.isDesktop()) {
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await widget.proxyServer.stop();
    print("onWindowClose");
    started = false;
    windowManager.destroy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      print('AppLifecycleState.detached');
      widget.onStop?.call();
      widget.proxyServer.stop();
      started = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        tooltip: started ? "停止" : "启动",
        icon: Icon(started ? Icons.stop : Icons.play_arrow_sharp,
            color: started ? Colors.red : Colors.green, size: widget.size.toDouble()),
        onPressed: () async {
          if (started) {
            widget.proxyServer.stop().then((value) {
              widget.onStop?.call();
              setState(() {
                started = !started;
              });
            });
          } else {
            start();
          }
        });
  }

  start() {
    widget.proxyServer.start().then((value) {
      setState(() {
        started = true;
      });
      widget.onStart?.call();
    }).catchError((e) {
      FlutterToastr.show("启动失败，请检查端口号${widget.proxyServer.port}是否被占用", context, duration: 3);
    });
  }
}
