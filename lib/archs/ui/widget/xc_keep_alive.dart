import 'package:flutter/widgets.dart';

class LWKeepAlive extends StatefulWidget {
  LWKeepAlive({
    Key? key,
    this.keepAlive = true,
    this.borderRadius,
    required this.child,
  }) : super(key: key);
  final bool keepAlive;
  final Widget child;
  BorderRadiusGeometry? borderRadius;

  @override
  _LWKeepAliveState createState() => _LWKeepAliveState();
}

class _LWKeepAliveState extends State<LWKeepAlive>
    with AutomaticKeepAliveClientMixin<LWKeepAlive> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.borderRadius == null
        ? widget.child
        : ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: widget.child);
  }

  @override
  void didUpdateWidget(covariant LWKeepAlive oldWidget) {
    if (oldWidget.keepAlive != widget.keepAlive) {
      // keepAlive 状态需要更新，实现在 AutomaticKeepAliveClientMixin 中
      updateKeepAlive();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}
