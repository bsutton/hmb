import 'package:flutter/material.dart';

import '../message_template_dialog.dart';
import 'contact_name.dart';
import 'contact_source.dart';
import 'customer_name.dart';
import 'customer_source.dart';
import 'date_holder.dart';
import 'date_source.dart';
import 'delay_period.dart';
import 'delay_source.dart';
import 'job_cost.dart';
import 'job_descripion.dart';
import 'job_source.dart';
import 'job_summary.dart';
import 'place_holder.dart';
import 'site_holder.dart';
import 'site_source.dart';
import 'text_holder.dart';
import 'time_holder.dart';
import 'time_source.dart';

class PlaceHolderManager {
  factory PlaceHolderManager() {
    placeHolderManager ??= PlaceHolderManager._internal();

    return placeHolderManager!;
  }

  PlaceHolderManager._internal() {
    customerSource = CustomerSource();
    jobSource = JobSource(customerSource: customerSource);
    siteSource = SiteSource();
    contactSource = ContactSource();
    // Initialize placeholders
    placeholders[JobCost.tagName] = JobCost(jobSource: jobSource);
    placeholders[JobDescription.tagName] = JobDescription(jobSource: jobSource);
    placeholders[JobSummary.tagName] = JobSummary(jobSource: jobSource);
    placeholders[CustomerName.tagName] =
        CustomerName(customerSource: customerSource);
    placeholders[ContactName.tagName] =
        ContactName(contactSource: contactSource);
    placeholders[DelayPeriod.tagName] = DelayPeriod(DelaySource());
    placeholders[AppointmentTime.tagName] =
        AppointmentTime(TimeSource(AppointmentTime.label));
    placeholders[AppointmentDate.tagName] =
        AppointmentDate(DateSource(AppointmentDate.label));
    placeholders[DueDate.tagName] = DueDate(DateSource(DueDate.label));
    placeholders[OriginalDate.tagName] =
        OriginalDate(DateSource(OriginalDate.label));
    placeholders[ServiceDate.tagName] =
        ServiceDate(DateSource(ServiceDate.label));
    placeholders[SiteHolder.tagName] = SiteHolder(siteSource);
    placeholders[SignatureHolder.tagName] = SignatureHolder();
  }
  static PlaceHolderManager? placeHolderManager;
  late final CustomerSource customerSource;
  late final JobSource jobSource;
  late final ContactSource contactSource;
  late final SiteSource siteSource;

  final Map<String, PlaceHolder<dynamic, dynamic>> placeholders = {};

  List<Widget> buildFields(MessageData data) => [
        customerSource.widget(data),
        jobSource.widget(data),
        // Add fields for other sources in the correct order
      ];

  // ignore: strict_raw_type
  Future<PlaceHolder?> resolvePlaceholder(
          String name, MessageData data) async =>
      placeholders[name];
}
