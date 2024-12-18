import 'package:flutter/material.dart';

import '../../util/app_title.dart';
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

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.of(context).pop(); // Finish wizard
    }
  }

  void _skipStep() {
    _nextStep();
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
          TextButton(
            onPressed: _skipStep,
            child:
                const Text('Skip All', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: screens[_currentStep],
    );
  }
}
