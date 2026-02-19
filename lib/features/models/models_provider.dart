import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ollama_client.dart';
import '../../services/model_settings_service.dart';
import '../../core/database.dart';
import '../../core/models/llm_model.dart';
import '../../core/settings_service.dart';
import '../../features/chat/ollama_provider.dart';

// Service Providers
final ollamaClientProvider = Provider<OllamaClient>((ref) {
  return OllamaClient();
});

final modelSettingsServiceProvider = Provider<ModelSettingsService>((ref) {
  final dbService = DatabaseService();
  return ModelSettingsService(dbService);
});

// Notifier
class ModelsNotifier extends StateNotifier<AsyncValue<List<LocalModel>>> {
  final ModelSettingsService _settingsService;
  final OllamaClient _ollamaClient;
  final Ref _ref;

  ModelsNotifier(this._settingsService, this._ollamaClient, this._ref) 
      : super(const AsyncValue.loading()) {
    refreshModels();
  }

  Future<void> refreshModels() async {
    try {
      state = const AsyncValue.loading();
      
      // 1. Fetch from source of truth check connection
      final ollamaTags = await _ollamaClient.getTags();
      
      // 2. Sync DB
      await _settingsService.syncModels(ollamaTags);
      
      // 3. Load from DB (with local config)
      final models = await _settingsService.getAllModels();
      
      state = AsyncValue.data(models);
      
      // Update global state
      _ref.invalidate(activeModelNameProvider);
      
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setActiveModel(String name) async {
    await _settingsService.setActiveModel(name);
    await refreshModels(); 
    _ref.invalidate(selectedModelProvider);
  }

  Future<void> deactivateModel(String name) async {
    // 1. Unload from Ollama
    await _ollamaClient.unloadModel(name);
    // 2. Clear from App State
    await _settingsService.clearActiveModel();
    // 3. Refresh UI
    await refreshModels();
    _ref.invalidate(selectedModelProvider);
  }

  Future<void> deleteModel(String name) async {
    final success = await _ollamaClient.deleteModel(name);
    if (success) {
      await refreshModels();
    }
  }

  Future<void> updateConfig(String name, {
    double? temperature,
    double? topP,
    int? topK,
    int? contextLength,
    String? systemPrompt,
    int? maxTokens,
  }) async {
    await _settingsService.updateModelConfig(
      name, 
      temperature: temperature,
      topP: topP, 
      topK: topK,
      contextLength: contextLength,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens
    );
    await refreshModels(); 
  }
}

final modelsProvider = StateNotifierProvider<ModelsNotifier, AsyncValue<List<LocalModel>>>((ref) {
  final settings = ref.watch(modelSettingsServiceProvider);
  final client = ref.watch(ollamaClientProvider);
  return ModelsNotifier(settings, client, ref);
});
