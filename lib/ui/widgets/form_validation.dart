import 'package:flutter/material.dart';

import 'hmb_toast.dart';

bool validateFormAndRevealErrors(
  GlobalKey<FormState> formKey, {
  String message = 'Fix the highlighted fields before continuing.',
}) {
  final formState = formKey.currentState;
  if (formState == null) {
    return false;
  }

  final valid = formState.validate();
  if (!valid) {
    HMBToast.error(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealFirstInvalidField(formKey.currentContext);
    });
  }
  return valid;
}

void _revealFirstInvalidField(BuildContext? formContext) {
  if (formContext == null) {
    return;
  }

  final firstInvalidField = _findFirstInvalidField(formContext as Element);
  if (firstInvalidField == null || !firstInvalidField.mounted) {
    return;
  }

  Scrollable.ensureVisible(
    firstInvalidField,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    alignment: 0.1,
  );

  final focusNode = _findFirstFocusable(firstInvalidField as Element);
  if (focusNode != null && focusNode.canRequestFocus) {
    focusNode.requestFocus();
  }
}

BuildContext? _findFirstInvalidField(Element root) {
  BuildContext? firstInvalidField;

  void visit(Element element) {
    if (firstInvalidField != null) {
      return;
    }

    if (element is StatefulElement) {
      final state = element.state;
      if (state is FormFieldState && state.hasError) {
        firstInvalidField = element;
        return;
      }
    }

    element.visitChildElements(visit);
  }

  root.visitChildElements(visit);
  return firstInvalidField;
}

FocusNode? _findFirstFocusable(Element root) {
  FocusNode? firstFocusable;

  void visit(Element element) {
    if (firstFocusable != null) {
      return;
    }

    if (element.widget is Focus) {
      final focusNode = Focus.maybeOf(element);
      if (focusNode != null && focusNode.canRequestFocus) {
        firstFocusable = focusNode;
        return;
      }
    }

    element.visitChildElements(visit);
  }

  root.visitChildElements(visit);
  return firstFocusable;
}
