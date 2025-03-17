import 'dart:async';

import 'package:flutter/material.dart';

/// 点击事件
class LWClick {
  LWClick._();

  tt() {
    DecoratedBox(
      decoration: BoxDecoration(color: Colors.amber),
    );
  }

  /// params:
  ///   - callback 外部回调
  ///   - antiMilliseconds 可重复点击的时间间隔
  static VoidCallback? onClickAnti(
      {VoidCallback? onTap, int antiMilliseconds = 300}) {
    if (onTap == null) return null;
    Timer? _timer;
    return () {
      _timer = Timer(Duration(milliseconds: antiMilliseconds), () {
        _timer?.cancel();
        _timer = null;
      });
      onTap.call();
    };
  }

  /// params:
  ///   - callback 外部回调
  ///   - child 子Widget
  static Widget onClick({VoidCallback? onTap, Widget? child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
