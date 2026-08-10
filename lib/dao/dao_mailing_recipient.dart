/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import '../entity/contact.dart';
import '../entity/customer.dart';
import '../entity/mailing_recipient.dart';
import '../entity/site.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_customer.dart';
import 'dao_job.dart';
import 'dao_site.dart';

class MailingCandidate {
  final Customer customer;
  final Contact? primaryContact;
  final List<Site> sites;

  MailingCandidate({
    required this.customer,
    required this.primaryContact,
    required this.sites,
  });

  bool get hasMultipleSites => sites.length > 1;
  bool get hasAddress =>
      sites.isNotEmpty && DaoMailingRecipient.hasMailableAddress(sites.first);
}

class DaoMailingRecipient extends Dao<MailingRecipient> {
  static const tableName = 'mailing_recipient';

  DaoMailingRecipient() : super(tableName);

  @override
  MailingRecipient fromMap(Map<String, dynamic> map) =>
      MailingRecipient.fromMap(map);

  Future<List<MailingRecipient>> getByMailing(int mailingId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'mailing_id = ?',
        whereArgs: [mailingId],
        orderBy: 'contact_name, customer_name, id',
      ),
    );
  }

  Future<List<MailingRecipient>> getRouteReady(int mailingId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: '''
mailing_id = ?
and selected = 1
and excluded = 0
and site_id is not null
and trim(address_line_1) != ''
and address_line_1 glob '*[0-9]*'
and trim(suburb) != ''
''',
        whereArgs: [mailingId],
        orderBy: 'route_batch, route_order, contact_name, customer_name',
      ),
    );
  }

  Future<void> deselectUnmailableRecipients(int mailingId) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {
        'selected': 0,
        'route_order': null,
        'route_batch': null,
        'modifiedDate': DateTime.now().toIso8601String(),
      },
      where: '''
mailing_id = ?
and selected = 1
and (
  site_id is null
  or trim(address_line_1) = ''
  or trim(suburb) = ''
)
''',
      whereArgs: [mailingId],
    );
    Dao.notifier(this);
  }

  Future<List<MailingCandidate>> getCandidates() async {
    final customers = await DaoCustomer().getByFilter(null);
    final stockCustomerId = (await DaoJob().getStockJob())?.customerId;
    final candidates = <MailingCandidate>[];
    for (final customer in customers.where(
      (customer) =>
          !customer.disbarred &&
          !customer.excludeFromMailings &&
          customer.id != stockCustomerId,
    )) {
      candidates.add(
        MailingCandidate(
          customer: customer,
          primaryContact: await DaoContact().getPrimaryForCustomer(customer.id),
          sites: await DaoSite().getByCustomer(customer.id),
        ),
      );
    }
    return candidates;
  }

  Future<void> populateForMailing(int mailingId) async {
    final candidates = await getCandidates();
    await withTransaction((transaction) async {
      for (final candidate in candidates) {
        final site = candidate.sites.length == 1 ? candidate.sites.first : null;
        final hasAddress = site != null && hasMailableAddress(site);
        final contact = candidate.primaryContact;
        final contactName = (contact?.fullname.trim().isNotEmpty ?? false)
            ? contact!.fullname.trim()
            : candidate.customer.name;
        await insert(
          MailingRecipient.forInsert(
            mailingId: mailingId,
            customerId: candidate.customer.id,
            contactId: contact?.id,
            siteId: site?.id,
            contactName: contactName,
            customerName: candidate.customer.name,
            siteName: site?.name,
            addressLine1: site?.addressLine1 ?? '',
            addressLine2: site?.addressLine2 ?? '',
            suburb: site?.suburb ?? '',
            state: site?.state ?? '',
            postcode: site?.postcode ?? '',
            selected: hasAddress,
          ),
          transaction,
        );
      }
    });
  }

  Future<MailingRecipient> refreshFromSite(
    MailingRecipient recipient,
    Site? site, {
    bool preserveRecipientState = false,
  }) async {
    final hasAddress = site != null && hasMailableAddress(site);
    final updated = recipient.copyWith(
      siteId: site?.id,
      siteName: site?.name,
      addressLine1: site?.addressLine1 ?? '',
      addressLine2: site?.addressLine2 ?? '',
      suburb: site?.suburb ?? '',
      state: site?.state ?? '',
      postcode: site?.postcode ?? '',
      selected: preserveRecipientState
          ? hasAddress && recipient.selected
          : hasAddress,
      excluded: preserveRecipientState && recipient.excluded,
      clearRoute: true,
      clearSite: site == null,
    );
    await update(updated);
    return updated;
  }

  Future<void> setAllSelected({
    required int mailingId,
    required bool selected,
  }) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {
        'selected': selected ? 1 : 0,
        'route_order': null,
        'route_batch': null,
        'modifiedDate': DateTime.now().toIso8601String(),
      },
      where: '''
mailing_id = ?
and excluded = 0
and site_id is not null
and trim(address_line_1) != ''
and trim(suburb) != ''
''',
      whereArgs: [mailingId],
    );
    Dao.notifier(this);
  }

  Future<void> saveRouteOrder(List<MailingRecipient> recipients) async {
    await withTransaction((transaction) async {
      for (var i = 0; i < recipients.length; i++) {
        await update(
          recipients[i].copyWith(routeBatch: 0, routeOrder: i),
          transaction,
        );
      }
    });
  }

  Future<void> clearRouteOrder(int mailingId) async {
    final db = withoutTransaction();
    await db.update(
      tableName,
      {
        'route_order': null,
        'route_batch': null,
        'modifiedDate': DateTime.now().toIso8601String(),
      },
      where: 'mailing_id = ?',
      whereArgs: [mailingId],
    );
    Dao.notifier(this);
  }

  Future<void> updateDeliveryStatus(
    MailingRecipient recipient,
    MailingDeliveryStatus status,
  ) async {
    final now = DateTime.now();
    await update(
      recipient.copyWith(
        deliveryStatus: status,
        deliveredAt: status == MailingDeliveryStatus.delivered ? now : null,
        skippedAt: status == MailingDeliveryStatus.skipped ? now : null,
        clearDeliveredAt: status != MailingDeliveryStatus.delivered,
        clearSkippedAt: status != MailingDeliveryStatus.skipped,
      ),
    );
  }

  static bool hasMailableAddress(Site site) =>
      MailingRecipient.hasSpecificAddressLine(site.addressLine1) &&
      site.suburb.trim().isNotEmpty;
}
