import 'package:flutter/material.dart';

import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_date_time_picker.dart';
import '../../widgets/select/select_manufacture.dart';
import '../../widgets/select/select_supplier.dart';
import '../../widgets/wizard_step.dart';
import '../category/select_category.dart';

class ToolDetailsStep extends WizardStep {
  ToolDetailsStep({
    required super.title,
  });

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  final TextEditingController warrantyPeriodController =
      TextEditingController();
  final TextEditingController costController = TextEditingController();

  final selectedSupplier = SelectedSupplier();
  final selectedManufacturer = SelectedManufacturer();
  final selectedCategory = SelectedCategory();
  DateTime selectedDatePurchased = DateTime.now();

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
                  controller: serialNumberController,
                  labelText: 'Serial Number',
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
