import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'mobile_dashboard_layout.dart';
import 'web/web_dashboard_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (kIsWeb && constraints.maxWidth > 800) {
          return const WebDashboardLayout();
        }
        return const MobileDashboardLayout();
      },
    );
  }
}
