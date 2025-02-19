import 'package:flutter/material.dart';

import '../source_context.dart';
import 'contact_name.dart';
import 'contact_source.dart';
import 'customer_name.dart';
import 'customer_source.dart';
import 'date_holder.dart';
import 'date_source.dart';
import 'delay_period.dart';
import 'delay_source.dart';
import 'job_activity_holder.dart';
import 'job_activity_source.dart';
import 'job_cost.dart';
import 'job_descripion.dart';
import 'job_source.dart';
import 'job_summary.dart';
import 'place_holder.dart';
import 'site_holder.dart';
import 'site_source.dart';
import 'text_holder.dart';

class PlaceHolderManager {
  factory PlaceHolderManager() {
    placeHolderManager ??= PlaceHolderManager._internal();

    return placeHolderManager!;
  }

  PlaceHolderManager._internal() {
    customerSource = CustomerSource();
    jobSource = JobSource();
    siteSource = SiteSource();
    contactSource = ContactSource();
    jobActivitySource = JobActivitySource();

    // Initialize placeholders

    /// Job
    placeholders[JobCost.tagName] = JobCost(jobSource: jobSource);
    placeholders[JobDescription.tagName] = JobDescription(jobSource: jobSource);
    placeholders[JobSummary.tagName] = JobSummary(jobSource: jobSource);

    // Customer
    placeholders[CustomerName.tagName] = CustomerName(
      customerSource: customerSource,
    );

    // Contact
    placeholders[ContactName.tagName] = ContactName(
      contactSource: contactSource,
    );

    // Delay
    placeholders[DelayPeriod.tagName] = DelayPeriod(delaySource: DelaySource());

    // Job Activity
    placeholders[JobActivityTime.tagName] = JobActivityTime(
      source: jobActivitySource,
    );
    placeholders[JobActivityDate.tagName] = JobActivityDate(
      source: jobActivitySource,
    );
    placeholders[OriginalDate.tagName] = OriginalDate(
      dateSource: DateSource(label: OriginalDate.label),
    );

    // Invoice
    placeholders[DueDate.tagName] = DueDate(
      dateSource: DateSource(label: DueDate.label),
    );

    /// Service Date - is this no really just job activity
    /// or do we leave if someone doesn't use job activityes.
    placeholders[ServiceDate.tagName] = ServiceDate(
      dateSource: DateSource(label: ServiceDate.label),
    );

    /// Site
    placeholders[SiteHolder.tagName] = SiteHolder(siteSource: siteSource);

    /// Signature
    placeholders[SignatureHolder.tagName] = SignatureHolder();
  }
  static PlaceHolderManager? placeHolderManager;
  late final CustomerSource customerSource;
  late final JobSource jobSource;
  late final ContactSource contactSource;
  late final SiteSource siteSource;
  late final JobActivitySource jobActivitySource;

  final Map<String, PlaceHolder<dynamic>> placeholders = {};

  List<Widget> buildFields(SourceContext data) => [
    customerSource.widget(),
    jobSource.widget(),
    // Add fields for other sources in the correct order
  ];

  // ignore: strict_raw_type
  Future<PlaceHolder?> resolvePlaceholder(
    String name,
    SourceContext data,
  ) async => placeholders[name];
}
