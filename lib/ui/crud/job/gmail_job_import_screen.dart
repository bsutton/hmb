import 'dart:async';
import 'dart:io';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../dao/dao_job_attachment.dart';
import '../../../dao/dao_job_source_email.dart';
import '../../../entity/job.dart';
import '../../../entity/job_attachment.dart';
import '../../../integrations/gmail/gmail_import_service.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/paths.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_filter_line.dart';
import '../../widgets/widgets.g.dart' hide StatefulBuilder;
import 'job_creation_email_source.dart';
import 'job_creator.dart';

class GmailJobImportScreen extends StatefulWidget {
  final GmailImportService? service;

  const GmailJobImportScreen({super.key, this.service});

  static Future<Job?> show(BuildContext context) {
    if (!context.mounted) {
      return Future.value();
    }
    return Navigator.of(context).push<Job>(
      MaterialPageRoute(builder: (_) => const GmailJobImportScreen()),
    );
  }

  @override
  State<GmailJobImportScreen> createState() => _GmailJobImportScreenState();
}

class _GmailJobImportScreenState extends DeferredState<GmailJobImportScreen> {
  late final GmailImportService _service;
  final _importedJobIds = <String, int>{};
  var _messages = <GmailMessageSummary>[];
  var _accountEmail = '';
  var _hasSearched = false;
  var _searchText = '';
  var _unreadOnly = false;
  var _hasAttachments = false;
  var _age = _GmailAge.last30Days;
  var _searchGeneration = 0;
  String? _nextPageToken;

  @override
  void initState() {
    _service = widget.service ?? GmailImportService();
    super.initState();
  }

  @override
  Future<void> asyncInitState() => _startSearch();

  Future<void> _search({
    required bool showOverlay,
    required int generation,
  }) async {
    final query = _gmailQuery;

    Future<void> load() async {
      final result = await _service.search(
        query: query,
        textFilter: _searchText,
      );
      if (generation != _searchGeneration) {
        return;
      }
      final imported = <String, int>{};
      for (final message in result.messages) {
        final source = await DaoJobSourceEmail().getByMessage(
          accountEmail: result.accountEmail,
          messageId: message.id,
        );
        if (source != null) {
          imported[message.id] = source.jobId;
        }
      }
      if (generation != _searchGeneration) {
        return;
      }
      _messages = result.messages;
      _accountEmail = result.accountEmail;
      _hasSearched = true;
      _importedJobIds
        ..clear()
        ..addAll(imported);
      _nextPageToken = result.nextPageToken;
    }

    if (showOverlay) {
      await BlockingUI().runAndWait(
        load,
        label: 'Searching Gmail',
        onCancel: _service.cancelPendingOperation,
      );
      if (mounted && generation == _searchGeneration) {
        setState(() {});
      }
    } else {
      await load();
    }
  }

  Future<void> _loadMore(int generation) async {
    final pageToken = _nextPageToken;
    if (pageToken == null) {
      return;
    }
    final result = await BlockingUI().runAndWait(
      () => _service.search(
        query: _gmailQuery,
        textFilter: _searchText,
        pageToken: pageToken,
      ),
      label: 'Loading more email',
    );
    final imported = <String, int>{};
    for (final message in result.messages) {
      final source = await DaoJobSourceEmail().getByMessage(
        accountEmail: result.accountEmail,
        messageId: message.id,
      );
      if (source != null) {
        imported[message.id] = source.jobId;
      }
    }
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    setState(() {
      _messages = [..._messages, ...result.messages];
      _importedJobIds.addAll(imported);
      _nextPageToken = result.nextPageToken;
    });
  }

