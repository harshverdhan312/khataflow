/// Base exception class for all AI insight domain and provider errors.
sealed class AIInsightException implements Exception {
  final String message;

  const AIInsightException(this.message);

  @override
  String toString() => 'AIInsightException: $message';
}

/// Thrown when network transport fails (e.g. DNS failure, connection refused, offline).
class AINetworkException extends AIInsightException {
  const AINetworkException([super.message = 'Network connection failed while reaching AI provider.']);
}

/// Thrown when the AI request exceeds the allowed timeout limit.
class AITimeoutException extends AIInsightException {
  const AITimeoutException([super.message = 'AI provider request timed out.']);
}

/// Thrown when the provider request lacks valid authentication or authorization.
class AIAuthException extends AIInsightException {
  const AIAuthException([super.message = 'AI provider authentication failed or configuration is missing.']);
}

/// Thrown when the AI provider returns an HTTP 4xx or 5xx error or rate limit.
class AIProviderException extends AIInsightException {
  final int? statusCode;

  const AIProviderException({
    required String message,
    this.statusCode,
  }) : super(message);

  @override
  String toString() =>
      'AIProviderException(status: $statusCode): $message';
}

/// Thrown when the AI provider returns malformed, unparseable, or missing JSON content.
class AIMalformedResponseException extends AIInsightException {
  const AIMalformedResponseException([super.message = 'AI provider returned a malformed or unparseable response.']);
}
