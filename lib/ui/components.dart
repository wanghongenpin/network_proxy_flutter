import 'package:flutter/material.dart';

class ListURI extends StatefulWidget {
  final IconData? leading;
  final String text;
  final Color? color;
  final IconData trailing;

  const ListURI(
      {Key? key, this.leading, required this.text, this.color = Colors.green, this.trailing = Icons.chevron_right})
      : super(key: key);

  @override
  State<ListURI> createState() => _ListURIState();
}

class _ListURIState extends State<ListURI> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: Icon(widget.leading, size: 15, color: widget.color),
        title: Text(widget.text, overflow: TextOverflow.ellipsis, maxLines: 1),
        trailing: Icon(widget.trailing),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 50.0),
        onTap: () {});
  }
}

class RowURI extends StatefulWidget {
  final IconData? leading;
  final String text;
  final IconData trailing;

  const RowURI({Key? key, this.leading, required this.text, this.trailing = Icons.arrow_right}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _RowURIState();
  }
}

class _RowURIState extends State<RowURI> {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      TextButton.icon(
        icon: Icon(widget.leading, size: 16),
        onPressed: () {
          print("hello");
        },
        label: Text(widget.text, style: const TextStyle(color: Colors.black87)),
      ),
      const Positioned(right: 10, child: Icon(Icons.chevron_right))
    ]);
  }
}

class IconText extends StatefulWidget {
  const IconText({Key? key, this.leading, required this.text, this.color, this.trailing}) : super(key: key);

  final Widget? leading;
  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  State<IconText> createState() => _IconTextState();
}

class _IconTextState extends State<IconText> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        widget.leading ?? const SizedBox(),
        Text(widget.text),
        widget.trailing ?? const SizedBox(),
      ],
    );
  }
}
