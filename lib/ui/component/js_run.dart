import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/javascript_runtime.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

class JavaScript extends StatefulWidget {
  const JavaScript({super.key});

  @override
  State<StatefulWidget> createState() {
    return _JavaScriptState();
  }
}

class _JavaScriptState extends State<JavaScript> {
  static JavascriptRuntime flutterJs = getJavascriptRuntime();

  late CodeController code;

  List<Text> outLines = [];

  @override
  void initState() {
    super.initState();

    // register channel callback
    final channelCallbacks = JavascriptRuntime.channelFunctionsRegistered[flutterJs.getEngineInstanceId()];
    channelCallbacks!["ConsoleLog"] = consoleLog;

    code = CodeController(language: javascript, text: 'console.log("Hello, World!")');
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  dynamic consoleLog(dynamic args) async {
    print(args);
    var level = args.removeAt(0);
    String output = args.join(' ');
    if (level == 'info') level = 'warn';
    outLines.add(Text(output, style: TextStyle(color: level == 'error' ? Colors.red : Colors.white, fontSize: 13)));
    setState(() {
      print(outLines);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("JavaScript", style: TextStyle(fontSize: 16)), centerTitle: true),
        resizeToAvoidBottomInset: false,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              //选择文件
              ElevatedButton.icon(
                  onPressed: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['js']);
                    if (result != null) {
                      File file = File(result.files.single.path!);
                      String content = await file.readAsString();
                      code.text = content;
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.file_download_sharp),
                  label: const Text("File")),
              const SizedBox(width: 15),
              FilledButton.icon(
                  onPressed: () async {
                    outLines.clear();
                    //失去焦点
                    FocusScope.of(context).requestFocus(FocusNode());
                    var jsResult = await flutterJs.evaluateAsync(code.text);
                    if (jsResult.isPromise || jsResult.rawResult is Future) {
                      jsResult = await flutterJs.handlePromise(jsResult);
                    }

                    if (jsResult.isError) {
                      outLines.add(Text(jsResult.toString(), style: const TextStyle(color: Colors.red, fontSize: 13)));
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Run")),
              const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
              height: 320,
              child: CodeTheme(
                  data: CodeThemeData(styles: monokaiSublimeTheme),
                  child: SingleChildScrollView(
                      child: CodeField(
                    minLines: 16,
                    textStyle: const TextStyle(fontSize: 12),
                    controller: code,
                    gutterStyle: const GutterStyle(width: 50, margin: 0),
                  )))),
          const SizedBox(height: 10),
          TextButton(onPressed: () {}, child: const Text("Output:", style: TextStyle(fontSize: 16))),
          Expanded(
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.black,
                  child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: outLines)))),
        ]));
  }
}
