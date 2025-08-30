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

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/measurement_type.dart';
import '../../util/dart/money_ex.dart';
import '../../util/dart/units.dart';
import 'fields/hmb_text_field.dart';
import 'hmb_button.dart';
import 'select/select.g.dart';
import 'text/hmb_text_themes.dart';

enum AddType { packing, shopping }

Future<void> showAddItemDialog(BuildContext context, AddType addType) async {
  final selectedJob = SelectedJob();
  Task? selectedTask;
  TaskItemType? selectedItemType;
  final descriptionController = TextEditingController();
  final purposeController = TextEditingController();
  final quantityController = TextEditingController();
  final unitCostController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: addType == AddType.shopping
            ? const HMBTextHeadline('Add Shopping Item')
            : const HMBTextHeadline('Add Packing Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Job Selection Dropdown
              HMBSelectJob(
                title: 'Select Job',
                selectedJob: selectedJob,
                items: (filter) => DaoJob().getActiveJobs(filter),
                onSelected: (job) {
                  setState(() {
                    selectedJob.jobId = job?.id;
                    selectedTask = null; // Reset task selection
                  });
                },
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              // Description Input
              HMBTextField(
                controller: descriptionController,
                labelText: 'Description',
              ),
              // Purpose Input
              HMBTextField(controller: purposeController, labelText: 'Purpose'),
              // Quantity Input
              HMBTextField(
                controller: quantityController,
                labelText: 'Quantity',
                keyboardType: TextInputType.number,
              ),
              // Unit Cost Input
              HMBTextField(
                controller: unitCostController,
                labelText: 'Unit Cost',
                keyboardType: TextInputType.number,
              ),
            ],
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
            onPressed: () => _addTaskItem(
              selectedJobId: selectedJob.jobId,
              selectedTask: selectedTask,
              selectedItemType: selectedItemType,
              quantityController: quantityController,
              unitCostController: unitCostController,
              descriptionController: descriptionController,
              purposeController: purposeController,
              context: context,
            ),
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
  required TextEditingController quantityController,
  required TextEditingController unitCostController,
  required TextEditingController descriptionController,
  required TextEditingController purposeController,
  required BuildContext context,
}) async {
  if (selectedJobId != null &&
      selectedTask != null &&
      selectedItemType != null) {
    final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
    final unitCost = MoneyEx.tryParse(unitCostController.text);

    // Create and insert the new TaskItem
    final newItem = TaskItem.forInsert(
      taskId: selectedTask.id,
      description: descriptionController.text,
      purpose: purposeController.text,
      itemType: selectedItemType,
      estimatedMaterialQuantity: quantity,
      estimatedMaterialUnitCost: unitCost,
      dimension1: Fixed.zero,
      dimension2: Fixed.zero,
      dimension3: Fixed.zero,
      labourEntryMode: LabourEntryMode.hours,
      margin: Percentage.zero,
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
