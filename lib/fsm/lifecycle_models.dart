class LifecycleContext {
  final String source;
  final String? reason;
  final String? actorId;
  final DateTime requestedAt;
  final String correlationId;

  LifecycleContext({
    required this.source,
    this.reason,
    this.actorId,
    DateTime? requestedAt,
    String? correlationId,
  }) : requestedAt = requestedAt ?? DateTime.now(),
       correlationId = correlationId ?? _newCorrelationId();

  static String _newCorrelationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'lifecycle-$now';
  }
}

class LifecycleResult<T> {
  final T entity;
  final String event;
  final String from;
  final String to;
  final bool changed;

  const LifecycleResult({
    required this.entity,
    required this.event,
    required this.from,
    required this.to,
    required this.changed,
  });
}

class LifecycleException implements Exception {
  final String message;

  const LifecycleException(this.message);

  @override
  String toString() => message;
}

class LifecycleAction {
  final Type eventType;
  final String label;
  final String hint;
  final bool requiresConfirmation;

  const LifecycleAction({
    required this.eventType,
    required this.label,
    required this.hint,
    this.requiresConfirmation = false,
  });
}
