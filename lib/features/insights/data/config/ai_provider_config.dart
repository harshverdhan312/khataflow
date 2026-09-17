/// Configuration for the real AI insight provider.
///
/// Supports both:
/// 1. Production gateway architecture (requests routed through an authenticated backend).
/// 2. Injected development/test configuration.
class AIProviderConfig {
  final Uri endpointUrl;
  final String? apiKey;
  final String? authToken;
  final Map<String, String> customHeaders;
  final Duration timeout;
  final String modelName;

  const AIProviderConfig({
    required this.endpointUrl,
    this.apiKey,
    this.authToken,
    this.customHeaders = const {},
    this.timeout = const Duration(seconds: 15),
    this.modelName = 'gemini-1.5-flash',
  });

  /// Factory for production gateway endpoints (no long-lived AI secret on the device).
  factory AIProviderConfig.gateway({
    required Uri gatewayUrl,
    String? userAuthToken,
    Duration timeout = const Duration(seconds: 15),
    String modelName = 'gemini-1.5-flash',
    Map<String, String> customHeaders = const {},
  }) {
    return AIProviderConfig(
      endpointUrl: gatewayUrl,
      authToken: userAuthToken,
      timeout: timeout,
      modelName: modelName,
      customHeaders: customHeaders,
    );
  }

  /// Factory for direct provider endpoints (development and integration testing only).
  factory AIProviderConfig.direct({
    required String apiKey,
    Uri? customEndpoint,
    Duration timeout = const Duration(seconds: 15),
    String modelName = 'gemini-1.5-flash',
  }) {
    final endpoint = customEndpoint ??
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
        );

    return AIProviderConfig(
      endpointUrl: endpoint,
      apiKey: apiKey,
      timeout: timeout,
      modelName: modelName,
    );
  }

  /// Factory for unconfigured/disabled provider state.
  factory AIProviderConfig.disabled() {
    return AIProviderConfig(
      endpointUrl: Uri.parse('http://localhost'),
      timeout: const Duration(seconds: 1),
    );
  }

  /// Returns `true` if the configuration possesses an endpoint and valid credentials/gateway settings.
  bool get isConfigured {
    if (endpointUrl.host == 'localhost' && apiKey == null && authToken == null) {
      return false;
    }
    return (apiKey != null && apiKey!.trim().isNotEmpty) ||
        (authToken != null && authToken!.trim().isNotEmpty) ||
        (endpointUrl.scheme.startsWith('http') && endpointUrl.host.isNotEmpty);
  }

  /// Generates the HTTP request headers without exposing internal secrets in strings.
  Map<String, String> buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...customHeaders,
    };

    if (authToken != null && authToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    } else if (apiKey != null && apiKey!.trim().isNotEmpty) {
      headers['x-goog-api-key'] = apiKey!.trim();
    }

    return headers;
  }
}
