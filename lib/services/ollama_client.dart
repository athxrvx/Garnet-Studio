import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class OllamaClient {
  // Use 127.0.0.1 instead of localhost for better reliability on Windows/Dart
  final String _baseUrl = 'http://127.0.0.1:11434';

  Future<List<Map<String, dynamic>>> getTags() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['models']);
      }
      return [];
    } catch (e) {
      print('OllamaClient Error: $e');
      return [];
    }
  }

  Future<bool> deleteModel(String name) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/delete'),
        body: jsonEncode({'name': name}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> unloadModel(String name) async {
    try {
      // Send an empty generate request with keep_alive: 0 to force unload immediately
      await http.post(
        Uri.parse('$_baseUrl/api/generate'),
        body: jsonEncode({
          'model': name,
          'prompt': '', // Empty prompt
          'keep_alive': 0, // Unload immediately
        }),
      );
    } catch (e) {
      // Ignore errors during unload
      print("Error unloading model: $e");
    }
  }

  // Returns a stream of generated text
  Stream<String> generateCompletion(String model, String prompt) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/generate'));
    request.body = jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': true,
      'options': {
        'temperature': 0.3, // Lower temp for research
      }
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        try {
          final data = jsonDecode(chunk);
          if (data['done'] == false) {
             yield data['response'] as String;
          }
        } catch (e) { }
      }
      client.close();
    } catch (e) {
      yield "Error connecting to Ollama: $e";
    }
  }

  // Returns a stream of progress messages (0.0 to 1.0) or status strings
  Stream<ModelPullStatus> pullModel(String name) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/pull'));
    request.body = jsonEncode({'name': name});

    try {
      final client = http.Client();
      final response = await client.send(request);

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        
        try {
          final data = jsonDecode(chunk);
          // Example: {"status":"downloading","digest":"...","total":...,"completed":...}
          
          if (data['status'] == 'success') {
            yield ModelPullStatus(status: 'Completed', progress: 1.0, isDone: true);
          } else if (data.containsKey('total') && data.containsKey('completed')) {
             final total = data['total'];
             final completed = data['completed'];
             final progress = total > 0 ? completed / total : 0.0;
             yield ModelPullStatus(status: data['status'], progress: progress.toDouble(), isDone: false);
          } else {
             yield ModelPullStatus(status: data['status'], progress: 0.0, isDone: false);
          }
        } catch (e) {
          // Ignore parse errors for partial chunks
        }
      }
      client.close();
    } catch (e) {
      yield ModelPullStatus(status: 'Error: $e', progress: 0.0, isDone: true, isError: true);
    }
  }
}

class ModelPullStatus {
  final String status;
  final double progress;
  final bool isDone;
  final bool isError;

  ModelPullStatus({required this.status, required this.progress, required this.isDone, this.isError = false});
}
