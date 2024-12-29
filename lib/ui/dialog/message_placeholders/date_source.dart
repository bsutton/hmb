import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/local_date.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../message_template_dialog.dart';
import 'source.dart';

class DateSource extends Source<LocalDate> {
  DateSource(this.label) : super(name: 'date');

  final String label;

  LocalDate? date;

  @override
  Widget widget(MessageData data) =>

      /// Date placeholder drop list

      HMBDateTimeField(
        showTime: false,
        label: label.toProperCase(),
        initialDateTime: DateTime.now(),
        onChanged: (datetime) {
          date = LocalDate.fromDateTime(datetime);
          // placeholder.setValue(localTime);
          // controller.text = '${datetime.day}/${datetime.month}/${datetime.year}';
          // placeholder.onChanged?.call(localTime, ResetFields());
        },
        showDate: false,
      );

  //  HMBDroplist<Site>(
  //       title: 'Site',
  //       selectedItem: () async => value,
  //       items: (filter) async {
  //         if (dateSource.value != null) {
  //           return DaoSite().getByCustomer(customer?.id);
  //         } else {
  //           return [];
  //         }
  //       },
  //       format: (site) => site.address,
  //       onChanged: setValue,
  //     );
}

// /// Site placeholder drop list
// PlaceHolderField<Site> _buildSiteDroplist(
//     SiteHolder siteHolder, MessageData data) {
//   final droplist = HMBDroplist<Site>(
//     title: siteHolder.name.toCapitalised(),
//     selectedItem: () async => siteHolder.site = data.site,
//     items: (filter) async {
//       if (data.customer != null) {
//         // Fetch sites associated with the selected customer
//         return DaoSite().getByFilter(data.customer!.id, filter);
//       } else {
//         // Fetch all sites
//         return DaoSite().getAll();
//       }
//     },
//     format: (site) => site.address,
//     onChanged: (site) {
//       siteHolder.site = site;
//       siteHolder.onChanged?.call(site, ResetFields());
//     },
//   );
//   return PlaceHolderField<Site>(
//     placeholder: siteHolder,
//     widget: droplist,
//     getValue: (data) async => siteHolder.value(data),
//   );
