class LifecycleTransition {
  final int id;
  final String aggregateType;
  final int aggregateId;
  final int jobId;
  final String event;
  final String fromState;
  final String toState;
  final String source;
  final String? reason;
  final String? actorId;
  final String correlationId;
  final DateTime occurredAt;

  const LifecycleTransition({
    required this.id,
    required this.aggregateType,
    required this.aggregateId,
    required this.jobId,
    required this.event,
    required this.fromState,
    required this.toState,
    required this.source,
    required this.correlationId,
    required this.occurredAt,
    this.reason,
    this.actorId,
  });

  factory LifecycleTransition.fromMap(Map<String, Object?> map) =>
      LifecycleTransition(
        id: map['id']! as int,
        aggregateType: map['aggregate_type']! as String,
        aggregateId: map['aggregate_id']! as int,
        jobId: map['job_id']! as int,
        event: map['event']! as String,
        fromState: map['from_state']! as String,
        toState: map['to_state']! as String,
        source: map['source']! as String,
        reason: map['reason'] as String?,
        actorId: map['actor_id'] as String?,
        correlationId: map['correlation_id']! as String,
        occurredAt: DateTime.parse(map['occurred_at']! as String),
      );
}
