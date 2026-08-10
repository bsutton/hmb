/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_customer.dart';
import '../../../dao/dao_mailing.dart';
import '../../../dao/dao_mailing_recipient.dart';
import '../../../dao/dao_site.dart';
import '../../../dao/dao_system.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_site.dart';
import '../../../entity/customer.dart';
import '../../../entity/mailing.dart';
import '../../../entity/mailing_recipient.dart';
import '../../../entity/site.dart';
import '../../../entity/system.dart';
import '../../../util/dart/address_format.dart';
import '../../../util/flutter/app_title.dart';
import '../../crud/site/edit_site_screen.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/color_ex.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/icons/hmb_filter_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_filter_sheet.dart';
import 'google_maps_route_service.dart';
import 'mailing_delivery_screen.dart';
import 'mailing_labels_screen.dart';

class MailingEditScreen extends StatefulWidget {
  final int mailingId;

  const MailingEditScreen({required this.mailingId, super.key});

  @override
  State<MailingEditScreen> createState() => _MailingEditScreenState();
}

enum _MailingIssueFilter {
  all,
  needsAttention,
  incompleteAddress,
  unresolvedMultipleAddress,
  excluded;

  String get label => switch (this) {
    _MailingIssueFilter.all => 'All recipients',
    _MailingIssueFilter.needsAttention => 'Needs checking',
    _MailingIssueFilter.incompleteAddress => 'Invalid address',
    _MailingIssueFilter.unresolvedMultipleAddress =>
      'Multiple address not selected',
    _MailingIssueFilter.excluded => 'Excluded recipients',
  };
}

enum _MailingSortOrder {
  name,
  route;

  String get label => switch (this) {
    _MailingSortOrder.name => 'Contact name',
    _MailingSortOrder.route => 'Optimised route order',
  };
}

enum _AddressEditChoice { applySuggestion, editManually }

class _MailingEditScreenState extends State<MailingEditScreen> {
  final _mailingDao = DaoMailing();
  final _recipientDao = DaoMailingRecipient();
  final _searchController = TextEditingController();

