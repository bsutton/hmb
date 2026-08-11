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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../entity/helpers/charge_mode.dart';
import '../../util/dart/measurement_type.dart';
import '../../util/dart/units.dart';
import '../task_items/material_price_editor.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/select.g.dart';
import '../widgets/text/hmb_text_themes.dart';

enum AddType { packing, shopping }

Future<void> showAddItemDialog(BuildContext context, AddType addType) async {
  final selectedJob = SelectedJob();
  Task? selectedTask;
  TaskItemType? selectedItemType;
  final descriptionController = TextEditingController();
  final purposeController = TextEditingController();
  final priceController = MaterialPriceEditingController(
    price: addType == AddType.shopping
        ? MaterialPrice.items(
            quantity: Fixed.one,
            unitCost: Money.fromInt(0, isoCode: 'AUD'),
          )
        : null,
  );
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: addType == AddType.shopping
            ? const HMBTextHeadline('Add Shopping Item')
            : const HMBTextHeadline('Add Packing Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: HMBColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Job Selection Dropdown
                HMBSelectJob(
                  title: 'Select Job',
                  selectedJob: selectedJob,
                  required: true,
                  items: (filter) => DaoJob().getActiveJobs(filter),
                  onSelected: (job) {
                    setState(() {
                      selectedJob.jobId = job?.id;
                      selectedTask = null; // Reset task selection
                    });
                  },
                ),
                // Task Selection Dropdown (dependent on selected job)
                if (selectedJob.jobId != null)
                  HMBDroplist<Task>(
                    title: 'Select Task',
                    selectedItem: () async => selectedTask,
                    items: (filter) =>
                        DaoTask().getTasksByJob(selectedJob.jobId!),
                    format: (task) => task.name,
                    onChanged: (task) {
                      setState(() {
                        selectedTask = task;
                      });
                    },
                  ),
                // Item Type Selection Dropdown
                HMBDroplist<TaskItemType>(
                  title: 'Item Type',
                  selectedItem: () async => selectedItemType,
                  items: (filter) async => [
                    ...switch (addType) {
                      AddType.shopping => [
                        TaskItemType.materialsBuy,
                        TaskItemType.consumablesBuy,
                        TaskItemType.toolsBuy,
                        TaskItemType.toolsHire,
                      ],
                      AddType.packing => [
                        TaskItemType.materialsStock,
                        TaskItemType.consumablesStock,
                        TaskItemType.toolsOwn,
                      ],
                    },
                  ],
                  format: (type) => type.label,
                  onChanged: (type) {
                    setState(() {
                      selectedItemType = type;
                    });
                  },
                ),
                // Description Input
                HMBTextField(
                  controller: descriptionController,
                  labelText: 'Description',
                  required: true,
                ),
                // Purpose Input
                HMBTextField(
                  controller: purposeController,
                  labelText: 'Purpose',
                ),
                MaterialPriceEditor(controller: priceController),
              ],
            ),
          ),
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            hint: "Don't add this task Item",
          ),
          HMBButton(
            label: 'Add',
            hint: 'Add this item',
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              unawaited(
                _addTaskItem(
                  selectedJobId: selectedJob.jobId,
                  selectedTask: selectedTask,
                  selectedItemType: selectedItemType,
                  priceController: priceController,
                  descriptionController: descriptionController,
                  purposeController: purposeController,
                  context: context,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _addTaskItem({
  required int? selectedJobId,
  required Task? selectedTask,
  required TaskItemType? selectedItemType,
  required MaterialPriceEditingController priceController,
  required TextEditingController descriptionController,
  required TextEditingController purposeController,
  required BuildContext context,
}) async {
  if (selectedJobId != null &&
      selectedTask != null &&
      selectedItemType != null) {
    final description = descriptionController.text.trim();
    final price = priceController.value;
    if (price == null) {
      return;
    }
    final defaultMargin = await DaoSystem().getDefaultProfitMargin();

    // Create and insert the new TaskItem
    final newItem = TaskItem.forInsert(
      taskId: selectedTask.id,
      description: description,
      purpose: purposeController.text.trim(),
      itemType: selectedItemType,
      estimatedPrice: price,
      chargeMode: ChargeMode.calculated,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      labourEntryMode: LabourEntryMode.hours,
      margin: defaultMargin,
      measurementType: MeasurementType.length,
      units: Units.defaultUnits,
      url: '',
    );

    await DaoTaskItem().insert(newItem);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
