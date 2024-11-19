import 'package:flutter/material.dart';

import '../job_source.dart';
import '../message_template_dialog.dart';
import 'customer_holder.dart';
import 'customer_source.dart';
import 'job_cost.dart';
import 'job_descripion.dart';
import 'place_holder.dart';

class PlaceHolderManager {
  final CustomerSource customerSource;
  final JobSource jobSource;

  final Map<String, PlaceHolder> placeholders = {};

  PlaceHolderManager()
      : customerSource = CustomerSource(),
        jobSource = JobSource(customerSource: CustomerSource()) {
    // Initialize placeholders
    placeholders['job.cost'] = JobCost(jobSource: jobSource);
    placeholders['job.description'] = JobDescription(jobSource: jobSource);
    placeholders['customer.name'] = CustomerName(customerSource: customerSource);
    // Add more placeholders as needed
  }

  List<Widget> buildFields(MessageData data) {
    return [
      customerSource.field(data),
      jobSource.field(data),
      // Add fields for other sources in the correct order
    ];
  }

  Future<String> resolvePlaceholder(String name, MessageData data) async {
    final placeholder = placeholders[name];
    if (placeholder != null) {
      return await placeholder.value(data);
    } else {
      return '';
    }
  }
}
