import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../routes/app_routes.dart';

/// Purely a navigation choice. It never authenticates or grants either role.
class TeamEntryV17 extends StatelessWidget {
  const TeamEntryV17({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('دخول الإدارة والفريق')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 64,
                  color: Color(0xFFD4AF37)),
              const SizedBox(height: 18),
              const Text('اختر نوع حسابك', textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.adminLogin),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('دخول المالك (الأونر)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/staff-login'),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('دخول الموظفين — برقم العمل والكود'),
              ),
              const SizedBox(height: 12),
              const Text('دخول الموظف يتطلب رقمًا مسجلاً وفعالًا في إدارة الفريق وكود تحقق صالحًا. اختيار المسار وحده لا يعطي أي صلاحيات.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo')),
            ],
          ),
        ),
      ),
    ),
  );
}