  Future<void> _openMessage(GmailMessageSummary summary) async {
    final importedJobId = _importedJobIds[summary.id];
    if (importedJobId != null) {
      HMBToast.info(
        'This email has already been imported as job $importedJobId.',
      );
      return;
    }
    final source = await BlockingUI().runAndWait(
      () => _service.loadMessage(
        accountEmail: _accountEmail,
        messageId: summary.id,
      ),
      label: 'Loading email',
    );
    if (!mounted) {
      return;
    }
    final selectedAttachments = await _preview(source);
    if (selectedAttachments == null || !mounted) {
      return;
    }

    final duplicate = await DaoJobSourceEmail().getByMessage(
      accountEmail: source.accountEmail,
      messageId: source.messageId,
    );
    if (duplicate != null) {
      HMBToast.info(
        'This email has already been imported as job ${duplicate.jobId}.',
      );
      return;
    }
    if (!mounted) {
      return;
    }

    final job = await JobCreator.show(context, emailSource: source);
    if (job != null && mounted) {
      if (selectedAttachments.isNotEmpty) {
        try {
          await BlockingUI().runAndWait(
            () => _importAttachments(job, source, selectedAttachments),
            label: 'Importing attachments',
          );
        } catch (error) {
          HMBToast.error(
            'The job was created, but an attachment could not be imported: '
            '$error',
            acknowledgmentRequired: true,
          );
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(job);
    }
  }

  Future<Set<String>?> _preview(JobCreationEmailSource source) {
    final selected = source.attachments.map((item) => item.key).toSet();
    return showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(source.subject.isEmpty ? '(No subject)' : source.subject),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.senderName.isEmpty
                        ? source.senderEmail
                        : '${source.senderName} <${source.senderEmail}>',
                  ),
                  Text(formatDateTime(source.receivedAt.toLocal())),
                  if (source.attachments.isNotEmpty) ...[
                    const Divider(),
                    const Text('Attachments to add to the job'),
                    ...source.attachments.map(
                      (attachment) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(attachment.filename),
                        subtitle: attachment.size <= 0
                            ? null
                            : Text('${attachment.size} bytes'),
                        value: selected.contains(attachment.key),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked ?? false) {
                              selected.add(attachment.key);
                            } else {
                              selected.remove(attachment.key);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                  const Divider(),
                  SelectableText(source.body),
                ],
              ),
            ),
          ),
          actions: [
            HMBButton(
              label: 'Cancel',
              hint: 'Return to Gmail search results',
              onPressed: () => Navigator.of(context).pop(),
            ),
            HMBButton(
              label: 'Create job',
              hint: 'Use this email in the Create Job Wizard',
              onPressed: () => Navigator.of(context).pop(selected),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importAttachments(
    Job job,
    JobCreationEmailSource source,
    Set<String> selected,
  ) async {
    final root = await getJobAttachmentsRootPath();
    final directory = Directory(p.join(root, job.id.toString()));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    for (final attachment in source.attachments) {
      if (!selected.contains(attachment.key)) {
        continue;
      }
      final bytes = await _service.loadAttachment(
        messageId: source.messageId,
        attachment: attachment,
      );
      if (bytes.isEmpty) {
        throw StateError('Gmail returned an empty ${attachment.filename}.');
      }
      final safeName = p
          .basename(attachment.filename)
          .replaceAll(RegExp('[^A-Za-z0-9._ -]'), '_');
      final safeKey = attachment.key.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
      final file = File(p.join(directory.path, '${safeKey}_$safeName'));
      await file.writeAsBytes(bytes, flush: true);
      await DaoJobAttachment().insert(
        JobAttachment.forInsert(
          jobId: job.id,
          filePath: file.path,
          displayName: attachment.filename,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (context) => const SizedBox.shrink(),
    errorBuilder: (context, error) => Scaffold(
      appBar: AppBar(title: const Text('Import Job from Gmail')),
      body: Center(child: Text('Unable to load Gmail: $error')),
    ),
    builder: (context) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 0,
        title: HMBFilterLine(
          lineBuilder: (_) => HMBSearch(
            label: 'To, From or Subject',
            onSearch: _onSearchChanged,
          ),
          sheetBuilder: (_) => _buildFilterSheet(),
          onReset: _resetFilters,
          onSheetClosed: _filtersChanged,
          isActive: () =>
              _unreadOnly || _hasAttachments || _age != _GmailAge.last30Days,
          tooltip: 'Email filters',
        ),
      ),
      body: Surface(
        elevation: SurfaceElevation.e0,
        child: HMBColumn(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: HMBRow(
                children: [
                  Expanded(
                    child: Text(
                      _accountEmail.isEmpty
                          ? 'Connect Gmail, then search by sender, recipient, '
                                'or subject.'
                          : 'Connected as $_accountEmail',
                    ),
                  ),
                  HMBButton(
                    label: _accountEmail.isEmpty
                        ? 'Connect and search'
                        : 'Refresh',
                    hint: _accountEmail.isEmpty
                        ? 'Connect Gmail and search for matching email'
                        : 'Refresh the Gmail search results',
                    onPressed: _runSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        _hasSearched
                            ? 'No matching email found.'
                            : 'Select Connect and search to choose an email '
                                  'from Gmail.',
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          _messages.length + (_nextPageToken == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Center(
                            child: HMBButton(
                              label: 'Load more',
                              hint: 'Load more Gmail search results',
                              onPressed: _runLoadMore,
                            ),
                          );
                        }
                        return _buildMessage(_messages[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildMessage(GmailMessageSummary message) {
    final importedJobId = _importedJobIds[message.id];
    return HMBListCard(
      title: message.subject.isEmpty ? '(No subject)' : message.subject,
      onTap: () => _runOpenMessage(message),
      children: [
        Text(message.sender),
        Text(formatDateTime(message.receivedAt.toLocal())),
        Text(message.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (message.hasAttachments) const Text('Attachments'),
        if (importedJobId != null) Text('Already imported: job $importedJobId'),
      ],
    );
  }

  void _runSearch() => unawaited(_startSearchAfterButtonFeedback());

  Future<void> _startSearchAfterButtonFeedback() async {
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      await _startSearch();
    }
  }

  Future<void> _startSearch() async {
    final generation = ++_searchGeneration;
    _nextPageToken = null;
    _importedJobIds.clear();
    await _guard(() => _search(showOverlay: true, generation: generation));
  }

  Future<void> _onSearchChanged(String? value) async {
    _searchText = value?.trim() ?? '';
    if (_accountEmail.isNotEmpty) {
      await _startSearch();
    }
  }

  String get _gmailQuery => buildGmailSearchQuery(
    text: _searchText,
    unreadOnly: _unreadOnly,
    hasAttachments: _hasAttachments,
    newerThanDays: _age.days,
  );

  Widget _buildFilterSheet() => StatefulBuilder(
    builder: (context, setSheetState) => HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          title: const Text('Unread only'),
          value: _unreadOnly,
          onChanged: (value) => setSheetState(() {
            _unreadOnly = value ?? false;
          }),
        ),
        CheckboxListTile(
          title: const Text('Has attachments'),
          value: _hasAttachments,
          onChanged: (value) => setSheetState(() {
            _hasAttachments = value ?? false;
          }),
        ),
        HMBDroplist<_GmailAge>(
          title: 'Received',
          selectedItem: () async => _age,
          items: (_) async => _GmailAge.values,
          format: (age) => age.label,
          onChanged: (age) => setSheetState(() {
            _age = age ?? _GmailAge.last30Days;
          }),
          showSearch: false,
        ),
      ],
    ),
  );

  void _resetFilters() {
    _unreadOnly = false;
    _hasAttachments = false;
    _age = _GmailAge.last30Days;
  }

  void _filtersChanged() {
    setState(() {});
    if (_accountEmail.isNotEmpty) {
      unawaited(_startSearch());
    }
  }

  void _runLoadMore() => unawaited(_startLoadMore());

  Future<void> _startLoadMore() async {
    final generation = _searchGeneration;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    await _guard(() => _loadMore(generation));
  }

  void _runOpenMessage(GmailMessageSummary message) =>
      unawaited(_guard(() => _openMessage(message)));

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on GmailImportCancelled {
      if (mounted) {
        HMBToast.info('Gmail search cancelled.');
      }
    } catch (error) {
      HMBToast.error(
        'Gmail import failed: $error',
        acknowledgmentRequired: true,
      );
    }
  }
}

enum _GmailAge {
  last7Days('Last 7 days', 7),
  last30Days('Last 30 days', 30),
  last90Days('Last 90 days', 90),
  anyTime('Any time', null);

  const _GmailAge(this.label, this.days);

  final String label;
  final int? days;
}
