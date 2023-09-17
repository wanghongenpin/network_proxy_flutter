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
