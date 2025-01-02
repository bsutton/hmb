import 'package:go_router/go_router.dart';

import '../../database/management/backup_providers/google_drive/google_drive_backup_screen.dart';
import '../../database/management/backup_providers/local/local_backup_screen.dart';
import '../../main.dart';
import '../about.dart';
import '../crud/customer/list_customer_screen.dart';
import '../crud/job/esitmator/list_job_estimates_screen.dart';
import '../crud/job/list_job_screen.dart';
import '../crud/manufacturer/list_manufacturer_screen.dart';
import '../crud/message_template/list_message_template.dart';
import '../crud/milestone/list_milestone_screen.dart';
import '../crud/supplier/list_supplier_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/system_integration_screen.dart';
import '../crud/tool/list_tool_screen.dart';
import '../error.dart';
import '../invoicing/list_invoice_screen.dart';
import '../list_packing_screen.dart';
import '../list_shopping_screen.dart';
import '../quoting/list_quote_screen.dart';
import '../scheduling/schedule_page.dart';
import '../widgets/media/full_screen_photo_view.dart';
import '../wizard/system_wizard.dart';
import 'home_with_drawer.dart';

GoRouter get router => GoRouter(
      debugLogDiagnostics: true,
      routes: [
        // 1) Root route that redirects to either the Wizard or the Jobs screen
        GoRoute(
          path: '/',
          redirect: (context, state) {
            // If firstRun is true, route to /system/wizard
            // Else, go to /jobs
            // Then set firstRun=false to avoid repeating
            final alt = firstRun ? '/system/wizard' : '/jobs';
            firstRun = false;
            return alt;
          },
        ),

        // 2) Error screen route
        GoRoute(
          path: '/error',
          builder: (context, state) {
            final errorMessage = state.extra as String? ?? 'Unknown Error';
            return ErrorScreen(errorMessage: errorMessage);
          },
        ),

        // 3) Jobs route (replaces the old root builder).
        GoRoute(
          path: '/jobs',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: JobListScreen()),
        ),

        // 4) All other routes directly from the top level:
        GoRoute(
          path: '/customers',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: CustomerListScreen()),
        ),
        GoRoute(
          path: '/suppliers',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: SupplierListScreen()),
        ),
        GoRoute(
          path: '/shopping',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: ShoppingScreen()),
        ),
        GoRoute(
          path: '/packing',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: PackingScreen()),
        ),
        GoRoute(
          path: '/schedule',
          builder: (_, __) => HomeWithDrawer(
              initialScreen: SchedulePage(
            dialogMode: false,
          )),
        ),
        GoRoute(
          path: '/billing/quotes',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: QuoteListScreen()),
        ),
        GoRoute(
          path: '/billing/invoices',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: InvoiceListScreen()),
        ),
        GoRoute(
          path: '/billing/estimator',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: JobEstimatesListScreen()),
        ),
        GoRoute(
          path: '/billing/milestones',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: ListMilestoneScreen()),
        ),
        GoRoute(
          path: '/extras/tools',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: ToolListScreen()),
        ),
        GoRoute(
          path: '/extras/manufacturers',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: ManufacturerListScreen()),
        ),
        GoRoute(
          path: '/system/sms_templates',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: MessageTemplateListScreen()),
        ),
        GoRoute(
          path: '/system/business',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: SystemBusinessScreen()),
        ),
        GoRoute(
          path: '/system/billing',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: SystemBillingScreen()),
        ),
        GoRoute(
          path: '/system/contact',
          builder: (_, __) => const HomeWithDrawer(
              initialScreen: SystemContactInformationScreen()),
        ),
        GoRoute(
          path: '/system/integration',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: SystemIntegrationScreen()),
        ),
        GoRoute(
          path: '/system/about',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: AboutScreen()),
        ),
        GoRoute(
          path: '/system/backup/google',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: GoogleDriveBackupScreen()),
        ),
        GoRoute(
          path: '/system/backup/local',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: LocalBackupScreen()),
        ),
        GoRoute(
          path: '/system/wizard',
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: FirstRunWizard()),
        ),
        GoRoute(
          path: '/photo_viewer',
          builder: (context, state) {
            final args = state.extra! as Map<String, String>;
            final imagePath = args['imagePath']!;
            final taskName = args['taskName']!;
            final comment = args['comment']!;
            return FullScreenPhotoViewer(
              imagePath: imagePath,
              title: taskName,
              comment: comment,
            );
          },
        ),
      ],
    );
