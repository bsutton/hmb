/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../../util/measurement_type.dart';
import '../../util/money_ex.dart';
import '../../util/units.dart';
import 'fields/hmb_text_field.dart';
import 'hmb_button.dart';
import 'select/hmb_droplist.dart';
import 'text/hmb_text_themes.dart';

enum AddType { packing, shopping }

Future<void> showAddItemDialog(BuildContext context, AddType addType) async {
  Job? selectedJob;
  Task? selectedTask;
  TaskItemTypeEnum? selectedItemType;
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
              HMBDroplist<Job>(
                title: 'Select Job',
                selectedItem: () async => selectedJob,
                items: (filter) => DaoJob().getActiveJobs(filter),
                format: (job) => job.summary,
                onChanged: (job) {
                  setState(() {
                    selectedJob = job;
                    selectedTask = null; // Reset task selection
                  });
                },
              ),
              const SizedBox(height: 10),
              // Task Selection Dropdown (dependent on selected job)
              if (selectedJob != null)
                HMBDroplist<Task>(
                  title: 'Select Task',
                  selectedItem: () async => selectedTask,
                  items: (filter) => DaoTask().getTasksByJob(selectedJob!.id),
                  format: (task) => task.name,
                  onChanged: (task) {
                    setState(() {
                      selectedTask = task;
                    });
                  },
                ),
              const SizedBox(height: 10),
              // Item Type Selection Dropdown
              HMBDroplist<TaskItemTypeEnum>(
                title: 'Item Type',
                selectedItem: () async => selectedItemType,
                items: (filter) async => [
                  ...switch (addType) {
                    AddType.shopping => [
                      TaskItemTypeEnum.toolsBuy,
                      TaskItemTypeEnum.materialsBuy,
                    ],
                    AddType.packing => [
                      TaskItemTypeEnum.toolsOwn,
                      TaskItemTypeEnum.materialsStock,
                    ],
                  },
                ],
                format: (type) => type.description,
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
              selectedJob: selectedJob,
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
  required Job? selectedJob,
  required Task? selectedTask,
  required TaskItemTypeEnum? selectedItemType,
  required TextEditingController quantityController,
  required TextEditingController unitCostController,
  required TextEditingController descriptionController,
  required TextEditingController purposeController,
  required BuildContext context,
}) async {
  if (selectedJob != null && selectedTask != null && selectedItemType != null) {
    final quantity = Fixed.tryParse(quantityController.text) ?? Fixed.one;
    final unitCost = MoneyEx.tryParse(unitCostController.text);

    // Create and insert the new TaskItem
    final newItem = TaskItem.forInsert(
      taskId: selectedTask.id,
      description: descriptionController.text,
      purpose: purposeController.text,
      itemTypeId: selectedItemType.id,
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
