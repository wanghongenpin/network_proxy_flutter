import 'package:flutter/material.dart';

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
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchWidget({super.key, this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  State<StatefulWidget> createState() => _SwitchState();
}

class _SwitchState extends State<SwitchWidget> {
  bool value = false;

  @override
  void initState() {
    super.initState();
    value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.title == null) {
      return Switch(
        value: value,
        onChanged: (value) {
          setState(() {
            this.value = value;
          });
          widget.onChanged(value);
        },
      );
    }
    return SwitchListTile(
      title: widget.title == null ? null : Text(widget.title!),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      value: value,
      dense: true,
      onChanged: (value) {
        setState(() {
          this.value = value;
        });
        widget.onChanged(value);
      },
    );
  }
}
