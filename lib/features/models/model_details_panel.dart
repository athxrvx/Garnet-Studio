import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/llm_model.dart';
import 'models_provider.dart';

class ModelDetailsPanel extends ConsumerStatefulWidget {
  final LocalModel model;

  const ModelDetailsPanel({super.key, required this.model});

  @override
  ConsumerState<ModelDetailsPanel> createState() => _ModelDetailsPanelState();
}

class _ModelDetailsPanelState extends ConsumerState<ModelDetailsPanel> {
  late double _temp;
  late double _topP;
  late int _contextLength;
  late TextEditingController _systemPromptCtrl;
  
  @override
  void initState() {
    super.initState();
    _temp = widget.model.temperature;
    _topP = widget.model.topP;
    _contextLength = widget.model.contextLength;
    _systemPromptCtrl = TextEditingController(text: widget.model.systemPrompt);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Configuration: ${widget.model.name}', 
                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _Header('Generation Parameters'),
                    _SliderRow(
                      label: 'Temperature', 
                      value: _temp, 
                      min: 0.0, max: 2.0, 
                      divisions: 20,
                      onChanged: (v) => setState(() => _temp = v)
                    ),
                    _SliderRow(
                      label: 'Top P', 
                      value: _topP, 
                      min: 0.0, max: 1.0, 
                      divisions: 20,
                      onChanged: (v) => setState(() => _topP = v)
                    ),
                    const SizedBox(height: 16),
                    _Header('Context Window'),
                     Row(
                      children: [
                        Text('Size: $_contextLength tokens', style: const TextStyle(color: Colors.white70)),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _contextLength,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white),
                          items: [2048, 4096, 8192, 16384, 32768, 65536, 128000].map((e) => 
                            DropdownMenuItem(value: e, child: Text(e.toString()))
                          ).toList(),
                          onChanged: (v) => setState(() => _contextLength = v!),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _Header('System Prompt'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _systemPromptCtrl,
                      maxLines: 8,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.white70),
                      decoration: InputDecoration(
                        hintText: 'You are a helpful AI assistant...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Profile'),
                  style: FilledButton.styleFrom(backgroundColor: AppConstants.accentColor),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _save() {
    ref.read(modelsProvider.notifier).updateConfig(
      widget.model.name,
      temperature: _temp,
      topP: _topP,
      contextLength: _contextLength,
      systemPrompt: _systemPromptCtrl.text,
    );
    Navigator.pop(context);
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 13));
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppConstants.accentColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
