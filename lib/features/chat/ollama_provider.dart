import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ollama/ollama_service.dart';
import '../../core/settings_service.dart'; // For activeModelNameProvider
import 'dart:convert';
import 'package:http/http.dart' as http;

// Temporary solution to fetch models directly
Future<List<String>> fetchModels() async {
  try {
    final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> models = data['models'];
      return models.map((m) => m['name'] as String).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
}

final availableModelsProvider = FutureProvider<List<String>>((ref) async {
  return await fetchModels();
});

class SelectedModelNotifier extends Notifier<String> {
  @override
  String build() {
     // 1. Try to sync with globally active model
    final activeModelAsync = ref.watch(activeModelNameProvider);
    
    if (activeModelAsync.hasValue && 
        activeModelAsync.value != null && 
        activeModelAsync.value != 'Not Selected') {
      return activeModelAsync.value!;
    }
    
    // 2. Fallback: Use first available model from Ollama
    final availableAsync = ref.watch(availableModelsProvider);
    if (availableAsync.hasValue && availableAsync.value != null && availableAsync.value!.isNotEmpty) {
      // Prefer gemma:2b or anything that isn't heavy if possible, but first is fine
      return availableAsync.value!.first;
    }

    // 3. Last resort fallback
    return 'llama3:latest'; 
  }
  
  void update(String newState) {
    state = newState;
  }
}

final selectedModelProvider = NotifierProvider<SelectedModelNotifier, String>(() {
  return SelectedModelNotifier();
});
