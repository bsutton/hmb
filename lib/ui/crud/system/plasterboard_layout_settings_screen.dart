import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../util/dart/app_settings.dart';
import '../../../util/dart/plaster_layout_scoring.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/save_and_close.dart';

class PlasterboardLayoutSettingsScreen extends StatefulWidget {
  const PlasterboardLayoutSettingsScreen({super.key});

  @override
  State<PlasterboardLayoutSettingsScreen> createState() =>
      _PlasterboardLayoutSettingsScreenState();
}

class _PlasterboardLayoutSettingsScreenState
    extends DeferredState<PlasterboardLayoutSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _extraSheetController;
  late TextEditingController _jointLengthController;
  late TextEditingController _cutPieceController;
  late TextEditingController _buttJointController;
  late TextEditingController _highJointController;
  late TextEditingController _smallPieceController;
  late TextEditingController _fragmentationController;
  late TextEditingController _verticalWallPenaltyController;

  @override
  Future<void> asyncInitState() async {
    final scoring = await AppSettings.getPlasterLayoutScoring();
    _extraSheetController = TextEditingController(
      text: '${scoring.extraSheetWeight}',
    );
    _jointLengthController = TextEditingController(
      text: '${scoring.jointLengthWeight}',
    );
    _cutPieceController = TextEditingController(
      text: '${scoring.cutPieceWeight}',
    );
    _buttJointController = TextEditingController(
      text: '${scoring.buttJointWeight}',
    );
    _highJointController = TextEditingController(
      text: '${scoring.highJointWeight}',
    );
    _smallPieceController = TextEditingController(
      text: '${scoring.smallPieceWeight}',
    );
    _fragmentationController = TextEditingController(
      text: '${scoring.fragmentationWeight}',
    );
    _verticalWallPenaltyController = TextEditingController(
      text: '${scoring.verticalWallPenaltyWeight}',
    );
  }

  @override
  void dispose() {
    _extraSheetController.dispose();
    _jointLengthController.dispose();
    _cutPieceController.dispose();
    _buttJointController.dispose();
    _highJointController.dispose();
    _smallPieceController.dispose();
    _fragmentationController.dispose();
    _verticalWallPenaltyController.dispose();
    super.dispose();
  }

  String? _validateInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Enter a whole number >= 0';
    }
    return null;
  }

  Future<bool> _save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
    await AppSettings.setPlasterLayoutScoring(
      PlasterLayoutScoring(
        extraSheetWeight: int.parse(_extraSheetController.text.trim()),
        jointLengthWeight: int.parse(_jointLengthController.text.trim()),
        buttJointWeight: int.parse(_buttJointController.text.trim()),
        cutPieceWeight: int.parse(_cutPieceController.text.trim()),
        highJointWeight: int.parse(_highJointController.text.trim()),
        smallPieceWeight: int.parse(_smallPieceController.text.trim()),
        fragmentationWeight: int.parse(_fragmentationController.text.trim()),
        verticalWallPenaltyWeight: int.parse(
          _verticalWallPenaltyController.text.trim(),
        ),
      ),
    );
    if (close && mounted) {
      context.pop();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Plasterboard Layout Scoring'),
        actions: [
          SaveAndClose(
            onSave: _save,
            showSaveOnly: true,
            onCancel: () async => context.pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Higher weights make the optimizer care more about that '
                'installation cost compared with raw material waste.',
              ),
              const Text(
                'Butt-joint and vertical-wall penalties bias the search '
                'toward easier-to-install landscape wall layouts.',
              ),
              HMBTextField(
                controller: _extraSheetController,
                labelText: 'Extra sheet weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _jointLengthController,
                labelText: 'Joint length weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _cutPieceController,
                labelText: 'Cut piece weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _buttJointController,
                labelText: 'Butt joint weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _highJointController,
                labelText: 'High joint weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _smallPieceController,
                labelText: 'Small piece weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _fragmentationController,
                labelText: 'Fragmentation weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
              HMBTextField(
                controller: _verticalWallPenaltyController,
                labelText: 'Vertical wall penalty weight',
                keyboardType: TextInputType.number,
                validator: _validateInt,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
