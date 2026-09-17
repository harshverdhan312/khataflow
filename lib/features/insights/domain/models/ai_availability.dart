/// Represents the operational availability state of optional AI capabilities.
enum AIAvailabilityStatus {
  /// AI service is configured and ready for generation requests.
  available,

  /// AI service is temporarily unreachable or network connectivity is absent.
  unavailable,

  /// AI capabilities are explicitly disabled by user/system settings.
  disabled,

  /// AI service lacks required endpoint or gateway configuration.
  unconfigured,
}

/// Immutable value object representing AI availability state and reason.
class AIAvailability {
  final AIAvailabilityStatus status;
  final String? message;

  const AIAvailability({
    required this.status,
    this.message,
  });

  const AIAvailability.available()
      : status = AIAvailabilityStatus.available,
        message = null;

  const AIAvailability.unavailable([String? reason])
      : status = AIAvailabilityStatus.unavailable,
        message = reason ?? 'AI insights are temporarily unavailable offline.';

  const AIAvailability.disabled([String? reason])
      : status = AIAvailabilityStatus.disabled,
        message = reason ?? 'AI insights are disabled.';

  const AIAvailability.unconfigured([String? reason])
      : status = AIAvailabilityStatus.unconfigured,
        message = reason ?? 'AI service is not configured.';

  bool get isAvailable => status == AIAvailabilityStatus.available;
  bool get isUnavailable => status == AIAvailabilityStatus.unavailable;
  bool get isDisabled => status == AIAvailabilityStatus.disabled;
  bool get isUnconfigured => status == AIAvailabilityStatus.unconfigured;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIAvailability &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          message == other.message;

  @override
  int get hashCode => Object.hash(status, message);

  @override
  String toString() => 'AIAvailability(status: $status, message: $message)';
}
