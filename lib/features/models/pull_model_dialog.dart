import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'models_provider.dart';

class PullModelDialog extends ConsumerStatefulWidget {
  const PullModelDialog({super.key});

  @override
  ConsumerState<PullModelDialog> createState() => _PullModelDialogState();
}

class _PullModelDialogState extends ConsumerState<PullModelDialog> {
  final _modelController = TextEditingController();
  final _tagController = TextEditingController(text: 'latest');
  // final _quantController = TextEditingController(text: 'q4_K_M'); // Advanced

  bool _isPulling = false;
  double _progress = 0.0;
  String _status = '';
  
  @override
  Widget build(BuildContext context) {
    if (_isPulling) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Pulling Model', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.accentColor),
            ),
            const SizedBox(height: 16),
            Text(_status, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Pull New Model', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _modelController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Model Name (e.g. llama3, qwen2.5)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Tag (default: latest)'),
            ),
            // Quantization inputs could go here
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ),
        FilledButton(
          onPressed: _startPull,
          style: FilledButton.styleFrom(backgroundColor: AppConstants.accentColor),
          child: const Text('Pull'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppConstants.accentColor)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
    );
  }

  void _startPull() {
    if (_modelController.text.isEmpty) return;
    
    final fullModelId = '${_modelController.text}:${_tagController.text}';
    
    setState(() {
      _isPulling = true;
      _status = 'Initializing...';
      _progress = 0.0;
    });

    final client = ref.read(ollamaClientProvider);
    
    // Listen to the stream
    client.pullModel(fullModelId).listen(
      (status) {
        setState(() {
          _status = status.status;
          _progress = status.progress;
        });
        
        if (status.isDone && !status.isError) {
          // Refresh list and close
          ref.read(modelsProvider.notifier).refreshModels();
          if (mounted) Navigator.pop(context);
        }
      },
      onError: (err) {
        setState(() => _status = 'Error: $err');
      },
    );
  }
}
