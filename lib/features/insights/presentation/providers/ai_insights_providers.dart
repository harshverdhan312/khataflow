import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/config/ai_provider_config.dart';
import '../../data/providers/mock_ai_insight_provider.dart';
import '../../data/providers/real_ai_insight_provider.dart';
import '../../data/repositories/ai_insight_repository_impl.dart';
import '../../domain/repositories/ai_insight_provider.dart';
import '../../domain/repositories/ai_insight_repository.dart';
import '../../domain/services/ai_context_builder.dart';
import '../../domain/services/ai_response_validator.dart';

import '../controllers/ai_insight_cache.dart';
import '../controllers/ai_insight_controller.dart';
import '../controllers/ai_insight_state.dart';

/// Provider for the AI configuration (endpoint, credentials/gateway auth, timeout).
final aiProviderConfigProvider = Provider<AIProviderConfig>((ref) {
  return AIProviderConfig.disabled();
});

/// Controls whether the application should use the real network AI provider or mock provider.
final useRealAiProviderProvider = StateProvider<bool>((ref) {
  final config = ref.watch(aiProviderConfigProvider);
  return config.isConfigured;
});

/// Pure domain context builder service.
final aiContextBuilderProvider = Provider<AIContextBuilder>((ref) {
  return const AIContextBuilder();
});

/// Pure domain response validator service.
final aiResponseValidatorProvider = Provider<AIResponseValidator>((ref) {
  return const AIResponseValidator();
});

/// Resolves the active [AIInsightProvider] instance (Real or Mock).
final aiInsightProviderInstance = Provider<AIInsightProvider>((ref) {
  final useReal = ref.watch(useRealAiProviderProvider);
  final config = ref.watch(aiProviderConfigProvider);

  if (useReal && config.isConfigured) {
    return RealAIInsightProvider(config: config);
  }

  return const MockAIInsightProvider();
});

/// Resolves the domain [AIInsightRepository] wired with the active provider and validator.
final aiInsightRepositoryProvider = Provider<AIInsightRepository>((ref) {
  final provider = ref.watch(aiInsightProviderInstance);
  final validator = ref.watch(aiResponseValidatorProvider);

  return AIInsightRepositoryImpl(
    provider: provider,
    validator: validator,
  );
});

/// Session-scoped in-memory cache for AI insight requests.
final aiInsightCacheProvider = Provider<AIInsightCache>((ref) {
  return AIInsightCache();
});

/// Application/Presentation controller managing AI insight generation state.
final aiInsightControllerProvider =
    StateNotifierProvider<AIInsightController, AIInsightState>((ref) {
  final repository = ref.watch(aiInsightRepositoryProvider);
  final contextBuilder = ref.watch(aiContextBuilderProvider);
  final cache = ref.watch(aiInsightCacheProvider);

  return AIInsightController(
    repository: repository,
    contextBuilder: contextBuilder,
    cache: cache,
  );
});

