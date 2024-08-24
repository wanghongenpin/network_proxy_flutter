import 'package:flutter/material.dart';

///悬浮小窗口
class FloatingWindowManager {
  static final FloatingWindowManager _instance = FloatingWindowManager._();

  factory FloatingWindowManager() => _instance;

  FloatingWindowManager._();

  ///浮窗
  OverlayEntry? overlayEntry;

  bool get isShow => overlayEntry != null;

  void show(BuildContext context, {required Widget widget}) {
    if (overlayEntry == null) {
      // var floatingWindow = FloatingWindow(top: 160, left: 210, child: Material(child: child));
      overlayEntry = OverlayEntry(builder: (BuildContext context) {
        return widget;
      });
      Overlay.of(context).insert(overlayEntry!);
    }
  }

  ///关闭小窗
  void hide() {
    overlayEntry?.remove();
    overlayEntry = null;
  }
}

class FloatingWindow extends StatefulWidget {
  final Widget child;
  final double top;
  final double right;

  const FloatingWindow({
    super.key,
    required this.child,
    required this.top,
    required this.right,
  });

  @override
  State<FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<FloatingWindow> with TickerProviderStateMixin {
  double right = 0;
  double top = 0;

  double maxX = 0;
  double maxY = 0;

  var parentKey = GlobalKey();
  var childKey = GlobalKey();

  var parentSize = const Size(0, 0);
  var childSize = const Size(0, 0);

  void changeState() {
    setState(() {});
  }

  @override
  void initState() {
    right = widget.right;
    top = widget.top;
    WidgetsBinding.instance.addPostFrameCallback((d) {
      parentSize = getWidgetSize(parentKey);
      childSize = getWidgetSize(childKey);
      maxX = parentSize.width - childSize.width;
      maxY = parentSize.height - childSize.height;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: parentKey,
      fit: StackFit.expand,
      children: [
        Positioned(
          key: childKey,
          right: right,
          top: top,
          child: GestureDetector(
            onPanUpdate: (d) {
              var delta = d.delta;
              right -= delta.dx;
              top += delta.dy;
              setState(() {});
            },
            onPanEnd: (d) {
              right = getValue(right, maxX);
              top = getValue(top, maxY);
            },
            child: widget.child,
          ),
        )
      ],
    );
  }

  ///限制边界
  double getValue(double value, double max) {
    if (value < 0) {
      return 0;
    } else if (value > max) {
      return max;
    } else {
      return value;
    }
  }

  Size getWidgetSize(GlobalKey key) {
    final RenderBox renderBox = key.currentContext?.findRenderObject() as RenderBox;
    return renderBox.size;
  }
}
