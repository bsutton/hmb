/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: library_private_types_in_public_api

import 'package:sqflite_common/sqlite_api.dart';

import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../dao_contact.dart';
import '../dao_contact_customer.dart';
import '../dao_job.dart';
import 'dao_join_adaptor.dart';

class JoinAdaptorCustomerContact implements DaoJoinAdaptor<Contact, Customer> {
  @override
  Future<void> deleteFromParent(Contact contact, Customer customer) async {
    await DaoContactCustomer().deleteJoin(customer, contact);

    for (final job in await DaoJob().getByCustomer(customer)) {
      if (job.contactId == contact.id) {
        job.contactId = null;
        await DaoJob().update(job);
      }
      await DaoContact().delete(contact.id);
    }
  }

  @override
  Future<List<Contact>> getByParent(Customer? parent) =>
      DaoContact().getByCustomer(parent?.id);

  @override
  Future<void> insertForParent(
    Contact contact,
    Customer customer,
    Transaction transaction,
  ) async {
    await DaoContact().insertForCustomer(contact, customer, transaction);
  }

  @override
  Future<void> setAsPrimary(Contact child, Customer parent) async {
    await DaoContactCustomer().setAsPrimary(child, parent);
  }
}
