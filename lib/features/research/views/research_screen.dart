import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:garnet_studio/features/research/providers/research_provider.dart';
import 'package:garnet_studio/features/research/models/research_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:garnet_studio/core/constants/app_constants.dart';

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final TextEditingController _workspaceController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _workspaceController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(researchProvider);
    final controller = ref.read(researchProvider.notifier);

    // If no workspace is selected, show empty state or selector
    if (state.activeWorkspace == null) {
      return _buildWorkspaceSelector(context, ref);
    }

    return Column( // Removed Scaffold
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.activeWorkspace!.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    'Research Workspace',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                    tooltip: 'Switch Workspace',
                    onPressed: () => controller.loadWorkspaces(),
                  ),
                  // Add Source Menu
                  MenuAnchor(
                    builder: (context, controller, child) {
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                           backgroundColor: AppConstants.accentColor, 
                           foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Source'),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.upload_file),
                        child: const Text('Upload Files'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.custom,
                            allowedExtensions: ['txt', 'md', 'pdf', 'zip', 'json', 'yaml', 'xml', 'html', 'css', 'dart', 'js', 'ts', 'py', 'jpg', 'png'],
                          );
                          if (result != null) {
                            for (var path in result.paths) {
                              if (path != null) await controller.importFile(path);
                            }
                          }
                        },
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.folder),
                        child: const Text('Import Folder'),
                        onPressed: () async {
                           final path = await FilePicker.platform.getDirectoryPath();
                           if (path != null) {
                              await controller.importFolder(path);
                           }
                        },
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.link),
                        child: const Text('Add Web Link'),
                        onPressed: () {
                           _showLinkDialog(context, ref); 
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Panel: Documents
              Container(
                width: 320,
                color: AppConstants.sidebarBackground.withOpacity(0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'SOURCES (${state.documents.length})',
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: state.documents.isEmpty 
                      ? Center(child: Text("No sources added", style: TextStyle(color: Colors.white.withOpacity(0.3))))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.documents.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = state.documents[index];
                            return Container(
                               decoration: BoxDecoration(
                                  color: AppConstants.lighterBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                               ),
                               child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: Icon(
                                    _getIconForDoc(doc.name), 
                                    size: 20, 
                                    color: Colors.white70
                                  ),
                                  title: Text(
                                    doc.name,
                                    style: const TextStyle(fontSize: 13, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text('${doc.chunkCount} chunks', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                                      if (doc.processingStatus == 'processing')
                                         const Padding(
                                           padding: EdgeInsets.only(left: 8.0),
                                           child: SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1)),
                                         ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete_outline, size: 16, color: Colors.white.withOpacity(0.3)),
                                    onPressed: () => controller.deleteDocument(doc.id),
                                    hoverColor: Colors.red.withOpacity(0.1),
                                  ),
                               ),
                            );
                          },
                        ),
                    ),
                  ],
                ),
              ),
              
              const VerticalDivider(width: 1, color: Colors.white10),

              // Right Panel: Chat
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: state.messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.manage_search, size: 64, color: AppConstants.accentColor.withOpacity(0.5)),
                                const SizedBox(height: 24),
                                const Text(
                                  'Research Assistant',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ask questions based on your ${state.documents.length} sources and build your knowledge.',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: state.messages.length,
                            itemBuilder: (context, index) {
                              final msg = state.messages[index];
                              final isUser = msg.role == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  padding: const EdgeInsets.all(16),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                                  decoration: BoxDecoration(
                                    color: isUser ? AppConstants.accentColor : AppConstants.lighterBackground,
                                    borderRadius: BorderRadius.only(
                                       topLeft: const Radius.circular(16),
                                       topRight: const Radius.circular(16),
                                       bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                                       bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isUser)
                                         const Padding(
                                           padding: EdgeInsets.only(bottom: 6.0),
                                           child: Text("Assistant", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                                         ),
                                      MarkdownBody(
                                        data: msg.content,
                                        styleSheet: MarkdownStyleSheet(
                                           p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                                           code: TextStyle(backgroundColor: Colors.black.withOpacity(0.3), fontFamily: 'Consolas'),
                                        ),
                                      ),
                                      if (!isUser && state.isGenerating && index == state.messages.length - 1)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8.0),
                                            child: LinearProgressIndicator(minHeight: 2, color: Colors.white), 
                                          ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                    
                    // Input Area
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                         border: Border(top: BorderSide(color: Colors.white10)),
                         color: AppConstants.darkBackground,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              onSubmitted: (value) {
                                 if (value.isNotEmpty && !state.isGenerating) {
                                   controller.query(value);
                                   _chatController.clear();
                                 }
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ask a question regarding your sources...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                filled: true,
                                fillColor: AppConstants.lighterBackground,
                                border: OutlineInputBorder(
                                   borderRadius: BorderRadius.circular(30),
                                   borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: AppConstants.accentColor, fixedSize: const Size(50, 50)),
                            onPressed: state.isGenerating 
                              ? null 
                              : () {
                                  if (_chatController.text.isNotEmpty) {
                                     controller.query(_chatController.text);
                                     _chatController.clear();
                                  }
                              }, 
                            icon: state.isGenerating 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForDoc(String name) {
    if (name.startsWith('http')) return Icons.link;
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.zip')) return Icons.folder_zip;
    if (name.endsWith('.jpg') || name.endsWith('.png')) return Icons.image;
    return Icons.article;
  }

  void _showLinkDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.lighterBackground,
        title: const Text('Add Web Link', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'URL',
            labelStyle: TextStyle(color: Colors.white54),
            hintText: 'https://example.com/article',
            hintStyle: TextStyle(color: Colors.white24),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppConstants.accentColor),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                 ref.read(researchProvider.notifier).importLink(url);
                 Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSelector(BuildContext context, WidgetRef ref) {
    final state = ref.read(researchProvider);
    final controller = ref.read(researchProvider.notifier);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppConstants.lighterBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const Icon(Icons.library_books, size: 64, color: AppConstants.accentColor),
            const SizedBox(height: 16),
            const Text("Select Workspace", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 32),
            Expanded(
              child: state.workspaces.isEmpty
                ? Center(child: Text("No workspaces yet. Create one to begin.", style: TextStyle(color: Colors.white.withOpacity(0.5))))
                : ListView.builder(
                    itemCount: state.workspaces.length,
                    itemBuilder: (context, index) {
                      final ws = state.workspaces[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                           color: AppConstants.sidebarBackground,
                           borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(ws.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Created: ${ws.createdAt.toString().split(' ')[0]}', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white24),
                            onPressed: () => controller.deleteWorkspace(ws.id),
                          ),
                          onTap: () => controller.selectWorkspace(ws),
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _workspaceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'New Workspace Name',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: AppConstants.darkBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (value) {
                       if (value.isNotEmpty) {
                          controller.createWorkspace(value);
                          _workspaceController.clear();
                       }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: AppConstants.accentColor
                  ),
                  onPressed: () {
                    if (_workspaceController.text.isNotEmpty) {
                      controller.createWorkspace(_workspaceController.text);
                      _workspaceController.clear();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

