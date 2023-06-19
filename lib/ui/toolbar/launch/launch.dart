import 'package:flutter/material.dart';
import 'package:network/network/bin/server.dart';
import 'package:network/network/channel.dart';
import 'package:window_manager/window_manager.dart';

class SocketLaunch extends StatefulWidget {
  final ProxyServer proxyServer;

  const SocketLaunch({super.key, required this.proxyServer});

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
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    started = false;
    widget.proxyServer.stop();
    setState(() {});
  }

  @override
  void onWindowClose() {
    started = false;
    widget.proxyServer.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        tooltip: started ? "停止" : "启动",
        icon: Icon(
          started ? Icons.stop : Icons.play_arrow_sharp,
          color: started ? Colors.red : Colors.green,
          size: 25,
        ),
        onPressed: () async {
          Future<Server?> result = started ? widget.proxyServer.stop() : widget.proxyServer.start();
          result.then((value) => setState(() {
                started = !started;
              }));
        });
  }
}
