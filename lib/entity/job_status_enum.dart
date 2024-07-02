enum JobStatusEnum {
  finalised,
  preStart,
  progressing,
  onHold,
}

extension JobStatusEnumExtension on JobStatusEnum {
  String get name {
    switch (this) {
      case JobStatusEnum.finalised:
        return 'finalised';
      case JobStatusEnum.preStart:
        return 'preStart';
      case JobStatusEnum.progressing:
        return 'progressing';
      case JobStatusEnum.onHold:
        return 'onHold';
    }
  }

  static JobStatusEnum fromName(String name) {
    switch (name) {
      case 'finalised':
        return JobStatusEnum.finalised;
      case 'preStart':
        return JobStatusEnum.preStart;
      case 'progressing':
        return JobStatusEnum.progressing;
      case 'onHold':
        return JobStatusEnum.onHold;
      default:
        throw ArgumentError('Invalid job status name');
    }
  }
}
