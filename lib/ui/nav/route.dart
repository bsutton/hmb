/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../database/management/backup_providers/google_drive/google_drive_backup_screen.dart';
import '../../database/management/backup_providers/local/local_backup_screen.dart';
import '../../util/flutter/flutter_types.dart';
import '../about.dart';
import '../crud/customer/list_customer_screen.dart';
import '../crud/job/estimator/list_job_estimates_screen.dart';
import '../crud/job/list_job_screen.dart';
import '../crud/manufacturer/list_manufacturer_screen.dart';
import '../crud/message_template/list_message_template.dart';
import '../crud/milestone/list_milestone_screen.dart';
import '../crud/receipt/list_receipt_screen.dart';
import '../crud/supplier/list_supplier_screen.dart';
import '../crud/system/chatgpt_integration_screen.dart';
import '../crud/system/ihserver_integration_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/xero_integration_screen.dart';
import '../crud/todo/list_todo_screen.dart';
import '../crud/tool/list_tool_screen.dart';
import '../error.dart';
import '../integrations/booking_request_list_screen.dart';
import '../invoicing/list_invoice_screen.dart';
import '../invoicing/yet_to_be_invoice.dart';
import '../quoting/list_quote_screen.dart';
import '../scheduling/schedule_page.dart';
import '../scheduling/today/today_page.dart';
import '../task_items/list_packing_screen.dart';
import '../task_items/list_shopping_screen.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/full_screen_photo_view.dart';
import '../widgets/splash_screen.dart';
import '../wizard/setup_wizard.dart';
import 'dashboards/accounting/accounting_dashboard.dart';
import 'dashboards/backup/backup_dashboard.dart';
import 'dashboards/help/help_dashboard.dart';
import 'dashboards/integration/integration_dashboard.dart';
import 'dashboards/main/home_dashboard.dart';
import 'dashboards/settings/settings_dashboard.dart';
import 'nav.g.dart';

GoRouter createGoRouter(
  GlobalKey<NavigatorState> navigatorKey,
  AsyncContextCallback bootstrap,
) => GoRouter(
  navigatorKey: navigatorKey,
  observers: [routeObserver], // so we can refresh the dashboard when
  // we pop back to it.
  debugLogDiagnostics: true,
  onException: (context, state, router) {
    HMBToast.error('Route Error: ${state.error}');
  },
  redirect: (context, state) {
    // If the deep link is the Xero OAuth callback, do not change
    // the current route.
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
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(bootstrap: bootstrap),
    ),

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
      path: '/home',
      builder: (_, _) => const HomeScaffold(initialScreen: MainDashboardPage()),
      routes: [...dashboardRoutes()],
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

List<GoRoute> dashboardRoutes() => [
  // 3) Jobs route (replaces the old root builder).
  GoRoute(
    path: 'jobs',
    builder: (_, _) => const HomeScaffold(initialScreen: JobListScreen()),
  ),
  GoRoute(
    path: 'todo',
    builder: (_, _) => const HomeScaffold(initialScreen: ToDoListScreen()),
  ),
  GoRoute(
    path: 'today',
    builder: (_, _) => const HomeScaffold(initialScreen: TodayPage()),
  ),
  GoRoute(
    path: 'booking_requests',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: BookingRequestListScreen()),
  ),

  GoRoute(
    path: 'help',
    builder: (_, _) => const HomeScaffold(initialScreen: HelpDashboardPage()),
    routes: helpRoutes(),
  ),

  GoRoute(
    path: 'schedule',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: SchedulePage(dialogMode: false)),
  ),
  GoRoute(
    path: 'shopping',
    builder: (_, _) => const HomeScaffold(initialScreen: ShoppingScreen()),
  ),
  GoRoute(
    path: 'packing',
    builder: (_, _) => const HomeScaffold(initialScreen: PackingScreen()),
  ),
  GoRoute(
    path: 'accounting',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: AccountingDashboardPage()),
    routes: accountingRoutes(),
  ),
  GoRoute(
    path: 'customers',
    builder: (_, _) => const HomeScaffold(initialScreen: CustomerListScreen()),
  ),
  GoRoute(
    path: 'suppliers',
    builder: (_, _) => const HomeScaffold(initialScreen: SupplierListScreen()),
  ),
  GoRoute(
    path: 'tools',
    builder: (_, _) => const HomeScaffold(initialScreen: ToolListScreen()),
  ),
  GoRoute(
    path: 'manufacturers',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: ManufacturerListScreen()),
  ),
  GoRoute(
    path: 'backup',
    builder: (_, _) => const HomeScaffold(initialScreen: BackupDashboardPage()),
    routes: backupRoutes(),
  ),

  GoRoute(
    path: 'settings',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: SettingsDashboardPage()),
    routes: settingRoutes(),
  ),
];

