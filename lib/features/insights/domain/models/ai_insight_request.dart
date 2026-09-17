import 'ai_context.dart';
import 'ai_request_type.dart';

/// Request object containing the bounded financial context and request intent for AI insight generation.
class AIInsightRequest {
  final AIContext context;
  final AIRequestType requestType;

  const AIInsightRequest({
    required this.context,
    required this.requestType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInsightRequest &&
          runtimeType == other.runtimeType &&
          context == other.context &&
          requestType == other.requestType;

  @override
  int get hashCode => Object.hash(context, requestType);

  @override
  String toString() =>
      'AIInsightRequest(requestType: $requestType, context: $context)';
}
