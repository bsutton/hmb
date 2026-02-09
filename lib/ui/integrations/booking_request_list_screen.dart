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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/ihserver/booking_request_sync_service.dart';
import '../../dao/dao_booking_request.dart';
import '../../dao/dao_system.dart';
import '../../entity/booking_request.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_filter_line.dart';
import '../widgets/widgets.g.dart' hide StatefulBuilder;
import 'booking_request_review_dialog.dart';

class BookingRequestListScreen extends StatefulWidget {
  const BookingRequestListScreen({super.key});

  @override
  State<BookingRequestListScreen> createState() =>
      _BookingRequestListScreenState();
}

class _BookingRequestListScreenState extends State<BookingRequestListScreen> {
  final _dao = DaoBookingRequest();
  final _systemDao = DaoSystem();
  var _loading = false;
  var _showRejected = false;
  var _showConverted = false;
  var _showPending = true;

  Future<List<BookingRequest>> _load() {
    final statuses = <BookingRequestStatus>[];
    if (_showPending) {
      statuses.add(BookingRequestStatus.pending);
    }
    if (_showRejected) {
      statuses.add(BookingRequestStatus.rejected);
    }
    if (_showConverted) {
      statuses.add(BookingRequestStatus.imported);
    }
    return _dao.getByStatuses(statuses);
  }

  Future<void> _sync() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      final system = await DaoSystem().get();
      if (!system.enableIhserverIntegration) {
        HMBToast.error('Enable booking sync to check for new requests.');
        return;
      }
      await BookingRequestSyncService().sync(force: true);
    } catch (e) {
      HMBToast.error(_friendlySyncError(e));
      if (_isConfigIssue(e)) {
        if (mounted) {
          await _showConfigHelpDialog(context);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Surface(
    elevation: SurfaceElevation.e0,
    child: HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder(
          future: _systemDao.get(),
          builder: (context, snapshot) {
            final system = snapshot.data;
            if (system == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!system.enableIhserverIntegration) {
              return Expanded(child: _buildConfigHelp(context));
            }
            return Expanded(
              child: HMBColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HMBFilterLine(
                    lineBuilder: (_) => Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Booking Requests'),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loading ? null : _sync,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Sync now'),
                        ),
                      ],
                    ),
                    sheetBuilder: (_) => _buildFilterSheet(),
                    onReset: () {
                      setState(() {
                        _showRejected = false;
                        _showConverted = false;
                        _showPending = true;
                      });
                    },
                    isActive: () =>
                        _showRejected || _showConverted || !_showPending,
                  ),
                  Expanded(
                    child: FutureBuilder<List<BookingRequest>>(
                      future: _load(),
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? const <BookingRequest>[];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (data.isEmpty) {
                          final message =
                              _showRejected || _showConverted || !_showPending
                              ? 'No requests match the current filter.'
                              : 'No pending requests.';
                          return Center(child: Text(message));
                        }
                        return ListView.builder(
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final request = data[index];
                            final payload = request.parsedPayload;
                            final statusLabel = switch (request.status) {
                              BookingRequestStatus.rejected => 'Rejected',
                              BookingRequestStatus.imported => 'Converted',
                              _ => 'Pending',
                            };
                            final subtitle =
                                '${payload.suburb} • ${payload.phone} '
                                '• $statusLabel';
                            return Card(
                              child: ListTile(
                                title: Text(
                                  payload.name.isEmpty
                                      ? 'New Request'
                                      : payload.name,
                                ),
                                subtitle: Text(subtitle),
                                trailing: TextButton(
                                  onPressed: () async {
                                    await BookingRequestReviewDialog.show(
                                      context,
                                      request,
                                    );
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('Review'),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );

  Widget _buildConfigHelp(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking sync is not configured',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              const Text(
                'Booking sync pulls website enquiries from ihserver and '
                'lets you review and create customers, jobs, and tasks. '
                'To enable it, add your ihserver URL and access token in '
                'Integrations.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Need the access token? It is set in ihserver '
                '`config/config.yaml` as `hmb_api_token`.',
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => GoRouter.of(
                  context,
                ).go('/home/settings/integrations/ihserver'),
                icon: const Icon(Icons.settings),
                label: const Text('Open ihserver settings'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  bool _isConfigIssue(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('403') ||
        message.contains('401') ||
        message.contains('forbidden') ||
        message.contains('unauthorized') ||
        message.contains('ihserver error');
  }

  Widget _buildFilterSheet() => StatefulBuilder(
    builder: (context, void Function(void Function()) setModalState) =>
        HMBColumn(
          children: [
            SwitchListTile(
              title: const Text('Show Pending'),
              value: _showPending,
              onChanged: (val) {
                setState(() => _showPending = val);
                setModalState(() {});
              },
            ).help('Show Pending', 'Show enquiries that are awaiting review.'),
            SwitchListTile(
              title: const Text('Show Rejected'),
              value: _showRejected,
              onChanged: (val) {
                setState(() => _showRejected = val);
                setModalState(() {});
              },
            ).help('Show Rejected', 'Show enquiries that have been rejected.'),
            SwitchListTile(
              title: const Text('Show Converted'),
              value: _showConverted,
              onChanged: (val) {
                setState(() => _showConverted = val);
                setModalState(() {});
              },
            ).help(
              'Show Converted',
              'Show enquiries that have been converted to jobs.',
            ),
          ],
        ),
  );

  String _friendlySyncError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('connection refused') ||
        message.contains('failed host lookup') ||
        message.contains('clientexception') ||
        message.contains('socketexception')) {
      return 'Cannot reach the booking server. Check that ihserver is running '
          'and the URL is correct.';
    }
    if (message.contains('timed out') || message.contains('timeout')) {
      return 'Booking server is taking too long to respond. Please try again.';
    }
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('forbidden')) {
      return 'Booking sync is not authorized. Check the ihserver token.';
    }
    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504')) {
      return 'Booking server error. Please try again later.';
    }
    return 'Unable to sync booking requests right now. Please try again.';
  }

  Future<void> _showConfigHelpDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Booking sync needs attention'),
      content: const Text(
        'Sync failed due to a configuration or authorization issue. '
        'Check the ihserver URL and access token in Integrations. '
        'Also confirm ihserver has `hmb_api_token` set.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            GoRouter.of(context).go('/home/settings/integrations/ihserver');
          },
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
}
