/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_manufacturer.dart';
import '../../../entity/manufacturer.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_manufacturer_screen.dart';

class ManufacturerListScreen extends StatelessWidget {
  const ManufacturerListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Manufacturer>(
    pageTitle: 'Manufacturers',
    dao: DaoManufacturer(),
    title: (entity) => HMBTextHeadline2(entity.name),
    // ignore: discarded_futures
    fetchList: (filter) => DaoManufacturer().getByFilter(filter),
    onEdit: (manufacturer) =>
        ManufacturerEditScreen(manufacturer: manufacturer),
    details: (entity) {
      final manufacturer = entity;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBTextBody(manufacturer.description ?? ''),
          if (manufacturer.contactNumber != null)
            HMBTextBody('Contact: ${manufacturer.contactNumber}'),
          if (manufacturer.email != null)
            HMBTextBody('Email: ${manufacturer.email}'),
          if (manufacturer.address != null)
            HMBTextBody('Address: ${manufacturer.address}'),
        ],
      );
    },
  );
}
