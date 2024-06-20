import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

///高级重放
/// @author wang
class CustomRepeatDialog extends StatefulWidget {
  final Function onRepeat;

  const CustomRepeatDialog({super.key, required this.onRepeat});

  @override
  State<StatefulWidget> createState() => _CustomRepeatState();
}

class _CustomRepeatState extends State<CustomRepeatDialog> {
  TextEditingController count = TextEditingController(text: '1');
  TextEditingController interval = TextEditingController(text: '0');
  TextEditingController minInterval = TextEditingController(text: '0');
  TextEditingController maxInterval = TextEditingController(text: '1000');
  TextEditingController delay = TextEditingController(text: '0');

  bool fixed = true;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    count.dispose();
    interval.dispose();
    delay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return AlertDialog(
      title: Text(localizations.customRepeat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      content: SingleChildScrollView(
          child: Form(
        key: formKey,
        child: ListBody(
          children: <Widget>[
            field(localizations.repeatCount, count), //次数
            Row( //间隔
              children: [
                SizedBox(width: 75, child: Text(localizations.repeatInterval)),
                const SizedBox(height: 5),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  //Checkbox样式 固定和随机
                  Row(children: [
                    SizedBox(
                        width: 78,
                        height: 35,
                        child: Transform.scale(
                            scale: 0.83,
                            child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("${localizations.fixed}:"),
                                value: fixed,
                                dense: true,
                                onChanged: (val) {
                                  setState(() {
                                    fixed = true;
                                  });
                                }))),
                    SizedBox(width: 152, height: 32, child: textField(interval, style: const TextStyle(fontSize: 13))),
                  ]),
                  Row(children: [
                    SizedBox(
                        width: 78,
                        height: 35,
                        child: Transform.scale(
                            scale: 0.83,
                            child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("${localizations.random}:"),
                                value: !fixed,
                                dense: true,
                                onChanged: (val) {
                                  setState(() {
                                    fixed = false;
                                  });
                                }))),
                    SizedBox(
                        width: 65, height: 32, child: textField(minInterval, style: const TextStyle(fontSize: 13))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Text("-")),
                    SizedBox(
                        width: 70, height: 32, child: textField(maxInterval, style: const TextStyle(fontSize: 13))),
                  ]),
                ]),
              ],
            ),
            const SizedBox(height: 5),
            field(localizations.repeatDelay, delay), //延时
          ],
        ),
      )),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(localizations.done),
          onPressed: () {
            if (!formKey.currentState!.validate()) {
              return;
            }

            //定时发起请求
            Future.delayed(Duration(milliseconds: int.parse(delay.text)), () => submitTask(int.parse(count.text)));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  //定时重放
  submitTask(int counter) {
    if (counter <= 0) {
      return;
    }
    widget.onRepeat.call();

    int intervalValue = int.parse(interval.text);
    //随机
    if (!fixed) {
      int min = int.parse(minInterval.text);
      int max = int.parse(maxInterval.text);
      intervalValue = Random().nextInt(max - min) + min;
    }

    Future.delayed(Duration(milliseconds: intervalValue), () {
      if (counter - 1 > 0) {
        submitTask(counter - 1);
      }
    });
  }

  Widget field(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(child: textField(controller)),
      ],
    );
  }

  FormField textField(TextEditingController? controller, {TextStyle? style}) {
    Color color = Theme.of(context).colorScheme.primary;

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: style,
      decoration: InputDecoration(
          errorStyle: const TextStyle(height: 2, fontSize: 0),
          contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
          border: OutlineInputBorder(borderSide: BorderSide(width: 1, color: color.withOpacity(0.3))),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.5, color: color.withOpacity(0.5))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: color))),
      validator: (val) => val == null || val.isEmpty ? localizations.cannotBeEmpty : null,
    );
  }
}
