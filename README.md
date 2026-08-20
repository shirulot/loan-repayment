# 提前还贷计算器（Flutter 多端应用）

这是一个本地运行的 Flutter 应用，目标平台为 Android、macOS 和 Windows。应用不依赖业务服务器，计划数据默认保存在本机；Android 会按系统备份设置保留计划状态。

## 已实现功能

- 按当前模型生成商贷、公积金和合计还款计划。
- 表格同时保留商贷月供、公积金月供、本月月供总额、商贷减少额、公积金减少额和总减少额。
- 在“实际提前还款”列直接录入真实扣款金额；从该月份开始，后续余额、正常月供、减少额和预期提前还款自动补正。
- 计划不预设每月家庭支援和额外支援；实际金额在对应月份直接录入。
- 当前月默认使用实际提前还款 17500 校准商贷余额；下个月商贷月供使用账单校准值（本金 1789.55、利息 986.24）。
- 当前月、下个月和下下个月优先使用三组“近期期望还款额”；对应金额留空或为 0 时，会回退使用可供提前还贷额。第四个月起的预期提前还款也直接按可供提前还贷额计算；因为月供会下降，金额会自动递增，并向上取整到十元。
- 计划从打开应用时的当前月开始计算，持续到余额实际清零；如果实际提前还款使余额提前清零，后续月份会自动移除。
- 每月现金流支持记录“本月收入”“额外收入”和“每月生活费”，自动显示正值“当月月供”和“可供提前还贷额”（本月收入 - 当月月供 - 每月生活费 + 额外收入）。
- 支持导出 Excel 兼容 `.xls`、CSV 和 JSON。导出文件位于应用 Documents 目录下的 `loan-repayment-plans` 文件夹。
- 参数和实际提前还款会缓存到同一目录；应用启动时自动读取最近一次缓存。
- 可填写贷款开始日期和总年限，应用会结合当前月份自动计算剩余期数；未填写时兼容使用原有剩余期数。
- Android 已配置 Auto Backup 和设备迁移规则；删除后重装能否恢复取决于系统备份或设备迁移是否可用，不需要额外存储权限。
- 主页面只显示计划概览，点击“查看详情”进入横屏友好的紧凑还款明细表。

## 运行

在项目目录执行：

```bash
flutter pub get
flutter run -d macos
flutter run -d windows
flutter run -d <Android设备ID>
```

可以用下面的命令查看设备 ID：

```bash
flutter devices
```

## 构建安装包

```bash
flutter build apk --release
flutter build macos --release
flutter build windows --release
```

Windows 构建需要在 Windows 环境执行；macOS 构建需要在 macOS 环境执行。Android 手机上可安装 `build/app/outputs/flutter-apk/app-release.apk`。

本项目目录中也附带了本机已构建的安装包；Windows 版本请在 Windows 电脑上执行上面的构建命令生成。

## 校验

```bash
flutter analyze
flutter test
```

核心计算代码位于 `lib/domain/services/loan_calculator.dart`，页面和参数编辑位于 `lib/ui/features/loan/views/loan_plan_page.dart`，还款明细位于 `lib/ui/features/loan/views/loan_plan_detail_page.dart`，导出逻辑位于 `lib/data/services/loan_export_service.dart`，缓存逻辑位于 `lib/data/services/loan_cache_service.dart`。
