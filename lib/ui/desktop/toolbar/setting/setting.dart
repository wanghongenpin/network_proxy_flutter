import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/util/system_proxy.dart';
import 'package:network_proxy/ui/component/multi_window.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/external_proxy.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'filter.dart';

///设置菜单
class Setting extends StatefulWidget {
  final ProxyServer proxyServer;

  const Setting({super.key, required this.proxyServer});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  late Configuration configuration;

  @override
  void initState() {
    configuration = widget.proxyServer.configuration;
    super.initState();
  }

  Widget item(String text, {VoidCallback? onPressed}) {
    return MenuItemButton(
        trailingIcon: const Icon(Icons.arrow_right),
        onPressed: onPressed,
        child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: Text(text, style: const TextStyle(fontSize: 14))));
  }

  @override
  Widget build(BuildContext context) {
    var surfaceTintColor =
        Brightness.dark == Theme.of(context).brightness ? null : Theme.of(context).colorScheme.background;
    return MenuAnchor(
      style: MenuStyle(surfaceTintColor: MaterialStatePropertyAll(surfaceTintColor)),
      builder: (context, controller, child) {
        return IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "设置",
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            });
      },
      menuChildren: [
        _ProxyMenu(proxyServer: widget.proxyServer),
        const ThemeSetting(),
        item("域名过滤", onPressed: hostFilter),
        item("请求重写", onPressed: requestRewrite),
        item("脚本", onPressed: () => openScriptWindow()),
        item("外部代理设置", onPressed: setExternalProxy),
        item("Github", onPressed: () => launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter"))),
      ],
    );
  }

  PopupMenuItem<String> menuItem(String title, {GestureTapCallback? onTap}) {
    return PopupMenuItem<String>(
        child: ListTile(
      title: Text(title),
      dense: true,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      trailing: const Icon(Icons.arrow_right),
      onTap: onTap,
    ));
  }

  ///设置外部代理地址
  setExternalProxy() {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return ExternalProxyDialog(configuration: widget.proxyServer.configuration);
        });
  }

  ///请求重写Dialog
  void requestRewrite() async {
    if (!mounted) return;
    openRequestRewriteWindow();
  }

  ///show域名过滤Dialog
  void hostFilter() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return FilterDialog(configuration: configuration);
      },
    );
  }
}

///代理菜单
class _ProxyMenu extends StatefulWidget {
  final ProxyServer proxyServer;

  const _ProxyMenu({required this.proxyServer});

  @override
  State<StatefulWidget> createState() => _ProxyMenuState();
}

class _ProxyMenuState extends State<_ProxyMenu> {
  var textEditingController = TextEditingController();

  late Configuration configuration;
  bool changed = false;

  @override
  void initState() {
    configuration = widget.proxyServer.configuration;
    textEditingController.text = configuration.proxyPassDomains;
    super.initState();
  }

  @override
  void dispose() {
    if (configuration.proxyPassDomains != textEditingController.text) {
      changed = true;
      configuration.proxyPassDomains = textEditingController.text;
      SystemProxy.setProxyPassDomains(configuration.proxyPassDomains);
    }

    if (changed) {
      configuration.flushConfig();
    }
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var surfaceTintColor =
        Brightness.dark == Theme.of(context).brightness ? null : Theme.of(context).colorScheme.background;

    return SubmenuButton(
      menuStyle: MenuStyle(
        surfaceTintColor: MaterialStatePropertyAll(surfaceTintColor),
        padding: const MaterialStatePropertyAll(EdgeInsets.only(top: 10, bottom: 10)),
      ),
      menuChildren: [
        PortWidget(proxyServer: widget.proxyServer, textStyle: const TextStyle(fontSize: 13)),
        const Divider(thickness: 0.3, height: 8),
        setSystemProxy(),
        const Divider(thickness: 0.3, height: 8),
        const SizedBox(height: 3),
        Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("代理忽略域名", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text("多个使用;分割", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              Padding(
                  padding: const EdgeInsets.only(left: 35),
                  child: TextButton(
                    child: const Text("重置"),
                    onPressed: () {
                      textEditingController.text = SystemProxy.proxyPassDomains;
                    },
                  ))
            ])),
        const SizedBox(height: 5),
        Padding(
            padding: const EdgeInsets.only(left: 15, right: 5),
            child: TextField(
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 13),
                controller: textEditingController,
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(10),
                    border: OutlineInputBorder(),
                    constraints: BoxConstraints(minWidth: 190, maxWidth: 190)),
                maxLines: 5,
                minLines: 1)),
        const SizedBox(height: 10),
      ],
      child: const Padding(padding: EdgeInsets.only(left: 10), child: Text("代理", style: TextStyle(fontSize: 14))),
    );
  }

  ///设置系统代理
  Widget setSystemProxy() {
    return SwitchListTile(
        hoverColor: Colors.transparent,
        title: const Text("设置为系统代理", maxLines: 1),
        dense: true,
        value: configuration.enableSystemProxy,
        onChanged: (val) {
          widget.proxyServer.setSystemProxyEnable(val);
          configuration.enableSystemProxy = val;
          setState(() {
            changed = true;
          });
        });
  }
}

class PortWidget extends StatefulWidget {
  final ProxyServer proxyServer;
  final TextStyle? textStyle;

  const PortWidget({super.key, required this.proxyServer, this.textStyle});

  @override
  State<StatefulWidget> createState() {
    return _PortState();
  }
}

class _PortState extends State<PortWidget> {
  final textController = TextEditingController();
  final FocusNode portFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    textController.text = widget.proxyServer.port.toString();
    portFocus.addListener(() async {
      //失去焦点
      if (!portFocus.hasFocus && textController.text != widget.proxyServer.port.toString()) {
        widget.proxyServer.configuration.port = int.parse(textController.text);

        if (widget.proxyServer.isRunning) {
          widget.proxyServer.restart().catchError(
              (e) => FlutterToastr.show("启动失败，请检查端口号${widget.proxyServer.port}是否被占用", context, duration: 3));
        }
        widget.proxyServer.configuration.flushConfig();
      }
    });
  }

  @override
  void dispose() {
    portFocus.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Padding(padding: EdgeInsets.only(left: 15)),
      Text("端口号：", style: widget.textStyle),
      SizedBox(
          width: 80,
          child: TextFormField(
            focusNode: portFocus,
            controller: textController,
            textAlign: TextAlign.center,
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(5),
              FilteringTextInputFormatter.allow(RegExp("[0-9]"))
            ],
            decoration: const InputDecoration(),
          ))
    ]);
  }
}
