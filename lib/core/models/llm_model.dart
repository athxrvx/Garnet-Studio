class LocalModel {
  final String name;
  final int size;
  final DateTime modifiedAt;
  final String digest;
  
  // Configuration (from DB)
  final bool isActive;
  final double temperature;
  final double topP;
  final int topK;
  final int contextLength;
  final String systemPrompt;
  final int maxTokens;

  LocalModel({
    required this.name,
    required this.size,
    required this.modifiedAt,
    required this.digest,
    this.isActive = false,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.contextLength = 4096,
    this.systemPrompt = '',
    this.maxTokens = -1,
  });

  LocalModel copyWith({
    String? name,
    int? size,
    DateTime? modifiedAt,
    String? digest,
    bool? isActive,
    double? temperature,
    double? topP,
    int? topK,
    int? contextLength,
    String? systemPrompt,
    int? maxTokens,
  }) {
    return LocalModel(
      name: name ?? this.name,
      size: size ?? this.size,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      digest: digest ?? this.digest,
      isActive: isActive ?? this.isActive,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      contextLength: contextLength ?? this.contextLength,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  // Helper for UI
  String get sizeGB => (size / (1024 * 1024 * 1024)).toStringAsFixed(2);
  String get ramEstimate => ((size / (1024 * 1024 * 1024)) * 1.3).toStringAsFixed(1);
}