// List<GoRoute> jobRoutes() => [
//   GoRoute(
//     name: 'estimate',
//     path: 'estimates/:jobId',
//     builder: (context, state) {
//       final jobId = state.pathParameters['jobId']!;
//       return FutureBuilderEx<Job?>(
//         future: DaoJob().getById(int.parse(jobId)),
//         builder: (ctx, job) => JobEstimatesListScreen(job: job),
//       );
//     },
//   ),
//   GoRoute(
//     name: 'quotes',
//     path: 'quotes/:jobId',
//     builder: (context, state) {
//       final jobId = state.pathParameters['jobId']!;
//       return FutureBuilderEx<Job?>(
//         future: DaoJob().getById(int.parse(jobId)),
//         builder: (ctx, job) => QuoteListScreen(job: job),
//       );
//     },
//   ),
//   GoRoute(
//     name: 'track',
//     path: 'track/:jobId',
//     builder: (context, state) {
//       final jobId = state.pathParameters['jobId']!;
//       return FutureBuilderEx<Job?>(
//         future: DaoJob().getById(int.parse(jobId)),
//         builder: (ctx, job) => TimeEntryListScreen(job: job!),
//       );
//     },
//   ),
//   GoRoute(
//     name: 'invoices',
//     path: 'invoices/:jobId',
//     builder: (context, state) {
//       final jobId = state.pathParameters['jobId']!;
//       return FutureBuilderEx<Job?>(
//         future: DaoJob().getById(int.parse(jobId)),
//         builder: (ctx, job) => InvoiceListScreen(job: job),
//       );
//     },
//   ),
// ];

// 4) All other routes directly from the top level:
List<GoRoute> accountingRoutes() => [
  GoRoute(
    path: 'quotes',
    builder: (_, _) => const HomeScaffold(initialScreen: QuoteListScreen()),
  ),
  GoRoute(
    path: 'invoices',
    builder: (_, _) => const HomeScaffold(initialScreen: InvoiceListScreen()),
  ),

  GoRoute(
    path: 'to_be_invoiced',
    builder: (_, _) => HomeScaffold(initialScreen: YetToBeInvoicedScreen()),
  ),
  GoRoute(
    path: 'estimator',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: JobEstimatesListScreen()),
  ),
  GoRoute(
    path: 'milestones',
    builder: (_, _) => const HomeScaffold(initialScreen: ListMilestoneScreen()),
  ),
  GoRoute(
    path: 'receipts',
    builder: (_, _) => const HomeScaffold(initialScreen: ReceiptListScreen()),
  ),
];

/// Setting Dashboard Route
List<GoRoute> settingRoutes() => [
  GoRoute(
    path: 'sms_templates',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: MessageTemplateListScreen()),
  ),
  GoRoute(
    path: 'business',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: SystemBusinessScreen()),
  ),
  GoRoute(
    path: 'billing',
    builder: (_, _) => const HomeScaffold(initialScreen: SystemBillingScreen()),
  ),
  GoRoute(
    path: 'contact',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: SystemContactInformationScreen()),
  ),
  GoRoute(
    path: 'integrations',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: IntegrationDashboardPage()),
    routes: [
      GoRoute(
        path: 'ihserver',
        builder: (_, _) =>
            const HomeScaffold(initialScreen: IhServerIntegrationScreen()),
      ),
      GoRoute(
        path: 'chatgpt',
        builder: (_, _) =>
            const HomeScaffold(initialScreen: ChatGptIntegrationScreen()),
      ),
      GoRoute(
        path: 'xero',
        builder: (_, _) =>
            const HomeScaffold(initialScreen: XeroIntegrationScreen()),
      ),
    ],
  ),
  GoRoute(
    path: 'wizard',
    builder: (context, state) {
      final fromSettings = state.extra as bool? ?? false;
      return HomeScaffold(
        initialScreen: SetupWizard(launchedFromSettings: fromSettings),
      );
    },
  ),
];

List<GoRoute> helpRoutes() => [
  GoRoute(
    path: 'about',
    builder: (_, _) => const HomeScaffold(initialScreen: AboutScreen()),
  ),
];

List<GoRoute> backupRoutes() => [
  GoRoute(
    path: 'google/backup',
    builder: (_, _) =>
        const HomeScaffold(initialScreen: GoogleDriveBackupScreen()),
  ),
  GoRoute(
    path: 'google/restore',
    builder: (_, _) => const HomeScaffold(
      initialScreen: GoogleDriveBackupScreen(restoreOnly: true),
    ),
  ),
  GoRoute(
    path: 'local/backup',
    builder: (_, _) => const HomeScaffold(initialScreen: LocalBackupScreen()),
  ),
];

/// A global RouteObserver that you can attach to GoRouter
final routeObserver = RouteObserver<ModalRoute<void>>();
