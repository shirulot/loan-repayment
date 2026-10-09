import 'package:flutter/widgets.dart';

/// 按实际可用宽度适配手机横屏和可调整大小的桌面窗口。
abstract final class LoanPlanLayoutStyle {
  // 844 宽手机扣除横屏安全区后仍可并排，半栏保留可读的表单宽度。
  static const twoColumnMinWidth = 720.0;
  static const maxCompactWidth = 640.0;
  static const planSidebarMinWidth = 1100.0;
  static const maxHomeWidth = 1200.0;
  static const parameterWidth = 320.0;
  static const gap = 16.0;
  static const panelPadding = EdgeInsets.fromLTRB(16, 8, 16, 16);
}
