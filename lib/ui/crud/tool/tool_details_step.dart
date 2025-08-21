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
import 'package:strings/strings.dart';

import '../../../dao/dao_tool.dart';
import '../../../entity/tool.dart';
import '../../../util/money_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/select/hmb_select_manufacture.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import '../category/select_category.dart';
import 'stock_take_wizard.dart';

class ToolDetailsStep extends WizardStep {
  final ToolWizardState toolWizardState;
  final Money? cost;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final warrantyPeriodController = TextEditingController();
  final costController = TextEditingController();

  final selectedSupplier = SelectedSupplier();
  final selectedManufacturer = SelectedManufacturer();
  final selectedCategory = SelectedCategory();
  var _selectedDatePurchased = DateTime.now();

  ToolDetailsStep(
    this.toolWizardState, {
    required String? name,
    required this.cost,
  }) : super(title: 'Tool Details') {
    nameController.text = name ?? '';
    costController.text = cost?.toString() ?? '';
  }

  @override
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    if (Strings.isBlank(nameController.text)) {
      HMBToast.error('You must enter a name');
      intendedStep.cancel();
      return;
    }
    if (selectedCategory.categoryId == null) {
      HMBToast.error('You must select a Category');
      intendedStep.cancel();
      return;
    }
    final daoTool = DaoTool();
    if (toolWizardState.tool == null) {
      final tool = Tool.forInsert(
        name: nameController.text,
        description: descriptionController.text,
        categoryId: selectedCategory.categoryId,
        supplierId: selectedSupplier.selected,
        manufacturerId: selectedManufacturer.manufacturerId,
        datePurchased: _selectedDatePurchased,
        warrantyPeriod: int.tryParse(warrantyPeriodController.text),
        cost: MoneyEx.tryParse(costController.text),
      );
      await daoTool.insert(tool);
      toolWizardState.tool = tool;
    } else {
      final tool = toolWizardState.tool!.copyWith(
        name: nameController.text,
        description: descriptionController.text,
        categoryId: selectedCategory.categoryId,
        supplierId: selectedSupplier.selected,
        manufacturerId: selectedManufacturer.manufacturerId,
        datePurchased: _selectedDatePurchased,
        warrantyPeriod: int.tryParse(warrantyPeriodController.text),
        cost: MoneyEx.tryParse(costController.text),
      );
      await daoTool.update(tool);
      toolWizardState.tool = tool;
    }
    // ignore: use_build_context_synchronously
    return super.onNext(context, intendedStep, userOriginated: userOriginated);
  }

  @override
  Widget build(BuildContext context) => Material(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            HMBTextField(
              controller: nameController,
              labelText: 'Name',
              required: true,
            ),
            SelectCategory(
              selectedCategory: selectedCategory,
              onSelected: (category) {
                setState(() {
                  selectedCategory.categoryId = category?.id;
                });
              },
            ),
            HMBTextArea(
              controller: descriptionController,
              labelText: 'Description',
            ),
            HMBSelectSupplier(
              selectedSupplier: selectedSupplier,
              onSelected: (supplier) {
                setState(() {
                  selectedSupplier.selected = supplier?.id;
                });
              },
            ),
            HMBSelectManufacturer(
              selectedManufacturer: selectedManufacturer,
              onSelected: (manufacturer) {
                setState(() {
                  selectedManufacturer.manufacturerId = manufacturer?.id;
                });
              },
            ),
            HMBTextField(
              controller: warrantyPeriodController,
              labelText: 'Warranty Period (months)',
              keyboardType: TextInputType.number,
            ),
            HMBTextField(
              controller: costController,
              labelText: 'Cost',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            HMBDateTimeField(
              mode: HMBDateTimeFieldMode.dateOnly,
              label: 'Date Purchased',
              initialDateTime: _selectedDatePurchased,
              onChanged: (date) => _selectedDatePurchased = date,
            ),
          ],
        ),
      ),
    ),
  );
}
