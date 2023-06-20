import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/panel.dart';
import 'package:network_proxy/utils/lang.dart';

///请求 URI
class PathRow extends StatefulWidget {
  final Color? color;
  final HttpRequest request;
  final ValueWrap<HttpResponse> response = ValueWrap();

  final NetworkTabController panel;

  PathRow(this.request, this.panel, {Key? key, this.color = Colors.green}) : super(key: GlobalKey<_PathRowState>());

  @override
  State<PathRow> createState() => _PathRowState();

  void add(HttpResponse response) {
    this.response.set(response);
    var state = key as GlobalKey<_PathRowState>;
    state.currentState?.changeState();
  }
}

class _PathRowState extends State<PathRow> {
  static _PathRowState? selectedState;

  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var request = widget.request;
    var response = widget.response.get();
    var title = '${request.method.name} ${Uri.parse(request.uri).path}';
    var time = formatDate(request.requestTime, [HH, ':', nn, ':', ss]);
    return ListTile(
        leading: Icon(getIcon(), size: 16, color: widget.color),
        title: Text(title, overflow: TextOverflow.ellipsis, maxLines: 1),
        subtitle: Text(
            '$time - [${response?.status.code ?? ''}]  ${response?.contentType.name.toUpperCase() ?? ''} ${response?.costTime() ?? ''} '),
        selected: selected,
        // trailing: const Icon(Icons.chevron_right),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
        onTap: onClick);
  }

  void changeState() {
    setState(() {});
  }

  void onClick() {
    if (selected) {
      return;
    }
    setState(() {
      selected = true;
    });
    if (selectedState?.mounted == true && selectedState != this) {
      selectedState?.setState(() {
        selectedState?.selected = false;
      });
    }
    selectedState = this;
    widget.panel.change(widget.request, widget.response.get());
  }

  IconData getIcon() {
    var map = {
      ContentType.json: Icons.data_object,
      ContentType.html: Icons.html,
      ContentType.js: Icons.javascript,
      ContentType.image: Icons.image,
      ContentType.text: Icons.text_fields,
      ContentType.css: Icons.css,
      ContentType.font: Icons.font_download,
    };
    if (widget.response.isNull()) {
      return Icons.http;
    }
    var contentType = widget.response.get()?.contentType;
    return map[contentType] ?? Icons.http;
  }
}
