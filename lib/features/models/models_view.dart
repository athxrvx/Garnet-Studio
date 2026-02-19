import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/llm_model.dart';
import 'models_provider.dart';
import 'pull_model_dialog.dart';
import 'model_details_panel.dart';

class ModelsView extends ConsumerWidget {
  const ModelsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Local LLM Inventory',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const PullModelDialog()),
                icon: const Icon(Icons.download),
                label: const Text('Pull Model'),
                style: FilledButton.styleFrom(backgroundColor: AppConstants.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: modelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              data: (models) {
                if (models.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox, size: 48, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text('No models installed', style: TextStyle(color: Colors.white54)),
                        TextButton(
                          onPressed: () => showDialog(context: context, builder: (_) => const PullModelDialog()),
                          child: const Text('Pull your first model'),
                        )
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: models.length,
                  itemBuilder: (context, index) => _ModelCard(model: models[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  final LocalModel model;

  const _ModelCard({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = model.isActive;
    
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppConstants.accentColor.withOpacity(0.15) : AppConstants.lighterBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppConstants.accentColor : Colors.white.withOpacity(0.12),
          width: isActive ? 2 : 1
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppConstants.accentColor, borderRadius: BorderRadius.circular(4)),
                  child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${model.sizeGB} GB • RAM Est: ${model.ramEstimate} GB',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
           Text(
            'Modified: ${model.modifiedAt.toLocal().toString().split('.')[0]}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const Spacer(),
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               IconButton(
                 icon: const Icon(Icons.settings, size: 18, color: Colors.white),
                 tooltip: 'Configure',
                 onPressed: () => showDialog(context: context, builder: (_) => ModelDetailsPanel(model: model)),
               ),
               IconButton(
                 icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                 tooltip: 'Delete',
                 onPressed: () => _confirmDelete(context, ref),
               ),
               if (!isActive)
                 FilledButton(
                   onPressed: () => ref.read(modelsProvider.notifier).setActiveModel(model.name),
                   style: FilledButton.styleFrom(
                     backgroundColor: Colors.white24,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                   ),
                   child: const Text('Activate'),
                 )
               else
                 FilledButton(
                   onPressed: () => ref.read(modelsProvider.notifier).deactivateModel(model.name),
                   style: FilledButton.styleFrom(
                     backgroundColor: const Color(0xFF442222),
                     foregroundColor: Colors.redAccent,
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                   ),
                   child: const Text('Deactivate'),
                 )
            ],
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    if (model.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete active model. Switch first.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Model?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${model.name}? This cannot be undone.', 
           style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
               ref.read(modelsProvider.notifier).deleteModel(model.name);
               Navigator.pop(context);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
