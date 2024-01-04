import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

///高级重放
/// @author wang
class MobileCustomRepeat extends StatefulWidget {
  final Function onRepeat;

  const MobileCustomRepeat({super.key, required this.onRepeat});

  @override
  State<StatefulWidget> createState() => _CustomRepeatState();
}

class _CustomRepeatState extends State<MobileCustomRepeat> {
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

    return Scaffold(
        appBar: AppBar(
          title: Text(localizations.customRepeat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          actions: [
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
            )
          ],
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Form(
              key: formKey,
              child: ListBody(
                children: <Widget>[
                  field(localizations.repeatCount, count), //次数
                  const SizedBox(height: 6),
                  field(localizations.repeatInterval, interval), //间隔
                  const SizedBox(height: 6),
                  field(localizations.repeatDelay, delay), //延时
                ],
              ),
            )));
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
    Color color = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        SizedBox(width: 95, child: Text("$label :")),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                border: OutlineInputBorder(borderSide: BorderSide(width: 1, color: color.withOpacity(0.3))),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.5, color: color.withOpacity(0.5))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: color))),
            validator: (val) => val == null || val.isEmpty ? localizations.cannotBeEmpty : null,
          ),
        ),
      ],
    );
  }
}
