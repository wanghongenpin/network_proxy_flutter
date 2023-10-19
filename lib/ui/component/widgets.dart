import 'package:flutter/material.dart';
import 'package:network_proxy/utils/lang.dart';

class CustomPopupMenuItem<T> extends PopupMenuItem<T> {
  final Color? color;

  const CustomPopupMenuItem({
    super.key,
    super.onTap,
    super.height,
    T? value,
    bool enabled = true,
    required Widget child,
    this.color,
  }) : super(value: value, enabled: enabled, child: child);

  @override
  PopupMenuItemState<T, CustomPopupMenuItem<T>> createState() => _CustomPopupMenuItemState<T>();
}

class _CustomPopupMenuItemState<T> extends PopupMenuItemState<T, CustomPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Theme.of(context).focusColor,
      ),
      child: super.build(context),
    );
  }
}

class SwitchWidget extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final ValueWrap<bool> value;
  final ValueChanged<bool> onChanged;

  SwitchWidget({super.key, this.title, this.subtitle, required bool value, required this.onChanged})
      : value = ValueWrap.of(value);

  @override
  State<StatefulWidget> createState() => _SwitchState();
}

class _SwitchState extends State<SwitchWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.title == null) {
      return Switch(
        value: widget.value.get() == true,
        onChanged: (value) {
          setState(() {
            widget.value.set(value);
          });
          widget.onChanged(value);
        },
      );
    }
    return SwitchListTile(
      title: widget.title == null ? null : Text(widget.title!),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      value: widget.value.get() == true,
      dense: true,
      onChanged: (value) {
        setState(() {
          widget.value.set(value);
        });
        widget.onChanged(value);
      },
    );
  }
}
