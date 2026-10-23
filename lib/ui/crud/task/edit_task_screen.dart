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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/foundation.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao_task.dart';
import '../../../dao/task_fixed_agreement.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/exceptions.dart';
import '../../../util/dart/money_ex.dart';
import '../../../util/flutter/platform_ex.dart';
import '../../invoicing/create_invoice_ui.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/fields/hmb_money_editing_controller.dart';
import '../../widgets/fields/hmb_money_field.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_crud_checklist_item.dart';
import '../../widgets/hmb_switch.dart';
import '../../widgets/icons/help_button.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../base_nested/edit_nested_screen.dart';
import '../base_nested/list_nested_screen.dart';
import '../category/select_category.dart';
import 'photo_crud.dart';

class TaskEditScreen extends StatefulWidget {
  final Job job;
  final Task? task;
  late final BillingType? billingType;

  TaskEditScreen({required this.job, super.key, this.task}) {
    // Use explicit task override only.
    // null means "Inherited" from job billing type.
    billingType = task?.billingType;
  }

  @override
  // ignore: library_private_types_in_public_api
  _TaskEditScreenState createState() => _TaskEditScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Task?>('task', task));
  }
}

class _TaskEditScreenState extends DeferredState<TaskEditScreen>
    implements NestedEntityState<Task> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _assumptionController;
  late PhotoController<Task> _photoController;
  late FocusNode _summaryFocusNode;
  late FocusNode _descriptionFocusNode;
  late FocusNode _assumptionFocusNode;
  final _category = SelectedCategory();
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _effortNotesController;

  @override
  Task? currentEntity;
  BillingType? selectedBillingType;
  final _fixedPrice = HMBMoneyEditingController();
  final _agreementNote = TextEditingController();
  var _agreed = false;
  var _hadAgreement = false;

  @override
  Future<void> asyncInitState() async {
    currentEntity ??= widget.task;
    selectedBillingType = widget.billingType;
    _category.categoryId = currentEntity?.categoryId;
    _quantityController = TextEditingController(
      text: currentEntity?.effortQuantity?.toString() ?? '',
    );
    _unitController = TextEditingController(text: currentEntity?.effortUnit);
    _effortNotesController = TextEditingController(
      text: currentEntity?.effortNotes,
    );

    _nameController = TextEditingController(text: currentEntity?.name);
    _descriptionController = TextEditingController(
      text: currentEntity?.description,
    );
    _assumptionController = TextEditingController(
      text: currentEntity?.assumption,
    );

    _photoController = PhotoController<Task>(
      parent: currentEntity,
      parentType: ParentType.task,
    );

    _summaryFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();
    _assumptionFocusNode = FocusNode();

    if (isNotMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_summaryFocusNode);
      });
    }

    await _loadInitialTaskStatus();
    if (currentEntity != null) {
      final agreement = await TaskFixedAgreement().get(currentEntity!.id);
      if (agreement != null) {
        _fixedPrice.money = MoneyEx.fromInt(agreement['amount']! as int);
        _agreementNote.text = agreement['agreement_note']! as String;
        _agreed = true;
        _hadAgreement = true;
      }
    }
  }

  Future<void> _loadInitialTaskStatus() async {
    TaskStatus? taskStatus;
    if (currentEntity?.status != null) {
      taskStatus = currentEntity?.status;
    }
    taskStatus ??= TaskStatus.awaitingApproval;

    setState(() {
      June.getState(SelectedTaskStatus.new).taskStatus = taskStatus;
    });
  }

  @override
  void dispose() {
    _fixedPrice.dispose();
    _agreementNote.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _assumptionController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _effortNotesController.dispose();
    _photoController.dispose();
    _summaryFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _assumptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => Text('Unable to load task: $error'),
    builder: (_) => NestedEntityEditScreen<Task, Job>(
      entityName: 'Task',
      dao: DaoTask(),
      onInsert: (task, transaction) async {
        await _insertTask(task!, transaction);
      },
      entityState: this,
      editor: (task) => HMBFormSection(
        children: [
          HMBTextField(
            controller: _nameController,
            focusNode: _summaryFocusNode,
            labelText: 'Summary',
            required: true,
          ),
          _chooseTaskStatus(task),
          _chooseBillingType(),
          if ((selectedBillingType ?? widget.job.billingType) ==
              BillingType.fixedPrice)
            HMBFormSection(
              children: [
                HMBMoneyField(
                  controller: _fixedPrice,
                  labelText: 'Agreed fixed price (optional)',
                  fieldName: 'fixed price',
                  nonZero: false,
                  onChanged: (_) => setState(() => _agreed = false),
                ),
                if (_fixedPrice.text.isNotEmpty || _hadAgreement) ...[
                  HMBSwitch(
                    labelText: 'Customer agreed to this price',
                    initialValue: _agreed,
                    leadingSpace: false,
                    onChanged: (value) => setState(() => _agreed = value),
                  ),
                  HMBTextField(
                    controller: _agreementNote,
                    labelText: 'Agreement note (optional)',
                  ),
                  Builder(
                    builder: (saveContext) => HMBButton(
                      label: 'Save and prepare invoice',
                      hint: 'Save the agreed task and review its invoice',
                      enabled: _agreed,
                      onPressed: () async {
                        final task = await BlockingUI().runAndWait(
                          () => ParentSaveScope.maybeOf(
                            saveContext,
                          )!.ensureSaved(),
                        );
                        if (task != null && saveContext.mounted) {
                          await createInvoiceFor(
                            widget.job,
                            saveContext,
                            taskId: task.id,
                          );
                        }
                      },
                    ),
                  ),
                ],
                const Text(
                  'Record an on-site agreement here, or leave the price blank '
                  'and prepare a formal quote. '
                  'Enter the final customer price, including any tax.',
                ),
              ],
            ),
          ExpansionTile(
            title: const Text('Effort comparison'),
            subtitle: const Text('Optional details for future estimating'),
            children: [
              SelectCategory(selectedCategory: _category),
              HMBTextField(
                controller: _quantityController,
                labelText: 'Work quantity (e.g. 25)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final quantity = double.tryParse(value);
                  return quantity == null || !quantity.isFinite || quantity <= 0
                      ? 'Enter a positive quantity'
                      : null;
                },
              ),
              HMBTextField(
                controller: _unitController,
                labelText: 'Unit (e.g. m², metres, items)',
                validator: (value) =>
                    _quantityController.text.trim().isNotEmpty &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the unit used for this quantity'
                    : null,
              ),
              HMBTextArea(
                controller: _effortNotesController,
                labelText: 'Comparison notes (size, condition, access)',
              ),
              const Text(
                'Internal comparison only. These values do not change billing '
                'or appear on quotes.',
              ),
            ],
          ),
          HMBTextArea(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            labelText: 'Description',
          ),
          HMBTextArea(
            controller: _assumptionController,
            focusNode: _assumptionFocusNode,
            labelText: 'Assumptions',
          ).help(
            'Assumptions',
            '''Detail the assumptions your pricing is based on. Assumptions are shown on the Quote. ''',
          ),
          // _chooseBillingType(),
          _buildItemList(task),
          PhotoCrud<Task>(
            parentName: 'Task',
            allowPendingPhotos: true,
            parentType: ParentType.task,
            controller: _photoController,
          ),
        ],
      ),
    ),
  );

  Widget _buildItemList(Task? task) => Flexible(
    child: SingleChildScrollView(
      child: HMBColumn(
        mainAxisSize: MainAxisSize.min,
        children: [HMBCrudTaskItem(task: task)],
      ),
    ),
  );

  final inheritedOption = BillingTypeOption(null, "Same as job's");

  Widget _chooseBillingType() =>
      HMBDroplist<BillingTypeOption>(
        title: 'Billing Type',

        // Items include "Inherited" + actual BillingType values
        items: (filter) async => [
          inheritedOption,
          ...BillingType.values.map((bt) => BillingTypeOption(bt, bt.display)),
        ],

        // Which value is selected?
        selectedItem: () async => selectedBillingType == null
            ? inheritedOption
            : BillingTypeOption(
                selectedBillingType,
                selectedBillingType!.display,
              ),

        // Save back: null means inherited
        onChanged: (selected) {
          selectedBillingType = selected?.type; // will be null for inherited
          setState(() {});
        },

        // Display text
        format: (opt) => opt.label,
      ).help('Billing Type', '''
Time and Materials (Cost Plus)

Bill the customer based on hours tracked and Task Items purchased.
You can progressively invoice the customer during the Job.

Navigate to Billing | Invoices

Fixed Price
Bills the customer a pre-agreed amount.

You can create Milestone Invoices as the Job progresses.
Use an agreed task price or a formal quote, then Create invoice.
''');

  Widget _chooseTaskStatus(Task? task) => HMBDroplist<TaskStatus>(
    title: 'Task Status',
    selectedItem: () async => June.getState(SelectedTaskStatus.new).taskStatus,
    items: (filter) async => TaskStatus.getByFilter(filter),
    format: (item) => item.name,
    onChanged: (item) {
      setState(() {
        June.getState(SelectedTaskStatus.new).taskStatus = item;
      });
    },
  );

  Future<void> _insertTask(Task task, Transaction transaction) async {
    await DaoTask().insert(task, transaction);
    _photoController.parent = task;
  }

  @override
  Future<Task> forUpdate(Task task) async => task.copyWith(
    jobId: widget.job.id,
    name: _nameController.text,
    billingType: selectedBillingType ?? widget.job.billingType,
    description: _descriptionController.text,
    assumption: _assumptionController.text,
    status: June.getState(SelectedTaskStatus.new).taskStatus,
    categoryId: _category.categoryId,
    clearCategory: _category.categoryId == null,
    effortQuantity: double.tryParse(_quantityController.text.trim()),
    clearEffortQuantity: _quantityController.text.trim().isEmpty,
    effortUnit: _unitController.text.trim(),
    effortNotes: _effortNotesController.text.trim(),
  );

  @override
  Future<Task> forInsert() async => Task.forInsert(
    jobId: widget.job.id,
    name: _nameController.text,
    billingType: selectedBillingType ?? widget.job.billingType,
    description: _descriptionController.text,
    assumption: _assumptionController.text,
    status: June.getState(SelectedTaskStatus.new).taskStatus!,
    categoryId: _category.categoryId,
    effortQuantity: double.tryParse(_quantityController.text.trim()),
    effortUnit: _unitController.text.trim(),
    effortNotes: _effortNotesController.text.trim(),
  );

  @override
  void refresh() {
    setState(() {});
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {
    if ((selectedBillingType ?? widget.job.billingType) ==
            BillingType.fixedPrice &&
        (_fixedPrice.text.isNotEmpty || _hadAgreement)) {
      final amount = _fixedPrice.money;
      if (!_agreed || amount == null || !amount.isPositive) {
        throw InvoiceException(
          'Enter the fixed price and confirm the customer agreed.',
        );
      }
      await TaskFixedAgreement().save(
        transaction,
        currentEntity!,
        amount,
        _agreementNote.text,
      );
    }
    final pending = (await _photoController.photos)
        .where((meta) => meta.photo.id == -1)
        .toList();
    try {
      await _photoController.savePendingPhotos(transaction: transaction);
      await _photoController.save(transaction: transaction);
    } catch (_) {
      // The enclosing task transaction rolls back; keep draft photos retryable.
      for (final meta in pending) {
        meta.photo.id = -1;
      }
      if (operation == Operation.insert) {
        _photoController.parent = null;
      }
      rethrow;
    }
  }
}

class SelectedTaskStatus extends JuneState {
  TaskStatus? _taskStatus;

  TaskStatus? get taskStatus => _taskStatus;

  set taskStatus(TaskStatus? value) {
    _taskStatus = value;
    setState();
  }
}

class BillingTypeOption {
  final BillingType? type;
  final String label;

  BillingTypeOption(this.type, this.label);
}
