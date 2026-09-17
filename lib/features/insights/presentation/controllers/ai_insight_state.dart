import '../../domain/models/ai_insight.dart';
import '../../domain/models/ai_request_type.dart';

/// Enum representing the state of AI insight generation.
enum AIInsightStatus {
  initial,
  loading,
  success,
  error,
  empty,
}

/// Immutable state model representing the current state of AI insight interactions.
class AIInsightState {
  final AIInsightStatus status;
  final AIRequestType? requestType;
  final AIInsight? insight;
  final String? errorMessage;
  final String? internalErrorType;

  const AIInsightState({
    this.status = AIInsightStatus.initial,
    this.requestType,
    this.insight,
    this.errorMessage,
    this.internalErrorType,
  });

  const AIInsightState.initial()
      : status = AIInsightStatus.initial,
        requestType = null,
        insight = null,
        errorMessage = null,
        internalErrorType = null;

  const AIInsightState.loading({
    required this.requestType,
    AIInsight? previousInsight,
  })  : status = AIInsightStatus.loading,
        insight = previousInsight,
        errorMessage = null,
        internalErrorType = null;

  const AIInsightState.success({
    required this.requestType,
    required this.insight,
  })  : status = AIInsightStatus.success,
        errorMessage = null,
        internalErrorType = null;

  const AIInsightState.error({
    required this.requestType,
    required this.errorMessage,
    this.internalErrorType,
    AIInsight? previousInsight,
  })  : status = AIInsightStatus.error,
        insight = previousInsight;

  const AIInsightState.empty({
    required this.requestType,
    required String message,
  })  : status = AIInsightStatus.empty,
        insight = null,
        errorMessage = message,
        internalErrorType = null;

  bool get isInitial => status == AIInsightStatus.initial;
  bool get isLoading => status == AIInsightStatus.loading;
  bool get isSuccess => status == AIInsightStatus.success;
  bool get isError => status == AIInsightStatus.error;
  bool get isEmpty => status == AIInsightStatus.empty;

  AIInsightState copyWith({
    AIInsightStatus? status,
    AIRequestType? requestType,
    AIInsight? insight,
    String? errorMessage,
    String? internalErrorType,
  }) {
    return AIInsightState(
      status: status ?? this.status,
      requestType: requestType ?? this.requestType,
      insight: insight ?? this.insight,
      errorMessage: errorMessage ?? this.errorMessage,
      internalErrorType: internalErrorType ?? this.internalErrorType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInsightState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          requestType == other.requestType &&
          insight == other.insight &&
          errorMessage == other.errorMessage &&
          internalErrorType == other.internalErrorType;

  @override
  int get hashCode => Object.hash(
        status,
        requestType,
        insight,
        errorMessage,
        internalErrorType,
      );

  @override
  String toString() =>
      'AIInsightState(status: $status, requestType: $requestType, insight: $insight, errorMessage: $errorMessage, internalErrorType: $internalErrorType)';
}
