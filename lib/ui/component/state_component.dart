import 'package:flutter/material.dart';

class StateComponent extends StatefulWidget {
  final Widget child;
  final Function? onChange;

  const StateComponent(this.child, {Key? key, this.onChange }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _StateComponentState();
  }
}

class _StateComponentState extends State<StateComponent> {
  void changeState() {
    setState(() {});
    if (widget.onChange != null) {
      widget.onChange!();
    }
  }
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
