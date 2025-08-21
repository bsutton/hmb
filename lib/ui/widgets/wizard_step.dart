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

import 'text/hmb_text_themes.dart';
import 'wizard.dart';

abstract class WizardStep {
  final GlobalKey key;
  final String _title;

  WizardState? wizardState;

  /// if [hidden] returns true then the step will not be shown
  /// in the set of steps.
  /// You can hide/unhide steps in a wizard to change the steps
  /// shown to a user based on a selection they make whilst in the
  /// wizard. If you change the 'hidden' state of a step you
  /// need to call [setState] to force the wizard to redraw.
  // ignore: omit_obvious_property_types
  bool hidden = false;

  WizardStep({required String title}) : _title = title, key = GlobalKey();

  Widget build(BuildContext context);

  ///
  /// Overload this method to change how the heading is formatted.
  /// By default we use TextNJSubheading.
  Widget get title => HMBTextHeadline3(_title);

  /// Overload this method and return false
  /// if you want the wizard to skip over this step.
  ///
  /// The step will still be displayed in the set of steps
  /// but the wizard will stop the user selecting it
  /// and the wizard will skip over it.
  bool get isActive => true;

  void setState(VoidCallback fn) {
    wizardState?.refresh(fn);
  }

  ///
  /// Controls whether a step can be skipped over
  /// if a user clicks on a later step.
  ///
  /// If [canSkip] returns true then wizard will
  /// allow a user to jump forward without showing this
  /// step. This means that the [onEntry] and [onNext]
  /// methods will not be called for this step.
  ///
  /// If [canSkip] returns false then any attempt to jump
  /// forward will result in the first step that returns false
  /// becoming the new active step. The [onEntry]
  /// methods will be called for this step.
  ///
  /// By default we return false and no step can be skipped.
  ///
  bool canSkip(BuildContext context) => false;

  ///
  /// Called as the wizard transitions to a new step but before
  /// the new step is displayed.
  /// [priorStep] gives you access to the step that is was
  /// being displayed before the transition commenced.
  /// You can veto the transition by calling [self].cancel or call
  /// [self].redirect to set an alternate step to move to.
  ///
  /// If you override this method you MUST call [self.confirm()]
  /// , [self.cancel()] or [self.redirect(alternateStep)] otherwise
  /// the UI will lock up.
  Future<void> onEntry(
    BuildContext context,
    WizardStep priorStep,
    WizardStepTarget self, {
    required bool userOriginated,
  }) async {
    self.confirm();
  }

  /// Called against the current step as the wizard is about to transitions
  ///  forward to a new step.
  /// [intendedStep] is the step the wizard is transitioning to.
  /// You can veto the transition by calling [intendedStep].cancel or call
  /// [intendedStep].redirect to set an alternate step to move to.
  Future<void> onNext(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    intendedStep.confirm();
  }

  /// Called against the current as the wizard is about to
  ///  transitions backwards to a new step.
  /// [intendedStep] is the step the wizard is transitioning to.
  /// You can veto the transition by calling [intendedStep].cancel or call
  /// [intendedStep].redirect to set an alternate step to move to.
  Future<void> onPrev(
    BuildContext context,
    WizardStepTarget intendedStep, {
    required bool userOriginated,
  }) async {
    intendedStep.confirm();
  }

  void reorderStep({required WizardStep move, required WizardStep after}) {
    wizardState?.reorderStep(move: move, after: after);
  }

  /// overload to dispose of resource when the steps are destroyed.
  void dispose() {}
}
