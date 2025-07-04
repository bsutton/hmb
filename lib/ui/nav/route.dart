/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../database/management/backup_providers/google_drive/google_drive_backup_screen.dart';
import '../../database/management/backup_providers/local/local_backup_screen.dart';
import '../about.dart';
import '../crud/customer/list_customer_screen.dart';
import '../crud/job/esitmator/list_job_estimates_screen.dart';
import '../crud/job/list_job_screen.dart';
import '../crud/manufacturer/list_manufacturer_screen.dart';
import '../crud/message_template/list_message_template.dart';
import '../crud/milestone/list_milestone_screen.dart';
import '../crud/receipt/list_receipt_screen.dart';
import '../crud/supplier/list_supplier_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/system_integration_screen.dart';
import '../crud/tool/list_tool_screen.dart';
import '../error.dart';
import '../invoicing/list_invoice_screen.dart';
import '../invoicing/yet_to_be_invoice.dart';
import '../quoting/list_quote_screen.dart';
import '../scheduling/schedule_page.dart';
import '../task_items/list_packing_screen.dart';
import '../task_items/list_shopping_screen.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/full_screen_photo_view.dart';
import '../wizard/setup_wizard.dart';
import 'nav.g.dart';
import 'splash_router.dart';

GoRouter createGoRouter(GlobalKey<NavigatorState> navigatorKey) => GoRouter(
  navigatorKey: navigatorKey,
  observers: [routeObserver], // so we can refresh the dashboard when
  // we pop back to it.
  debugLogDiagnostics: true,
  onException: (context, state, router) {
    HMBToast.error('Route Error: ${state.error}');
  },
  redirect: (context, state) {
    // If the deep link is the Xero OAuth callback, do not change the current route.
    if (state.matchedLocation == '/xero/auth_complete') {
      // Return the current location so that no navigation occurs
      // as we are directly handling the intent in the xero auth code.
      return state.uri.toString();
    }

    // No other redirection.
    return null;
  },
  routes: [
    // '/' is used on startup and for deeplinking
    GoRoute(path: '/', builder: (context, state) => const SplashRouter()),

    // 2) Error screen route
    GoRoute(
      path: '/error',
      builder: (context, state) {
        final errorMessage = state.extra as String? ?? 'Unknown Error';
        return ErrorScreen(errorMessage: errorMessage);
      },
    ),

    // This where the user lands after we finish initialising.
    GoRoute(
      path: '/dashboard',
      builder: (_, _) => const HomeScaffold(initialScreen: MainDashboardPage()),
    ),

    GoRoute(
      path: '/dashboard/accounting',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: AccountingDashboardPage()),
    ),
    GoRoute(
      path: '/dashboard/settings',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SettingsDashboardPage()),
    ),
    GoRoute(
      path: '/dashboard/help',
      builder: (_, _) => const HomeScaffold(initialScreen: HelpDashboardPage()),
    ),
    // 3) Jobs route (replaces the old root builder).
    GoRoute(
      path: '/jobs',
      builder: (_, _) => const HomeScaffold(initialScreen: JobListScreen()),
    ),

    // 4) All other routes directly from the top level:
    GoRoute(
      path: '/customers',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: CustomerListScreen()),
    ),
    GoRoute(
      path: '/suppliers',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SupplierListScreen()),
    ),
    GoRoute(
      path: '/shopping',
      builder: (_, _) => const HomeScaffold(initialScreen: ShoppingScreen()),
    ),
    GoRoute(
      path: '/packing',
      builder: (_, _) => const HomeScaffold(initialScreen: PackingScreen()),
    ),
    GoRoute(
      path: '/schedule',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SchedulePage(dialogMode: false)),
    ),
    GoRoute(
      path: '/accounting/quotes',
      builder: (_, _) => const HomeScaffold(initialScreen: QuoteListScreen()),
    ),
    GoRoute(
      path: '/accounting/invoices',
      builder: (_, _) => const HomeScaffold(initialScreen: InvoiceListScreen()),
    ),

    GoRoute(
      path: '/accounting/to_be_invoiced',
      builder: (_, _) => HomeScaffold(initialScreen: YetToBeInvoicedScreen()),
    ),
    GoRoute(
      path: '/accounting/estimator',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: JobEstimatesListScreen()),
    ),
    GoRoute(
      path: '/accounting/milestones',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: ListMilestoneScreen()),
    ),
    GoRoute(
      path: '/accounting/receipts',
      builder: (_, _) => const HomeScaffold(initialScreen: ReceiptListScreen()),
    ),
    GoRoute(
      path: '/extras/tools',
      builder: (_, _) => const HomeScaffold(initialScreen: ToolListScreen()),
    ),
    GoRoute(
      path: '/extras/manufacturers',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: ManufacturerListScreen()),
    ),
    GoRoute(
      path: '/system/sms_templates',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: MessageTemplateListScreen()),
    ),
    GoRoute(
      path: '/system/business',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SystemBusinessScreen()),
    ),
    GoRoute(
      path: '/system/billing',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SystemBillingScreen()),
    ),
    GoRoute(
      path: '/system/contact',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SystemContactInformationScreen()),
    ),
    GoRoute(
      path: '/system/integration',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: SystemIntegrationScreen()),
    ),
    GoRoute(
      path: '/system/about',
      builder: (_, _) => const HomeScaffold(initialScreen: AboutScreen()),
    ),
    GoRoute(
      path: '/system/backup/google',
      builder: (_, _) =>
          const HomeScaffold(initialScreen: GoogleDriveBackupScreen()),
    ),
    GoRoute(
      path: '/system/backup/google/restore',
      builder: (_, _) => const HomeScaffold(
        initialScreen: GoogleDriveBackupScreen(restoreOnly: true),
      ),
    ),
    GoRoute(
      path: '/system/backup/local',
      builder: (_, _) => const HomeScaffold(initialScreen: LocalBackupScreen()),
    ),

    GoRoute(
      path: '/system/wizard',
      builder: (context, state) {
        final fromSettings = state.extra as bool? ?? false;
        return HomeScaffold(
          initialScreen: SetupWizard(launchedFromSettings: fromSettings),
        );
      },
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
    // GoRoute(path: '/testpdf', builder: (context, state) => const TestPdfZoom()),
  ],
);

/// A global RouteObserver that you can attach to GoRouter
final routeObserver = RouteObserver<ModalRoute<void>>();
