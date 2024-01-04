import 'dart:async';

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
  TextEditingController delay = TextEditingController(text: '0');

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
            field(localizations.repeatInterval, interval), //间隔
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
            Future.delayed(Duration(milliseconds: int.parse(delay.text)),
                () => submitTask(int.parse(count.text), int.parse(interval.text)));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  //定时重放
  submitTask(int counter, var interval) {
    if (counter <= 0) {
      return;
    }
    Future.delayed(Duration(milliseconds: interval), () {
      widget.onRepeat.call();
      if (counter - 1 > 0) {
        submitTask(counter - 1, interval);
      }
    });
  }

  Widget field(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(),
            validator: (val) => val == null || val.isEmpty ? localizations.cannotBeEmpty : null,
          ),
        ),
      ],
    );
  }
}
