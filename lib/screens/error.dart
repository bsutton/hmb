import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({required this.errorMessage, super.key});

  ErrorScreen.fromException(Exception exception, StackTrace stackTrace,
      {super.key})
      : errorMessage = exception.toString() {
    /// report error to sentry.
    unawaited(Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    ));
  }
  final String errorMessage;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
}

class FullScreenDialog extends StatelessWidget {
  const FullScreenDialog(
      {required this.title, required this.content, super.key});
  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: content,
      );
}
