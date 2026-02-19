import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome
import '../../core/constants/app_constants.dart';
import '../../core/settings_service.dart';
// import '../../core/root_container.dart'; // Removed to break circular dependency
import '../models/models_provider.dart';
import '../layout/main_layout.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  
  String? _selectedModel;
  bool _isLoading = false;

  // Personality Templates
  final List<Map<String, dynamic>> _personas = [
    {
      'label': 'Reviewer',
      'icon': FontAwesomeIcons.magnifyingGlass,
      'desc': 'Professional, critical, and detail-oriented.',
      'prompt': 'You are a professional reviewer. Analyze user input critically, identify flaws, and suggest concrete improvements. Maintain a formal and objective tone.'
    },
    {
      'label': 'Coder',
      'icon': FontAwesomeIcons.code,
      'desc': 'Focused on code quality, performance, and best practices.',
      'prompt': 'You are an expert software engineer. Prioritize clean, efficient, and well-documented code. Explain your logic clearly but concisely.'
    },
    {
      'label': 'Standard', // Default
      'icon': FontAwesomeIcons.robot,
      'desc': 'Helpful, friendly, and versatile assistant.',
      'prompt': 'You are Garnet, a helpful and friendly AI assistant. Be concise and accurate.'
    },
    {
      'label': 'Creative',
      'icon': FontAwesomeIcons.paintbrush,
      'desc': 'Imaginative, descriptive, and open-ended.',
      'prompt': 'You are a creative muse. Focus on imaginative storytelling, vivid descriptions, and brainstorming unique ideas. Be expressive.'
    },
  ];
  
  int _selectedPersonaIndex = 2; // Default to Standard

  @override
  void initState() {
    super.initState();
    _systemPromptController.text = _personas[_selectedPersonaIndex]['prompt'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }
  
  void _selectPersona(int index) {
     setState(() {
       _selectedPersonaIndex = index;
       _systemPromptController.text = _personas[index]['prompt'];
     });
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Auto-select first model if none selected
    final modelsAsync = ref.read(modelsProvider);
    if (_selectedModel == null && modelsAsync.hasValue && modelsAsync.value!.isNotEmpty) {
       _selectedModel = modelsAsync.value!.first.name;
    }
    
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a default model (or ensure Ollama is running)")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsServiceProvider);
      
      await settings.setSetting('user_name', _nameController.text.trim());
      await settings.setSetting('system_prompt', _systemPromptController.text.trim());
      await settings.setSetting('active_model', _selectedModel!);
      await settings.setSetting('onboarding_complete', 'true');
      
      // Refresh providers
      ref.invalidate(activeModelNameProvider);
      
      if (mounted) {
        // Navigate to Main Layout (Using pushReplacement to kill back stack)
        // Ensure we are replacing the AppRoot switch logic by updating the provider? 
        // No, AppRoot watches the setting implicitly via future provider?
        // Actually AppRoot watches `onboardingStatusProvider`.
        // We need to invalidate that provider to trigger rebuild of AppRoot logic?
        // Or just navigation is enough if `AppRoot` isn't a continuous watcher or if we want smooth transition.
        
        ref.invalidate(onboardingStatusProvider); // This should trigger AppRoot to switch
        // But for safety/animation, let's manual nav
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainLayout(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving settings: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(modelsProvider);

    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 1000,
          height: 700,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppConstants.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Side: Brand & Info
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  color: AppConstants.sidebarBackgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      Row(
                         children: [
                           SizedBox(
                             width: 32,
                             height: 32,
                             child: Image.asset('assets/app_logo.png'),
                           ),
                           const SizedBox(width: 12),
                           const Text("Garnet Studio", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                         ],
                      ),
                      const Spacer(),
                      
                      const Text(
                        "Welcome,\nExplorer.",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Configure your personal AI workspace.",
                        style: TextStyle(fontSize: 18, color: AppConstants.textSecondary),
                      ),
                      const Spacer(),
                      
                      // Mobile App Promo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(FontAwesomeIcons.mobileScreen, size: 24, color: AppConstants.accentColor),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Go Mobile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Download the Garnet companion app to chat with your local models from any room.", 
                                    style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.8))
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right Side: Form
              Expanded(
                flex: 6,
                child: SingleChildScrollView( // Allow scrolling on smaller screens
                   padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text("User Profile", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textTertiary, letterSpacing: 1.0)),
                         const SizedBox(height: 12),
                         TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: AppConstants.textPrimary),
                            decoration: InputDecoration(
                              labelText: "What should AI call you?",
                              hintText: "e.g. Atharva, Admin, Master Wayne",
                              filled: true,
                              fillColor: AppConstants.scaffoldBackgroundColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.person_outline, size: 18, color: AppConstants.textTertiary),
                            ),
                            validator: (v) => v == null || v.isEmpty ? "Please enter a name" : null,
                         ),
                         const SizedBox(height: 20),
                         
                         if (modelsAsync.valueOrNull != null && modelsAsync.valueOrNull!.isNotEmpty) ...[
                            TextFormField(
                              initialValue: modelsAsync.valueOrNull!.first.name,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Detected Model",
                                filled: true,
                                fillColor: AppConstants.scaffoldBackgroundColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.smart_toy_outlined, size: 18, color: AppConstants.textTertiary),
                                suffixIcon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                              ),
                            ),
                            const SizedBox(height: 20),
                         ],

                         const Text("AI Personality", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textTertiary, letterSpacing: 1.0)),
                         const SizedBox(height: 12),
                         
                         // Template Selector
                         GridView.builder(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                             crossAxisCount: 2,
                             mainAxisSpacing: 16,
                             crossAxisSpacing: 16,
                             childAspectRatio: 2.6, // Even flatter cards
                           ),
                           itemCount: _personas.length,
                           itemBuilder: (context, index) {
                             final p = _personas[index];
                             final isSelected = _selectedPersonaIndex == index;
                             return InkWell(
                               onTap: () => _selectPersona(index),
                               borderRadius: BorderRadius.circular(12),
                               child: Container(
                                 decoration: BoxDecoration(
                                   color: isSelected ? AppConstants.accentColor.withOpacity(0.1) : AppConstants.scaffoldBackgroundColor,
                                   border: Border.all(
                                     color: isSelected ? AppConstants.accentColor : Colors.transparent, 
                                     width: 2
                                   ),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Column(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     Icon(p['icon'], color: isSelected ? AppConstants.accentColor : AppConstants.textTertiary, size: 24),
                                     const SizedBox(height: 8),
                                     Text(p['label'], style: TextStyle(
                                       color: isSelected ? AppConstants.textPrimary : AppConstants.textSecondary,
                                       fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                       fontSize: 13
                                     )),
                                   ],
                                 ),
                               ),
                             );
                           },
                         ),
                         
                         const SizedBox(height: 24),
                         
                         // Prompt Editor
                         TextFormField(
                           controller: _systemPromptController,
                           minLines: 2,
                           maxLines: 8,
                           style: const TextStyle(fontSize: 13, height: 1.4, color: AppConstants.textSecondary),
                           decoration: InputDecoration(
                             hintText: "System prompt...",
                             filled: true,
                             fillColor: AppConstants.scaffoldBackgroundColor,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                             contentPadding: const EdgeInsets.all(16),
                           ),
                         ),
                         const SizedBox(height: 32),
                         
                         // Done Button
                         SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _completeOnboarding,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.accentColor,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: AppConstants.accentColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Launch Studio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
