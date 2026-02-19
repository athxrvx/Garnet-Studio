import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../models/chat_message.dart';

final ollamaServiceProvider = Provider<OllamaService>((ref) => OllamaService());

class OllamaService {
  final String contentUrl;

  OllamaService({this.contentUrl = AppConstants.ollamaBaseUrl});

  Future<List<String>> listModels() async {
    try {
      final response = await http.get(Uri.parse('$contentUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'];
        return models.map((m) => m['name'] as String).toList();
      }
      return [];
    } catch (e) {
      print('Error accessing Ollama: $e');
      return [];
    }
  }

  Stream<String> generateChatStream(List<ChatMessage> messages, String model) async* {
    final url = Uri.parse('$contentUrl/api/chat');
    
    final request = http.Request('POST', url);
    request.body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => {
        'role': m.role.name,
        'content': m.content
      }).toList(),
      'stream': true,
    });

    try {
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Ollama API error: ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // Ollama sends multiple JSON objects in one chunk sometimes, or broken chunks
        // Proper parsing handles newline separation
        final lines = chunk.split('\n').where((line) => line.trim().isNotEmpty);
        for (final line in lines) {
          try {
            final data = jsonDecode(line);
            if (data['message'] != null && data['message']['content'] != null) {
              yield data['message']['content'];
            }
            if (data['done'] == true) {
              return;
            }
          } catch (e) {
            // Partial JSON line, ignore or handles
          }
        }
      }
    } catch (e) {
       yield "Error connecting to Ollama: $e";
       print(e);
    }
  }
}
