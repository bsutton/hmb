/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system_credentials.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class GoogleMapsIntegrationScreen extends StatefulWidget {
  const GoogleMapsIntegrationScreen({super.key});

  @override
  State<GoogleMapsIntegrationScreen> createState() =>
      _GoogleMapsIntegrationScreenState();
}

class _GoogleMapsIntegrationScreenState
    extends State<GoogleMapsIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    setAppTitle('Google Maps Integration');
    unawaited(_load());
  }

  Future<void> _load() async {
    final credentials = await DaoSystem().getGoogleMapsCredentials();
    if (!mounted) {
      return;
    }
    setState(() => _apiKeyController.text = credentials.apiKey ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<bool> _save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
    await DaoSystem().updateGoogleMapsCredentials(
      GoogleMapsCredentials(apiKey: _apiKeyController.text.trim()),
    );
    if (mounted) {
      HMBToast.info('saved');
      if (close) {
        context.go('/home/settings/integrations');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HMBColumn(
      children: [
        SaveAndClose(
          onSave: _save,
          showSaveOnly: false,
          onCancel: () async => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: HMBColumn(
                  children: [
                    const Text(
                      'Store a Google Maps Platform API key to enable '
                      'delivery route optimisation for mailings. Enable the '
                      'Routes API for route planning and the Address '
                      'Validation API plus Places API (New) for address '
                      'validation and suggestions. Do not use Route '
                      'Optimization API.',
                    ),
                    const HMBSpacer(height: true),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Google Maps API Key',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
