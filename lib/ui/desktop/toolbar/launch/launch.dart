import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:window_manager/window_manager.dart';

class SocketLaunch extends StatefulWidget {
  final ProxyServer proxyServer;
  final int size;
  final Function? onStart;
  final Function? onStop;

  const SocketLaunch({super.key, required this.proxyServer, this.size = 25, this.onStart, this.onStop});

  @override
  State<StatefulWidget> createState() {
    return _SocketLaunchState();
  }
}

class _SocketLaunchState extends State<SocketLaunch> with WindowListener {
  bool started = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    widget.proxyServer.start();
    widget.onStart?.call();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    print("onWindowClose");
    await widget.proxyServer.stop();
    started = false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        tooltip: started ? "停止" : "启动",
        icon: Icon(started ? Icons.stop : Icons.play_arrow_sharp,
            color: started ? Colors.red : Colors.green, size: widget.size.toDouble()),
        onPressed: () async {
          Future<Server?> result = started ? widget.proxyServer.stop() : widget.proxyServer.start();
          if (started) {
            widget.onStop?.call();
          } else {
            widget.onStart?.call();
          }
          result.then((value) => setState(() {
                started = !started;
              }));
        });
  }
}
