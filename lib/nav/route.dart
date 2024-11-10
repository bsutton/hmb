import 'package:go_router/go_router.dart';

import '../crud/customer/list_customer_screen.dart';
import '../crud/job/list_job_screen.dart';
import '../crud/manufacturer/list_manufacturer_screen.dart';
import '../crud/message_template/list_message_template.dart';
import '../crud/supplier/list_supplier_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/system_integration_screen.dart';
import '../crud/tool/list_tool_screen.dart';
import '../database/management/backup_providers/email/screen.dart';
import '../main.dart';
import '../screens/about.dart';
import '../screens/error.dart';
import '../screens/list_packing_screen.dart';
import '../screens/list_shopping_screen.dart';
import '../screens/wizard/wizard.dart';
import '../widgets/media/full_screen_photo_view.dart';
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
                path: 'extras/tools',
                builder: (_, __) => const HomeWithDrawer(
                      initialScreen: ToolListScreen(),
                    )),
            GoRoute(
                path: 'extras/manufacturers',
                builder: (_, __) => const HomeWithDrawer(
                      initialScreen: ManufacturerListScreen(),
                    )),
            GoRoute(
              path: 'system/sms_templates',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: MessageTemplateListScreen()),
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
              path: 'photo_viewer',
              builder: (context, state) {
                final args = state.extra! as Map<String, String>;
                final imagePath = args['imagePath']!;
                final taskName = args['taskName']!;
                final comment = args['comment']!;
                return FullScreenPhotoViewer(
                    imagePath: imagePath, title: taskName, comment: comment);
              },
            ),
          ],
        ),
      ],
    );
