import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

import '../../../dao/dao_tool.dart';
import '../../../entity/tool.dart';
import '../../../util/money_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/select/select_manufacture.dart';
import '../../widgets/select/select_supplier.dart';
import '../../widgets/wizard.dart';
import '../../widgets/wizard_step.dart';
import '../category/select_category.dart';
import 'stock_take_wizard.dart';

class ToolDetailsStep extends WizardStep {
  ToolDetailsStep(this.toolWizardState,
      {required this.name, required this.cost})
      : super(title: 'Details') {
    nameController.text = name ?? '';
    costController.text = cost?.toString() ?? '';
  }

  final ToolWizardState toolWizardState;
  final String? name;
  final Money? cost;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController warrantyPeriodController =
      TextEditingController();
  final TextEditingController costController = TextEditingController();

  final selectedSupplier = SelectedSupplier();
  final selectedManufacturer = SelectedManufacturer();
  final selectedCategory = SelectedCategory();
  DateTime selectedDatePurchased = DateTime.now();

  @override
  Future<void> onNext(BuildContext context, WizardStepTarget intendedStep,
      {required bool userOriginated}) async {
    final daoTool = DaoTool();
    if (toolWizardState.tool == null) {
      final tool = Tool.forInsert(
          name: nameController.text,
          description: descriptionController.text,
          categoryId: selectedCategory.categoryId,
          supplierId: selectedSupplier.selected,
          manufacturerId: selectedManufacturer.manufacturerId,
          datePurchased: selectedDatePurchased,
          warrantyPeriod: int.tryParse(warrantyPeriodController.text),
          cost: MoneyEx.tryParse(costController.text));
      await daoTool.insert(tool);
      toolWizardState.tool = tool;
    } else {
      final tool = toolWizardState.tool!.copyWith(
          name: nameController.text,
          description: descriptionController.text,
          categoryId: selectedCategory.categoryId,
          supplierId: selectedSupplier.selected,
          manufacturerId: selectedManufacturer.manufacturerId,
          datePurchased: selectedDatePurchased,
          warrantyPeriod: int.tryParse(warrantyPeriodController.text),
          cost: MoneyEx.tryParse(costController.text));
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
                SelectSupplier(
                  selectedSupplier: selectedSupplier,
                  onSelected: (supplier) {
                    setState(() {
                      selectedSupplier.selected = supplier?.id;
                    });
                  },
                ),
                SelectManufacturer(
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                HMBDateTimeField(
                  showTime: false,
                  label: 'Date Purchased',
                  initialDateTime: selectedDatePurchased,
                  onChanged: (date) => selectedDatePurchased = date,
                ),
              ],
            ),
          ),
        ),
      );
}