  Mailing? _mailing;
  List<MailingRecipient> _recipients = [];
  final _undoStack = <List<MailingRecipient>>[];
  Map<int, int> _siteCountByCustomerId = {};
  Set<int> _validationAttentionSiteIds = {};
  var _loading = true;
  var _showExcluded = false;
  var _issueFilter = _MailingIssueFilter.all;
  var _sortOrder = _MailingSortOrder.name;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_load());
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mailing = await _mailingDao.getById(widget.mailingId);
    if (mailing == null) {
      return;
    }
    await _recipientDao.deselectUnmailableRecipients(mailing.id);
    final recipients = await _refreshLinkedSiteSnapshots(
      await _recipientDao.getByMailing(mailing.id),
    );
    final siteCountByCustomerId = <int, int>{};
    for (final recipient in recipients) {
      siteCountByCustomerId[recipient.customerId] =
          (await DaoSite().getByCustomer(recipient.customerId)).length;
    }
    final validationAttentionSiteIds = await _validationAttentionSiteIdsFor(
      recipients,
    );
    if (mounted) {
      setAppTitle(mailing.name);
      setState(() {
        _mailing = mailing;
        _recipients = recipients;
        _siteCountByCustomerId = siteCountByCustomerId;
        _validationAttentionSiteIds = validationAttentionSiteIds;
        if (!mailing.routeOptimised) {
          _sortOrder = _MailingSortOrder.name;
        }
        _loading = false;
      });
    }
  }

  Future<void> _setAll(bool selected) async {
    _pushUndo(_recipients);
    await _recipientDao.setAllSelected(
      mailingId: widget.mailingId,
      selected: selected,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _recipients = [
        for (final recipient in _recipients)
          recipient.hasAddress && !recipient.excluded
              ? recipient.copyWith(selected: selected, clearRoute: true)
              : recipient,
      ];
    });
  }

  Future<void> _toggle(
    MailingRecipient recipient, {
    required bool selected,
    Site? selectedSite,
  }) async {
    final current =
        _recipients
            .where((existing) => existing.id == recipient.id)
            .firstOrNull ??
        await _recipientDao.getById(recipient.id) ??
        recipient;
    if (selected && current.excluded) {
      HMBToast.error('Restore this recipient before selecting them.');
      return;
    }
    if (selected && !current.hasAddress) {
      final refreshed = await _refreshFromSelectedSite(
        current,
        selectedSite: selectedSite,
      );
      if (refreshed == null) {
        HMBToast.error('Select an address before including this recipient.');
        return;
      }
      _pushUndo([current]);
      _replaceRecipient(refreshed);
      return;
    }
    _pushUndo([current]);
    final updated = current.copyWith(selected: selected, clearRoute: true);
    await _recipientDao.update(updated);
    _replaceRecipient(updated);
  }

  Future<MailingRecipient?> _refreshFromSelectedSite(
    MailingRecipient recipient, {
    Site? selectedSite,
  }) async {
    final siteId = recipient.siteId;
    final site =
        selectedSite ??
        (siteId == null ? null : await DaoSite().getById(siteId));
    if (site == null || !DaoMailingRecipient.hasMailableAddress(site)) {
      return null;
    }
    return _recipientDao.refreshFromSite(recipient, site);
  }

  Future<void> _setExcluded(
    MailingRecipient recipient, {
    required bool excluded,
  }) async {
    _pushUndo([recipient]);
    final updated = recipient.copyWith(
      excluded: excluded,
      selected: !excluded && recipient.hasAddress,
      clearRoute: true,
    );
    await _recipientDao.update(updated);
    _replaceRecipient(updated);
  }

  Future<void> _excludeFromFutureMailings(MailingRecipient recipient) async {
    final customer = await DaoCustomer().getById(recipient.customerId);
    if (customer == null) {
      HMBToast.error('Unable to update this customer.');
      return;
    }
    await DaoCustomer().update(customer.copyWith(excludeFromMailings: true));
    if (!recipient.excluded) {
      await _setExcluded(recipient, excluded: true);
    }
    HMBToast.info('Customer excluded from future mailings.');
  }

  Future<void> _undoLastAction() async {
    if (_undoStack.isEmpty) {
      HMBToast.info('Nothing to undo.');
      return;
    }
    final previous = _undoStack.removeLast();
    for (final recipient in previous) {
      await _recipientDao.update(recipient);
    }
    await _load();
  }

  void _pushUndo(Iterable<MailingRecipient> recipients) {
    _undoStack.add([...recipients]);
    if (_undoStack.length > 10) {
      _undoStack.removeAt(0);
    }
  }

  Future<void> _optimiseRoute() async {
    final mailing = _mailing!;
    final origin = await _routeOrigin();
    if (Strings.isBlank(origin)) {
      HMBToast.error('Set the business address before optimising the route.');
      return;
    }
    if (_readyRecipients().isEmpty) {
      HMBToast.error('Select at least one recipient before routing.');
      return;
    }
    final businessAddress = await _businessAddressForValidation();
    if (businessAddress == null) {
      return;
    }

    var validationIssues = <MailingAddressValidationIssue>[];
    RouteOptimisationResult? routeResult;
    try {
      await BlockingUI().runAndWait(() async {
        validationIssues = await _collectAddressValidationIssues(
          includeInvalidPartial: false,
          businessAddress: businessAddress,
          checkRouteReadiness: true,
        );
        if (validationIssues.isNotEmpty) {
          return;
        }

        final routeService = GoogleMapsRouteService();
        final readyRecipients = _readyRecipients();
        routeResult = await routeService.optimiseWithResult(
          origin: origin!,
          recipients: readyRecipients,
        );
        final fallbackReason = routeResult!.fallbackReason;
        if (fallbackReason != null) {
          await _recipientDao.clearRouteOrder(mailing.id);
          await _mailingDao.update(
            mailing.copyWith(
              status: MailingStatus.draft,
              routeOrigin: origin,
              routeOptimised: false,
            ),
          );
          return;
        }
        await _recipientDao.saveRouteOrder(routeResult!.recipients);
        await _mailingDao.update(
          mailing.copyWith(
            status: MailingStatus.routeReady,
            routeOrigin: origin,
            routeOptimised: true,
          ),
        );
      }, label: 'Optimising Route');
      await _refreshValidationAttentionState();
      if (validationIssues.isNotEmpty) {
        await _showAddressValidationIssues(
          validationIssues,
          title: 'Route readiness',
        );
        return;
      }
      final fallbackReason = routeResult?.fallbackReason;
      if (fallbackReason == null) {
        HMBToast.info('Route optimised for ${_readyRecipients().length} stops');
        _sortOrder = _MailingSortOrder.route;
      } else {
        await _showRouteFailure(
          fallbackReason,
          failedRecipient: routeResult?.failedRecipient,
        );
        _sortOrder = _MailingSortOrder.name;
      }
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Route optimisation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _showRouteFailure('Route optimisation failed.\n\n$error');
    }
  }

  Future<String?> _routeOrigin() async {
    final mailing = _mailing!;
    final origin = mailing.routeOrigin;
    if (_hasSpecificFreeformAddress(origin)) {
      return origin;
    }
    return _businessAddressForValidation();
  }

  Future<bool> _validateAddresses({
    bool showSuccess = true,
    bool includeInvalidPartial = true,
  }) async {
    final businessAddress = await _businessAddressForValidation();
    if (businessAddress == null) {
      return true;
    }
    if (!mounted) {
      return true;
    }

    var issues = <MailingAddressValidationIssue>[];
    await BlockingUI().runAndWait(() async {
      issues = await _collectAddressValidationIssues(
        includeInvalidPartial: includeInvalidPartial,
        businessAddress: businessAddress,
        checkRouteReadiness: true,
      );
    }, label: 'Validating Addresses');
    await _refreshValidationAttentionState();

    if (!mounted) {
      return true;
    }
    if (issues.isEmpty) {
      if (showSuccess) {
        HMBToast.info('All checked addresses validated.');
      }
      return false;
    }
    await _showAddressValidationIssues(issues, title: 'Delivery validation');
    return true;
  }

  Future<List<MailingAddressValidationIssue>> _collectAddressValidationIssues({
    required bool includeInvalidPartial,
    required String businessAddress,
    bool checkRouteReadiness = false,
  }) async {
    await _refreshVisibleLinkedSiteSnapshots();
    final validationRecipients = includeInvalidPartial
        ? await _validationRecipients()
        : _readyRecipients();
    if (validationRecipients.isEmpty) {
      return [
        MailingAddressValidationIssue(
          message: 'Select at least one recipient or invalid address.',
        ),
      ];
    }

    return GoogleMapsRouteService().validateRecipients(
      recipients: validationRecipients,
      businessAddress: businessAddress,
      checkRouteReadiness: checkRouteReadiness,
    );
  }

  Future<String?> _businessAddressForValidation() async {
    var system = await DaoSystem().getForUpdate();
    if (_hasSpecificBusinessAddress(system)) {
      return system.address;
    }
    if (!mounted) {
      return null;
    }
    system = await _promptForBusinessAddress(system) ?? system;
    if (!_hasSpecificBusinessAddress(system)) {
      return null;
    }
    return system.address;
  }

  bool _hasSpecificBusinessAddress(System system) =>
      MailingRecipient.hasSpecificAddressLine(system.addressLine1 ?? '') &&
      Strings.isNotBlank(system.suburb);

  bool _hasSpecificFreeformAddress(String? address) =>
      Strings.isNotBlank(address) &&
      MailingRecipient.hasSpecificAddressLine(address!.split(',').first);

  Future<System?> _promptForBusinessAddress(System system) async {
    final line1 = TextEditingController(text: system.addressLine1);
    final line2 = TextEditingController(text: system.addressLine2);
    final suburb = TextEditingController(text: system.suburb);
    final state = TextEditingController(text: system.state);
    final postcode = TextEditingController(text: system.postcode);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Business Address'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To improve selecting local addresses as suggestions, '
                  'please provide your business address details.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: line1,
                  decoration: const InputDecoration(
                    labelText: 'Address line 1',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.streetAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: line2,
                  decoration: const InputDecoration(
                    labelText: 'Address line 2',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.streetAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: suburb,
                  decoration: const InputDecoration(
                    labelText: 'Suburb',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: state,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: postcode,
                        decoration: const InputDecoration(
                          labelText: 'Postcode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([line1, suburb]),
              builder: (context, child) => TextButton(
                onPressed:
                    !MailingRecipient.hasSpecificAddressLine(line1.text) ||
                        Strings.isBlank(suburb.text)
                    ? null
                    : () => Navigator.pop(context, true),
                child: child!,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (saved != true) {
        return null;
      }
      system
        ..addressLine1 = line1.text.trim()
        ..addressLine2 = line2.text.trim()
        ..suburb = suburb.text.trim()
        ..state = state.text.trim()
        ..postcode = postcode.text.trim();
      await DaoSystem().updateConfiguration(system);
      return system;
    } finally {
      line1.dispose();
      line2.dispose();
      suburb.dispose();
      state.dispose();
      postcode.dispose();
    }
  }

  Future<void> _showAddressValidationIssues(
    List<MailingAddressValidationIssue> issues, {
    String title = 'Address validation',
  }) async {
    if (!mounted) {
      return;
    }
    final remaining = [...issues];
    final applied = <_ValidationDialogAction>[];
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: remaining.isEmpty
                ? const Center(child: Text('All validation issues fixed.'))
                : ListView.separated(
                    itemCount: remaining.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final issue = remaining[index];
                      final recipient = issue.recipient;
                      return MailingAddressValidationIssueTile(
                        issue: issue,
                        onApplySuggestion:
                            recipient == null || issue.suggestion == null
                            ? null
                            : (suggestion) async {
                                final application =
                                    await _applyAddressSuggestion(
                                      recipient,
                                      suggestion,
                                      showToast: false,
                                    );
                                setDialogState(() {
                                  if (application != null) {
                                    applied.add(
                                      _ValidationDialogAction(
                                        issue: issue,
                                        index: index,
                                        undo: () =>
                                            _undoAppliedAddressSuggestion(
                                              application,
                                            ),
                                      ),
                                    );
                                  }
                                  remaining.removeAt(index);
                                });
                              },
                        onEditManually: recipient == null
                            ? null
                            : () async {
                                await _editValidationIssueAddress(issue);
                              },
                        onExclude: recipient == null
                            ? null
                            : () async {
                                final action =
                                    await _excludeValidationIssueRecipient(
                                      issue,
                                      index,
                                    );
                                setDialogState(() {
                                  if (action != null) {
                                    applied.add(action);
                                  }
                                  remaining.removeAt(index);
                                });
                              },
                        onNoMail: recipient == null
                            ? null
                            : () async {
                                final action =
                                    await _noMailValidationIssueRecipient(
                                      issue,
                                      index,
                                    );
                                setDialogState(() {
                                  if (action != null) {
                                    applied.add(action);
                                  }
                                  remaining.removeAt(index);
                                });
                              },
                      );
                    },
                  ),
          ),
          actions: [
            HMBButton.small(
              label: 'Undo',
              hint: 'Undo the last validation action',
              onPressed: applied.isEmpty
                  ? () {}
                  : () async {
                      final action = applied.removeLast();
                      await action.undo();
                      setDialogState(() {
                        remaining.insert(
                          action.index.clamp(0, remaining.length),
                          action.issue,
                        );
                      });
                    },
              enabled: applied.isNotEmpty,
            ),
            HMBButton.small(
              label: 'Close',
              hint: 'Close address validation',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<_AppliedAddressSuggestion?> _applyAddressSuggestion(
    MailingRecipient recipient,
    SuggestedSiteAddress suggestion, {
    bool showToast = true,
  }) async {
    final updated = suggestion.site;
    final previousSite = await DaoSite().getById(updated.id);
    final previousRecipient = _recipients
        .where((existing) => existing.id == recipient.id)
        .firstOrNull;
    if (previousRecipient == null) {
      return null;
    }
    _pushUndo([previousRecipient]);
    await DaoSite().update(updated);
    final refreshed = await _recipientDao.refreshFromSite(
      previousRecipient,
      updated,
    );
    await _refreshValidationAttentionState();
    _replaceRecipient(refreshed);
    if (showToast) {
      HMBToast.info('Address suggestion applied.');
    }
    return _AppliedAddressSuggestion(
      issue: MailingAddressValidationIssue(
        recipient: previousRecipient,
        suggestion: suggestion,
        message: '',
      ),
      index: 0,
      previousRecipient: previousRecipient,
      previousSite: previousSite,
    );
  }

  Future<void> _undoAppliedAddressSuggestion(
    _AppliedAddressSuggestion application,
  ) async {
    final previousSite = application.previousSite;
    if (previousSite != null) {
      await DaoSite().update(previousSite);
    }
    await _recipientDao.update(application.previousRecipient);
    await _refreshValidationAttentionState();
    _replaceRecipient(application.previousRecipient);
  }

  Future<_ValidationDialogAction?> _excludeValidationIssueRecipient(
    MailingAddressValidationIssue issue,
    int index,
  ) async {
    final recipient = issue.recipient;
    if (recipient == null) {
      return null;
    }
    final previousRecipient =
        _recipients
            .where((existing) => existing.id == recipient.id)
            .firstOrNull ??
        await _recipientDao.getById(recipient.id) ??
        recipient;
    final updated = previousRecipient.copyWith(
      excluded: true,
      selected: false,
      clearRoute: true,
    );
    await _recipientDao.update(updated);
    await _refreshValidationAttentionState();
    _replaceRecipient(updated);
    return _ValidationDialogAction(
      issue: issue,
      index: index,
      undo: () async {
        await _recipientDao.update(previousRecipient);
        await _refreshValidationAttentionState();
        _replaceRecipient(previousRecipient);
      },
    );
  }

  Future<_ValidationDialogAction?> _noMailValidationIssueRecipient(
    MailingAddressValidationIssue issue,
    int index,
  ) async {
    final recipient = issue.recipient;
    if (recipient == null) {
      return null;
    }
    final previousRecipient =
        _recipients
            .where((existing) => existing.id == recipient.id)
            .firstOrNull ??
        await _recipientDao.getById(recipient.id) ??
        recipient;
    final customer = await DaoCustomer().getById(recipient.customerId);
    if (customer == null) {
      HMBToast.error('Unable to update this customer.');
      return null;
    }
    await DaoCustomer().update(customer.copyWith(excludeFromMailings: true));
    final updated = previousRecipient.copyWith(
      excluded: true,
      selected: false,
      clearRoute: true,
    );
    await _recipientDao.update(updated);
    await _refreshValidationAttentionState();
    _replaceRecipient(updated);
    return _ValidationDialogAction(
      issue: issue,
      index: index,
      undo: () async {
        await DaoCustomer().update(customer);
        await _recipientDao.update(previousRecipient);
        await _refreshValidationAttentionState();
        _replaceRecipient(previousRecipient);
      },
    );
  }

  Future<void> _editValidationIssueAddress(
    MailingAddressValidationIssue issue,
  ) async {
    final recipient = issue.recipient;
    if (recipient == null) {
      return;
    }
    final site = await _siteForRecipient(recipient);
    if (site == null) {
      HMBToast.error('No site address is available for this recipient.');
      return;
    }
    await _editSiteForRecipient(recipient, site);
  }

  Future<void> _showRouteFailure(
    String message, {
    MailingRecipient? failedRecipient,
  }) async {
    if (!mounted) {
      return;
    }
    final editAddress = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route optimisation failed'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(child: SelectableText(message)),
        ),
        actions: [
          if (failedRecipient != null)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Edit Address'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if ((editAddress ?? false) && failedRecipient != null) {
      await _suggestAndEditRecipientAddress(failedRecipient);
    }
  }

  Future<void> _suggestAndEditRecipientAddress(
    MailingRecipient recipient,
  ) async {
    final site = await _siteForRecipient(recipient);
    if (site == null) {
      HMBToast.error('No site address is available for this recipient.');
      return;
    }

    SuggestedSiteAddress? suggestion;
    await BlockingUI().runAndWait(() async {
      suggestion = await GoogleMapsRouteService().suggestSiteAddress(site);
    }, label: 'Finding Address Suggestion');

    if (suggestion == null) {
      await _editSiteForRecipient(recipient, site);
      return;
    }

    final suggestedAddress = suggestion!;
    final choice = await _showAddressSuggestion(site, suggestedAddress);
    if (choice == null) {
      return;
    }
    switch (choice) {
      case _AddressEditChoice.applySuggestion:
        final updated = suggestedAddress.site;
        await DaoSite().update(updated);
        await _refreshRecipientFromSite(recipient, updated);
        HMBToast.info('Address suggestion applied.');
      case _AddressEditChoice.editManually:
        await _editSiteForRecipient(
          recipient,
          site,
          initialSite: suggestedAddress.site,
        );
    }
  }

  Future<_AddressEditChoice?> _showAddressSuggestion(
    Site current,
    SuggestedSiteAddress suggestion,
  ) {
    final suggested = suggestion.site;
    return showDialog<_AddressEditChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Address suggestion'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current', style: Theme.of(context).textTheme.titleSmall),
              SelectableText(current.address),
              const SizedBox(height: 16),
              Text('Suggested', style: Theme.of(context).textTheme.titleSmall),
              SelectableText(suggested.address),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _AddressEditChoice.editManually),
            child: const Text('Edit Manually'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _AddressEditChoice.applySuggestion),
            child: const Text('Apply Suggestion'),
          ),
        ],
      ),
    );
  }

  Future<Site?> _siteForRecipient(MailingRecipient recipient) async {
    final siteId = recipient.siteId;
    if (siteId != null) {
      return DaoSite().getById(siteId);
    }
    final sites = await DaoSite().getByCustomer(recipient.customerId);
    if (sites.length == 1) {
      return sites.single;
    }
    return null;
  }

  Future<void> _refreshVisibleLinkedSiteSnapshots() async {
    final refreshed = await _refreshLinkedSiteSnapshots(_recipients);
    if (!mounted) {
      return;
    }
    setState(() => _recipients = refreshed);
  }

  Future<List<MailingRecipient>> _refreshLinkedSiteSnapshots(
    List<MailingRecipient> recipients,
  ) async {
    final refreshed = <MailingRecipient>[];
    for (final recipient in recipients) {
      final site = await _siteForRecipient(recipient);
      if (site == null || _recipientMatchesSite(recipient, site)) {
        refreshed.add(recipient);
        continue;
      }
      refreshed.add(
        await _recipientDao.refreshFromSite(
          recipient,
          site,
          preserveRecipientState: true,
        ),
      );
    }
    return refreshed;
  }

  bool _recipientMatchesSite(MailingRecipient recipient, Site site) =>
      recipient.siteId == site.id &&
      recipient.siteName == site.name &&
      recipient.addressLine1 == site.addressLine1 &&
      recipient.addressLine2 == site.addressLine2 &&
      recipient.suburb == site.suburb &&
      recipient.state == site.state &&
      recipient.postcode == site.postcode;

  Future<void> _editSiteForRecipient(
    MailingRecipient recipient,
    Site selectedSite, {
    Site? initialSite,
  }) async {
    final customer = await DaoCustomer().getById(recipient.customerId);
    final site = initialSite ?? await DaoSite().getById(selectedSite.id);
    if (!mounted) {
      return;
    }
    if (customer == null || site == null) {
      HMBToast.error('Unable to edit this delivery address.');
      return;
    }
    await Navigator.push<Site>(
      context,
      MaterialPageRoute<Site>(
        builder: (context) => SiteEditScreen<Customer>(
          parent: customer,
          daoJoin: JoinAdaptorCustomerSite(),
          site: site,
        ),
      ),
    );
    final updated = await DaoSite().getById(site.id);
    if (updated == null) {
      return;
    }
    await _validateEditedSite(recipient, updated);
  }

  Future<void> _validateEditedSite(
    MailingRecipient recipient,
    Site updated,
  ) async {
    final current =
        _recipients
            .where((existing) => existing.id == recipient.id)
            .firstOrNull ??
        await _recipientDao.getById(recipient.id) ??
        recipient;
    _pushUndo([current]);
    final refreshed = await _recipientDao.refreshFromSite(
      current,
      updated,
      preserveRecipientState: true,
    );
    var issues = <MailingAddressValidationIssue>[];
    await BlockingUI().runAndWait(() async {
      issues = await GoogleMapsRouteService().validateRecipients(
        recipients: [refreshed],
      );
    }, label: 'Validating Address');

    final validated = recipientAfterAddressValidation(refreshed, issues);
    await _recipientDao.update(validated);
    await _refreshValidationAttentionState();
    _replaceRecipient(validated);
    if (issues.isEmpty) {
      HMBToast.info('Address validated and recipient selected.');
      return;
    }
    await _showAddressValidationIssues(
      issues,
      title: 'Address still needs attention',
    );
  }

  Future<void> _refreshRecipientFromSite(
    MailingRecipient recipient,
    Site updated,
  ) async {
    final current = _recipients
        .where((existing) => existing.id == recipient.id)
        .firstOrNull;
    if (current != null) {
      _pushUndo([current]);
      final refreshed = await _recipientDao.refreshFromSite(current, updated);
      await _refreshValidationAttentionState();
      _replaceRecipient(refreshed);
    }
  }

  Future<void> _startDelivery() async {
    if (!_hasRoute()) {
      final shouldRoute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Route required'),
          content: const Text(
            'Optimise the delivery route before starting delivery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Optimise Route'),
            ),
          ],
        ),
      );
      if (shouldRoute ?? false) {
        await _optimiseRoute();
      } else {
        return;
      }
      if (!_hasRoute()) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MailingDeliveryScreen(mailingId: widget.mailingId),
      ),
    );
    await _load();
  }

  List<MailingRecipient> _readyRecipients() => _recipients
      .where(
        (recipient) =>
            recipient.selected && recipient.hasAddress && !recipient.excluded,
      )
      .toList();

  Future<List<MailingRecipient>> _validationRecipients() async {
    final validationRecipients = <MailingRecipient>[];
    final seenSiteIds = <int>{};

    for (final recipient in _recipients) {
      if (recipient.excluded) {
        continue;
      }

      if ((recipient.selected && recipient.hasAddress) ||
          (!recipient.hasAddress && recipient.hasPartialAddress)) {
        validationRecipients.add(recipient);
        final siteId = recipient.siteId;
        if (siteId != null) {
          seenSiteIds.add(siteId);
        }
      }

      final sites = await DaoSite().getByCustomer(recipient.customerId);
      for (final site in sites) {
        if (seenSiteIds.contains(site.id)) {
          continue;
        }
        if (!_siteNeedsValidation(site)) {
          continue;
        }
        validationRecipients.add(_recipientForSiteValidation(recipient, site));
        seenSiteIds.add(site.id);
      }
    }

    return validationRecipients;
  }

  bool _siteNeedsValidation(Site site) {
    if (DaoMailingRecipient.hasMailableAddress(site)) {
      return false;
    }
    return _siteHasPartialAddress(site);
  }

  bool _siteHasPartialAddress(Site site) {
    final name = site.name?.trim() ?? '';
    return [
          site.addressLine1,
          site.addressLine2,
          site.suburb,
          site.state,
          site.postcode,
        ].any(Strings.isNotBlank) ||
        RegExp(r'\d').hasMatch(name);
  }

  MailingRecipient _recipientForSiteValidation(
    MailingRecipient recipient,
    Site site,
  ) => recipient.copyWith(
    siteId: site.id,
    siteName: site.name,
    addressLine1: site.addressLine1,
    addressLine2: site.addressLine2,
    suburb: site.suburb,
    state: site.state,
    postcode: site.postcode,
    selected: false,
    clearRoute: true,
  );

  bool _hasRoute() {
    if (!(_mailing?.routeOptimised ?? false)) {
      return false;
    }
    final ready = _readyRecipients();
    return ready.isNotEmpty &&
        (_mailing?.routeOptimised ?? false) &&
        ready.every(
          (recipient) =>
              recipient.routeOrder != null && recipient.routeBatch != null,
        );
  }

  bool get _routeOrderAvailable => _hasRoute();

  void _replaceRecipient(MailingRecipient updated) {
    if (!mounted) {
      return;
    }
    final index = _recipients.indexWhere(
      (recipient) => recipient.id == updated.id,
    );
    if (index == -1) {
      return;
    }
    setState(() => _recipients[index] = updated);
  }

  Future<void> _refreshValidationAttentionState() async {
    final siteIds = await _validationAttentionSiteIdsFor(_recipients);
    if (mounted) {
      setState(() => _validationAttentionSiteIds = siteIds);
    }
  }

  Future<Set<int>> _validationAttentionSiteIdsFor(
    List<MailingRecipient> recipients,
  ) async {
    final siteIds = <int>{};
    for (final recipient in recipients) {
      final siteId = recipient.siteId;
      if (siteId == null) {
        continue;
      }
      final site = await DaoSite().getById(siteId);
      if (site != null && _siteValidationNeedsAttention(site)) {
        siteIds.add(site.id);
      }
    }
    return siteIds;
  }

  bool _siteValidationNeedsAttention(Site site) => {
    'invalid',
    'failed',
    'not_found',
    'invalidated',
    'route_failed',
  }.contains(site.geocodeStatus);

  bool _recipientNeedsAttention(MailingRecipient recipient) {
    if (recipient.excluded) {
      return false;
    }
    if (!recipient.hasAddress) {
      return true;
    }
    final siteId = recipient.siteId;
    return siteId != null && _validationAttentionSiteIds.contains(siteId);
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HMBFilterSheet(
        contentBuilder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => HMBColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: _showExcluded,
                title: const Text('Show excluded recipients'),
                onChanged: (value) {
                  setState(() => _showExcluded = value);
                  setSheetState(() {});
                },
              ),
              const Divider(),
              Text('Sort', style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<_MailingSortOrder>(
                groupValue: _sortOrder,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _sortOrder = value);
                  setSheetState(() {});
                },
                child: HMBColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final order in _MailingSortOrder.values)
                      RadioListTile<_MailingSortOrder>(
                        value: order,
                        enabled:
                            order != _MailingSortOrder.route ||
                            _routeOrderAvailable,
                        title: Text(order.label),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Text('Focus', style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<_MailingIssueFilter>(
                groupValue: _issueFilter,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _issueFilter = value);
                  setSheetState(() {});
                },
                child: HMBColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final filter in _MailingIssueFilter.values)
                      RadioListTile<_MailingIssueFilter>(
                        value: filter,
                        title: Text(filter.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onReset: () => setState(() {
          _showExcluded = false;
          _issueFilter = _MailingIssueFilter.all;
          _sortOrder = _MailingSortOrder.name;
        }),
      ),
    );
  }

  Future<void> _openLabels() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MailingLabelsScreen(mailingId: widget.mailingId),
      ),
    );
    await _load();
  }

  void _toggleNeedsAttentionFilter() {
    setState(() {
      _issueFilter = _issueFilter == _MailingIssueFilter.needsAttention
          ? _MailingIssueFilter.all
          : _MailingIssueFilter.needsAttention;
      _showExcluded = false;
    });
  }

  bool get _isFilterActive =>
      _showExcluded ||
      _issueFilter != _MailingIssueFilter.all ||
      _sortOrder != _MailingSortOrder.name;

  @override
  Widget build(BuildContext context) {
    final mailing = _mailing;
    if (_loading || mailing == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ready = _readyRecipients().length;
    final selected = _recipients
        .where((recipient) => recipient.selected && !recipient.excluded)
        .length;
    final blocked = _recipients.where(_recipientNeedsAttention).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(mailing.name),
        actions: [
          IconButton(
            tooltip: 'Rename mailing',
            icon: const Icon(Icons.edit),
            onPressed: () => unawaited(_renameMailing()),
          ),
        ],
      ),
      body: HMBColumn(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                HMBChip(label: '$ready ready'),
                HMBChip(label: '$selected selected'),
                HMBChip(
                  label: _issueFilter == _MailingIssueFilter.needsAttention
                      ? 'Showing $blocked need checking'
                      : '$blocked need checking',
                  tone: _issueFilter == _MailingIssueFilter.needsAttention
                      ? HMBChipTone.accent
                      : HMBChipTone.warning,
                  icon: Icons.report_problem_outlined,
                  onTap: _toggleNeedsAttentionFilter,
                ),
                HMBButton.smallWithIcon(
                  label: 'All',
                  icon: const Icon(Icons.check_box),
                  hint: 'Select every ready recipient',
                  onPressed: () => unawaited(_setAll(true)),
                ),
                HMBButton.smallWithIcon(
                  label: 'None',
                  icon: const Icon(Icons.check_box_outline_blank),
                  hint: 'Deselect every ready recipient',
                  onPressed: () => unawaited(_setAll(false)),
                ),
                HMBButton.smallWithIcon(
                  label: 'Print...',
                  icon: const Icon(Icons.print),
                  hint: 'Preview and print mailing labels',
                  onPressed: () => unawaited(_openLabels()),
                ),
                HMBButton.smallWithIcon(
                  label: 'Validate',
                  icon: const Icon(Icons.fact_check),
                  hint: 'Check selected delivery addresses before routing',
                  onPressed: () => unawaited(_validateAddresses()),
                ),
                HMBButton.smallWithIcon(
                  label: 'Route',
                  icon: const Icon(Icons.route),
                  hint: 'Optimise the delivery route',
                  onPressed: () => unawaited(_optimiseRoute()),
                ),
                HMBButton.smallWithIcon(
                  label: 'Deliver',
                  icon: const Icon(Icons.navigation),
                  hint: 'Start delivery mode',
                  onPressed: () => unawaited(_startDelivery()),
                ),
                HMBButton.smallWithIcon(
                  label: 'Undo',
                  icon: const Icon(Icons.undo),
                  hint: 'Undo the last mailing recipient action',
                  enabled: _undoStack.isNotEmpty,
                  onPressed: () => unawaited(_undoLastAction()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Contact, customer, or suburb',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: _searchController.clear,
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                HMBFilterIcon(
                  active: _isFilterActive,
                  onPressed: _showFilterSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _visibleRecipients.length,
              itemBuilder: (context, index) => _RecipientTile(
                key: ValueKey(_visibleRecipients[index].id),
                recipient: _visibleRecipients[index],
                showRouteOrder: _routeOrderAvailable,
                onChanged: _toggle,
                onExcludedChanged: _setExcluded,
                onExcludeFromFutureMailings: _excludeFromFutureMailings,
                onSiteChanged: (recipient, site) async {
                  _pushUndo([recipient]);
                  final updated = await _recipientDao.refreshFromSite(
                    recipient,
                    site,
                  );
                  await _refreshValidationAttentionState();
                  _replaceRecipient(updated);
                },
                onSiteEdited: _validateEditedSite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MailingRecipient> get _visibleRecipients {
    final recipients = _sortedRecipients(_searchedRecipients);
    if (_issueFilter != _MailingIssueFilter.all) {
      return recipients;
    }
    if (_showExcluded) {
      return recipients;
    }
    return recipients.where((recipient) => !recipient.excluded).toList();
  }

  List<MailingRecipient> get _searchedRecipients {
    final search = _searchController.text.trim().toLowerCase();
    final recipients = _issueFilteredRecipients;
    if (search.isEmpty) {
      return recipients;
    }
    return recipients
        .where(
          (recipient) =>
              recipient.contactName.toLowerCase().contains(search) ||
              recipient.customerName.toLowerCase().contains(search) ||
              recipient.suburb.toLowerCase().contains(search),
        )
        .toList();
  }

  List<MailingRecipient> get _issueFilteredRecipients => _recipients
      .where(
        (recipient) => switch (_issueFilter) {
          _MailingIssueFilter.all => true,
          _MailingIssueFilter.needsAttention => _recipientNeedsAttention(
            recipient,
          ),
          _MailingIssueFilter.incompleteAddress => !recipient.hasAddress,
          _MailingIssueFilter.unresolvedMultipleAddress =>
            recipient.siteId == null &&
                (_siteCountByCustomerId[recipient.customerId] ?? 0) > 1,
          _MailingIssueFilter.excluded => recipient.excluded,
        },
      )
      .toList();

  List<MailingRecipient> _sortedRecipients(List<MailingRecipient> recipients) {
    final sorted = [...recipients];
    switch (_sortOrder) {
      case _MailingSortOrder.name:
        sorted.sort((a, b) {
          final contact = a.contactName.compareTo(b.contactName);
          if (contact != 0) {
            return contact;
          }
          return a.customerName.compareTo(b.customerName);
        });
      case _MailingSortOrder.route:
        sorted.sort((a, b) {
          final aRoute = a.routeOrder;
          final bRoute = b.routeOrder;
          if (aRoute == null && bRoute == null) {
            return a.contactName.compareTo(b.contactName);
          }
          if (aRoute == null) {
            return 1;
          }
          if (bRoute == null) {
            return -1;
          }
          final batch = (a.routeBatch ?? 0).compareTo(b.routeBatch ?? 0);
          if (batch != 0) {
            return batch;
          }
          return aRoute.compareTo(bRoute);
        });
    }
    return sorted;
  }

  Future<void> _renameMailing() async {
    final mailing = _mailing!;
    final controller = TextEditingController(text: mailing.name);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename Mailing'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mailing name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (Strings.isBlank(name)) {
        return;
      }
      final updated = mailing.copyWith(name: name!.trim());
      await _mailingDao.update(updated);
      if (mounted) {
        setAppTitle(updated.name);
        setState(() => _mailing = updated);
      }
    } finally {
      controller.dispose();
    }
  }
}

class _AppliedAddressSuggestion {
  final MailingAddressValidationIssue issue;
  final int index;
  final MailingRecipient previousRecipient;
  final Site? previousSite;

  const _AppliedAddressSuggestion({
    required this.issue,
    required this.index,
    required this.previousRecipient,
    required this.previousSite,
  });

  _AppliedAddressSuggestion copyWith({
    MailingAddressValidationIssue? issue,
    int? index,
  }) => _AppliedAddressSuggestion(
    issue: issue ?? this.issue,
    index: index ?? this.index,
    previousRecipient: previousRecipient,
    previousSite: previousSite,
  );
}

class _ValidationDialogAction {
  final MailingAddressValidationIssue issue;
  final int index;
  final Future<void> Function() undo;

  const _ValidationDialogAction({
    required this.issue,
    required this.index,
    required this.undo,
  });
}

class MailingAddressValidationIssueTile extends StatefulWidget {
  final MailingAddressValidationIssue issue;
  final Future<void> Function(SuggestedSiteAddress suggestion)?
  onApplySuggestion;
  final Future<void> Function()? onEditManually;
  final Future<void> Function()? onExclude;
  final Future<void> Function()? onNoMail;

  const MailingAddressValidationIssueTile({
    required this.issue,
    required this.onApplySuggestion,
    required this.onEditManually,
    required this.onExclude,
    required this.onNoMail,
    super.key,
  });

  @override
  State<MailingAddressValidationIssueTile> createState() =>
      _MailingAddressValidationIssueTileState();
}

class _MailingAddressValidationIssueTileState
    extends State<MailingAddressValidationIssueTile> {
  var _selectedSuggestionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final recipient = issue.recipient;
    final suggestions = issue.suggestions;
    final suggestion = suggestions.isEmpty
        ? null
        : suggestions[_selectedSuggestionIndex.clamp(
            0,
            suggestions.length - 1,
          )];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipient?.contactName ?? 'Address validation failed',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(issue.message),
        const SizedBox(height: 8),
        if (suggestion == null)
          Text(
            issue.suggestionFailure ??
                'No address suggestion was returned. Check the '
                    'address manually, or confirm the Google '
                    'Address Validation API and Places API (New) are '
                    'enabled.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          Text('Suggested', style: Theme.of(context).textTheme.labelLarge),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: [
                for (var i = 0; i < suggestions.length; i++)
                  _AddressSuggestionChoice(
                    suggestion: suggestions[i],
                    selected: i == _selectedSuggestionIndex,
                    onTap: () => setState(() => _selectedSuggestionIndex = i),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (widget.onApplySuggestion != null && suggestion != null)
          HMBButton.small(
            label: 'Apply Suggestion',
            hint: 'Use this suggested address',
            onPressed: () => widget.onApplySuggestion!(suggestion),
          ),
        if (widget.onEditManually != null)
          HMBButton.small(
            label: 'Edit Manually',
            hint: 'Edit this address manually',
            onPressed: () => widget.onEditManually!(),
          ),
        if (widget.onExclude != null)
          HMBButton.small(
            label: 'Exclude',
            hint: 'Exclude this recipient from this mailing',
            onPressed: () => widget.onExclude!(),
          ),
        if (widget.onNoMail != null)
          HMBButton.small(
            label: 'No Mail',
            hint: 'Exclude this customer from future mailings',
            onPressed: () => widget.onNoMail!(),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _AddressSuggestionChoice extends StatelessWidget {
  final SuggestedSiteAddress suggestion;
  final bool selected;
  final VoidCallback onTap;

  const _AddressSuggestionChoice({
    required this.suggestion,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withSafeOpacity(0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.site.address,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientTile extends StatefulWidget {
  final MailingRecipient recipient;
  final bool showRouteOrder;
  final Future<void> Function(
    MailingRecipient recipient, {
    required bool selected,
    Site? selectedSite,
  })
  onChanged;
  final Future<void> Function(
    MailingRecipient recipient, {
    required bool excluded,
  })
  onExcludedChanged;
  final Future<void> Function(MailingRecipient recipient)
  onExcludeFromFutureMailings;
  final Future<void> Function(MailingRecipient recipient, Site? site)
  onSiteChanged;
  final Future<void> Function(MailingRecipient recipient, Site site)
  onSiteEdited;

  const _RecipientTile({
    required this.recipient,
    required this.showRouteOrder,
    required this.onChanged,
    required this.onExcludedChanged,
    required this.onExcludeFromFutureMailings,
    required this.onSiteChanged,
    required this.onSiteEdited,
    super.key,
  });

  @override
  State<_RecipientTile> createState() => _RecipientTileState();
}

class _RecipientTileState extends State<_RecipientTile> {
  List<Site> _sites = [];
  var _sitesLoaded = false;
  var _applyingSiteChange = false;
  int? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.recipient.siteId;
    unawaited(_loadSites());
  }

  @override
  void didUpdateWidget(covariant _RecipientTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipient.id != widget.recipient.id) {
      _selectedSiteId = widget.recipient.siteId;
      _sites = [];
      _sitesLoaded = false;
      unawaited(_loadSites());
      return;
    }
    if (!_applyingSiteChange) {
      _selectedSiteId = widget.recipient.siteId;
    }
  }

  Future<void> _loadSites() async {
    final sites = await DaoSite().getByCustomer(widget.recipient.customerId);
    final sitesById = <int, Site>{};
    for (final site in sites) {
      sitesById[site.id] = site;
    }
    final uniqueSites = _uniqueSitesForDropdown(sitesById.values);
    if (mounted) {
      setState(() {
        _sites = uniqueSites;
        _sitesLoaded = true;
      });
    }
  }

  List<Site> _uniqueSitesForDropdown(Iterable<Site> sites) {
    final currentSiteId = widget.recipient.siteId;
    final byAddress = <String, Site>{};
    for (final site in sites) {
      final key = _siteDuplicateKey(site);
      final existing = byAddress[key];
      if (existing == null ||
          site.id == currentSiteId ||
          (!_isMailableSite(existing) && _isMailableSite(site))) {
        byAddress[key] = site;
      }
    }
    return byAddress.values.toList();
  }

  String _siteDuplicateKey(Site site) {
    final addressKey = [
      site.addressLine1,
      site.addressLine2,
      site.suburb,
      site.state,
      site.postcode,
    ].map(_normaliseAddressPart).where((part) => part.isNotEmpty).join('|');
    if (addressKey.isNotEmpty) {
      return addressKey;
    }
    return _normaliseAddressPart(site.name ?? '');
  }

  String _normaliseAddressPart(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    final needsAddress = !recipient.hasAddress;
    final selectedSite = _selectedSite(recipient);
    final hasAnySite = _sites.isNotEmpty;
    final hasMultiple = _sites.length > 1;
    final hasMailableSites = _sites.any(_isMailableSite);
    final colorScheme = Theme.of(context).colorScheme;
    final canToggleRecipient = !recipient.excluded && !_applyingSiteChange;
    final color = recipient.excluded
        ? colorScheme.surfaceContainerHighest.withSafeOpacity(0.45)
        : needsAddress
        ? colorScheme.error.withSafeOpacity(0.18)
        : !recipient.selected
        ? colorScheme.surfaceContainerHighest.withSafeOpacity(0.28)
        : null;
    final borderColor = recipient.excluded
        ? colorScheme.outline
        : needsAddress
        ? colorScheme.error.withSafeOpacity(0.65)
        : !recipient.selected
        ? colorScheme.outline.withSafeOpacity(0.75)
        : hasMultiple
        ? colorScheme.primary
        : null;

    return Card(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: recipient.selected,
                  onChanged: !canToggleRecipient
                      ? null
                      : (value) => unawaited(
                          widget.onChanged(
                            recipient,
                            selected: value ?? false,
                            selectedSite: _selectedSite(recipient),
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: !canToggleRecipient
                              ? null
                              : () => unawaited(
                                  widget.onChanged(
                                    recipient,
                                    selected: !recipient.selected,
                                    selectedSite: _selectedSite(recipient),
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(recipient.contactName),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                [
                                      recipient.customerName,
                                      if (recipient.siteName != null)
                                        recipient.siteName!,
                                      recipient.address,
                                    ]
                                    .where((part) => part.trim().isNotEmpty)
                                    .join(' - '),
                              ),
                            ),
                            if (selectedSite != null)
                              HMBEditIcon(
                                key: ValueKey(
                                  'mailing-recipient-edit-${recipient.id}',
                                ),
                                hint: 'Edit delivery address',
                                onPressed: () =>
                                    _editSelectedSite(recipient, selectedSite),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_sitesLoaded && hasAnySite && _sites.length != 1)
              DropdownButtonFormField<int>(
                key: ValueKey(
                  '${recipient.id}-${_selectedMailableSiteId(recipient)}',
                ),
                initialValue: _selectedMailableSiteId(recipient),
                focusColor: colorScheme.primary.withSafeOpacity(0.24),
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(child: Text('Choose address')),
                  for (final site in _sites)
                    DropdownMenuItem<int>(
                      value: site.id,
                      enabled: _isMailableSite(site),
                      child: Text(
                        _siteMenuLabel(site),
                        style: !_isMailableSite(site)
                            ? TextStyle(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w800,
                              )
                            : null,
                      ),
                    ),
                ],
                onChanged: (siteId) async {
                  final site = _sites
                      .where((site) => site.id == siteId)
                      .firstOrNull;
                  if (site != null && !_isMailableSite(site)) {
                    HMBToast.error(
                      'Choose an address with a street number and suburb.',
                    );
                    return;
                  }
                  setState(() => _applyingSiteChange = true);
                  try {
                    await widget.onSiteChanged(recipient, site);
                    if (mounted) {
                      setState(() => _selectedSiteId = siteId);
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _applyingSiteChange = false);
                    }
                  }
                },
              ),
            Wrap(
              spacing: 8,
              children: [
                if (needsAddress && recipient.hasPartialAddress)
                  const HMBChip(label: 'Invalid address'),
                if (needsAddress &&
                    !recipient.hasPartialAddress &&
                    hasMailableSites)
                  const HMBChip(label: 'No address selected'),
                if (needsAddress &&
                    !recipient.hasPartialAddress &&
                    !hasMailableSites)
                  const HMBChip(label: 'No address available'),
                if (hasMultiple) const HMBChip(label: 'Multiple addresses'),
                if (widget.showRouteOrder && recipient.routeOrder != null)
                  HMBChip(label: 'Stop ${recipient.routeOrder! + 1}'),
                if (recipient.contactId == null)
                  const HMBChip(label: 'No primary contact'),
                HMBChip(
                  label: recipient.excluded
                      ? 'Excluded'
                      : recipient.deliveryStatus.display,
                ),
                HMBButton.smallWithIcon(
                  label: recipient.excluded ? 'Restore' : 'Exclude',
                  icon: Icon(
                    recipient.excluded
                        ? Icons.undo
                        : Icons.remove_circle_outline,
                  ),
                  hint: recipient.excluded
                      ? 'Restore this recipient to the mailing'
                      : 'Exclude this recipient from labels and delivery',
                  onPressed: () => unawaited(
                    widget.onExcludedChanged(
                      recipient,
                      excluded: !recipient.excluded,
                    ),
                  ),
                ),
                if (!recipient.excluded)
                  HMBButton.smallWithIcon(
                    label: 'No Mail',
                    icon: const Icon(Icons.unsubscribe),
                    hint: 'Exclude this customer from all future mailing lists',
                    onPressed: () => unawaited(
                      widget.onExcludeFromFutureMailings(recipient),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isMailableSite(Site site) =>
      DaoMailingRecipient.hasMailableAddress(site);

  Site? _selectedSite(MailingRecipient recipient) {
    final selectedSiteId = _selectedSiteId ?? recipient.siteId;
    final selected = _sites
        .where((site) => site.id == selectedSiteId)
        .firstOrNull;
    if (selected != null) {
      return selected;
    }
    if (_sites.length == 1) {
      return _sites.single;
    }
    return null;
  }

  int? _selectedMailableSiteId(MailingRecipient recipient) {
    final site = _selectedSite(recipient);
    if (site == null || !_isMailableSite(site)) {
      return null;
    }
    return site.id;
  }

  String _siteLabel(Site site) {
    final hasAddressLine = MailingRecipient.hasSpecificAddressLine(
      site.addressLine1,
    );
    final hasSuburb = Strings.isNotBlank(site.suburb);
    final address = _siteAddressSummary(site);
    final name = site.name?.trim();
    if (!hasAddressLine || !hasSuburb) {
      final label = Strings.isNotBlank(name) ? name! : address;
      return '${Strings.isBlank(label) ? 'Unnamed site' : label} '
          '(${_siteInvalidReason(site)})';
    }
    if (Strings.isNotBlank(name)) {
      return '$name - $address';
    }
    return address;
  }

  String _siteMenuLabel(Site site) {
    if (_isMailableSite(site)) {
      return _siteLabel(site);
    }
    return 'INVALID ADDRESS - ${_siteAddressText(site)} '
        '(${_siteInvalidReason(site)})';
  }

  String _siteAddressText(Site site) {
    final name = site.name?.trim();
    final address = _siteAddressSummary(site);
    if (Strings.isNotBlank(address)) {
      return address;
    }
    if (Strings.isNotBlank(name)) {
      return name!;
    }
    return 'Unnamed site';
  }

  String _siteAddressSummary(Site site) =>
      joinAddressParts([site.addressLine1, site.suburb, site.postcode]);

  String _siteInvalidReason(Site site) {
    final missing = [
      if (Strings.isBlank(site.addressLine1))
        'address line'
      else if (!MailingRecipient.hasSpecificAddressLine(site.addressLine1))
        'street number',
      if (Strings.isBlank(site.suburb)) 'suburb',
    ];
    return 'missing ${Strings.join(missing, separator: ' and ')}';
  }

  Future<void> _editSelectedSite(
    MailingRecipient recipient,
    Site selectedSite,
  ) async {
    final customer = await DaoCustomer().getById(recipient.customerId);
    final site = await DaoSite().getById(selectedSite.id);
    if (!mounted) {
      return;
    }
    if (customer == null || site == null) {
      HMBToast.error('Unable to edit this delivery address.');
      return;
    }
    await Navigator.push<Site>(
      context,
      MaterialPageRoute<Site>(
        builder: (context) => SiteEditScreen<Customer>(
          parent: customer,
          daoJoin: JoinAdaptorCustomerSite(),
          site: site,
        ),
      ),
    );
    final updated = await DaoSite().getById(site.id);
    if (updated == null) {
      return;
    }
    await _loadSites();
    await widget.onSiteEdited(recipient, updated);
  }
}

MailingRecipient recipientAfterAddressValidation(
  MailingRecipient recipient,
  List<MailingAddressValidationIssue> issues,
) => recipient.copyWith(
  selected: issues.isEmpty && !recipient.excluded,
  clearRoute: true,
);
