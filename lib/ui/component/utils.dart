import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/http/http.dart';

IconData getIcon(HttpResponse? response) {
  var map = {
    ContentType.json: Icons.data_object,
    ContentType.html: Icons.html,
    ContentType.js: Icons.javascript,
    ContentType.image: Icons.image,
    ContentType.text: Icons.text_fields,
    ContentType.css: Icons.css,
    ContentType.font: Icons.font_download,
  };
  if (response == null) {
    return Icons.question_mark;
  }
  var contentType = response.contentType;
  return map[contentType] ?? Icons.http;
}

String copyRequest(HttpRequest request, HttpResponse? response) {
  var sb = StringBuffer();
  sb.writeln("请求内容Request");
  sb.writeln("${request.method.name} ${request.requestUrl} ${request.protocolVersion}");
  sb.writeln(request.headers.headerLines());
  sb.writeln();
  sb.writeln(request.bodyAsString);

  sb.writeln("--------------------------------------------------------");
  sb.writeln();
  sb.writeln("响应内容Response");
  sb.writeln("${response?.protocolVersion} ${response?.status.code}");
  sb.writeln(response?.headers.headerLines());
  sb.writeln(response?.bodyAsString);
  return sb.toString();
}

RelativeRect menuPosition(BuildContext context) {
  final RenderBox bar = context.findRenderObject() as RenderBox;
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  const Offset offset = Offset.zero;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromPoints(
      bar.localToGlobal(bar.size.centerRight(offset), ancestor: overlay),
      bar.localToGlobal(bar.size.centerRight(offset), ancestor: overlay),
    ),
    offset & overlay.size,
  );
  return position;
}

Widget contextMenu(BuildContext context, EditableTextState editableTextState) {
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        onPressed: () {
          editableTextState.copySelection(SelectionChangedCause.tap);
          FlutterToastr.show("已复制到剪切板", context);
          unSelect(editableTextState);
          editableTextState.hideToolbar();
        },
        type: ContextMenuButtonType.copy,
      ),
      ContextMenuButtonItem(
        label: 'Copy Value',
        onPressed: () {
          unSelect(editableTextState);
          Clipboard.setData(ClipboardData(text: editableTextState.textEditingValue.text)).then((value) {
            FlutterToastr.show("已复制到剪切板", context);
            editableTextState.hideToolbar();
          });
        },
        type: ContextMenuButtonType.custom,
      ),
      ContextMenuButtonItem(
        onPressed: () {
          editableTextState.selectAll(SelectionChangedCause.tap);
        },
        type: ContextMenuButtonType.selectAll,
      ),
    ],
  );
}

void unSelect(EditableTextState editableTextState) {
  editableTextState.userUpdateTextEditingValue(
    editableTextState.textEditingValue.copyWith(selection: const TextSelection(baseOffset: 0, extentOffset: 0)),
    SelectionChangedCause.tap,
  );
}
