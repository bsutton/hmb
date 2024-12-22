import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../util/app_title.dart';
import '../widgets/hmb_button.dart';
import 'billing_page.dart';
import 'business_page.dart';
import 'contact_page.dart';
import 'integration_page.dart';

class FirstRunWizard extends StatefulWidget {
  const FirstRunWizard({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FirstRunWizardState createState() => _FirstRunWizardState();
}

class _FirstRunWizardState extends State<FirstRunWizard> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    setAppTitle('HMB Setup Wizard');
  }

  Future<void> _nextStep() async {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Finish wizard
      } else {
        context.go('/jobs');
      }
    }
  }

  Future<void> _skipStep() async {
    await _nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      WizardBusinessPage(onNext: _nextStep),
      WizardBillingPage(onNext: _nextStep),
      WizardContactPage(onNext: _nextStep),
      WizardIntegrationPage(onNext: _skipStep),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          HMBButton(
            label: 'Skip All',
            onPressed: _skipStep,
          ),
        ],
      ),
      body: screens[_currentStep],
    );
  }
}
