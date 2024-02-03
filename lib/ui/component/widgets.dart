import 'package:flutter/material.dart';
import 'package:network_proxy/utils/lang.dart';

class CustomPopupMenuItem<T> extends PopupMenuItem<T> {
  final Color? color;

  const CustomPopupMenuItem({
    super.key,
    super.onTap,
    super.height,
    super.value,
    super.enabled,
    required Widget super.child,
    this.color,
  });

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
  final double scale;

  SwitchWidget({super.key, this.title, this.subtitle, required bool value, required this.onChanged, this.scale = 1})
      : value = ValueWrap.of(value);

  @override
  State<StatefulWidget> createState() => _SwitchState();
}

class _SwitchState extends State<SwitchWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.title == null) {
      return Transform.scale(
          scale: widget.scale,
          child: Switch(
            value: widget.value.get() == true,
            onChanged: (value) {
              setState(() {
                widget.value.set(value);
              });
              widget.onChanged(value);
            },
          ));
    }
    return Transform.scale(
        scale: widget.scale,
        child: SwitchListTile(
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
        ));
  }
}

class Dot extends StatelessWidget {
  final Color? color;
  final double size;

  const Dot({super.key, this.color = const Color(0xFF00FF00), this.size = 5});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class BottomSheetItem extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const BottomSheetItem({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onPressed?.call();
        },
        child: SizedBox(width: double.infinity, child: Text(text, textAlign: TextAlign.center)));
  }
}

class IconText extends StatelessWidget {
  final GestureTapCallback? onTap;
  final Icon? icon;
  final Widget? trailing;
  final String text;
  final TextStyle? textStyle;

  const IconText({super.key, this.onTap, required this.text, this.icon, this.trailing, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: Row(children: [
          if (icon != null) icon!,
          if (icon != null) const SizedBox(width: 8),
          Expanded(child: Text(text, style: textStyle)),
          if (trailing != null) trailing!
        ]));
  }
}
