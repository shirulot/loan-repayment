import 'package:flutter/material.dart';

/// Bottom navigation for the three mobile loan surfaces.
class LoanPlanMobileNavigationBar extends StatelessWidget {
  const LoanPlanMobileNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.calendarUnreadCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int? calendarUnreadCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 70,
        backgroundColor: colors.surfaceContainerLowest,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return Theme.of(context).textTheme.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: '还款计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '计算器',
          ),
          if (calendarUnreadCount case final unreadCount?)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                smallSize: 8,
                child: const Icon(Icons.calendar_month_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadCount > 0,
                smallSize: 8,
                child: const Icon(Icons.calendar_month),
              ),
              label: '日历',
            ),
        ],
      ),
    );
  }
}
