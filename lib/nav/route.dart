import 'package:go_router/go_router.dart';

import '../crud/customer/customer_list_screen.dart';
import '../crud/job/job_list_screen.dart';
import '../crud/supplier/supplier_list_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/system_integration_screen.dart';
import '../database/management/backup_providers/email/screen.dart';
import '../main.dart';
import '../screens/about.dart';
import '../screens/error.dart';
import '../screens/packing.dart';
import '../screens/shopping.dart';
import '../screens/wizard/wizard.dart';
import '../widgets/full_screen_photo_view.dart';
import 'home_with_drawer.dart';

GoRouter get router => GoRouter(
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final alt = firstRun ? '/system/wizard' : null;
            firstRun = false;
            return alt;
          },
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: JobListScreen()),
          routes: [
            GoRoute(
              path: 'error',
              builder: (context, state) {
                final errorMessage = state.extra as String? ?? 'Unknown Error';
                return ErrorScreen(errorMessage: errorMessage);
              },
            ),
            GoRoute(
              path: 'jobs',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: JobListScreen()),
            ),
            GoRoute(
              path: 'customers',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: CustomerListScreen()),
            ),
            GoRoute(
              path: 'suppliers',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SupplierListScreen()),
            ),
            GoRoute(
              path: 'shopping',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: ShoppingScreen()),
            ),
            GoRoute(
              path: 'packing',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: PackingScreen()),
            ),
            GoRoute(
              path: 'system/business',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SystemBusinessScreen()),
            ),
            GoRoute(
              path: 'system/billing',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SystemBillingScreen()),
            ),
            GoRoute(
              path: 'system/contact',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: SystemContactInformationScreen()),
            ),
            GoRoute(
              path: 'system/integration',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: SystemIntegrationScreen()),
            ),
            GoRoute(
              path: 'system/about',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: AboutScreen()),
            ),
            GoRoute(
              path: 'system/backup',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: BackupScreen(pathToBackup: '')),
            ),
            GoRoute(
              path: 'system/wizard',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: FirstRunWizard()),
            ),
            GoRoute(
              path: 'xero/auth_complete',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: AboutScreen()),
            ),
            GoRoute(
              path: 'photo_viewer',
              builder: (context, state) {
                final args = state.extra! as Map<String, String>;
                final imagePath = args['imagePath']!;
                final taskName = args['taskName']!;
                final comment = args['comment']!;
                return FullScreenPhotoViewer(
                    imagePath: imagePath, taskName: taskName, comment: comment);
              },
            ),
          ],
        ),
      ],
    );
