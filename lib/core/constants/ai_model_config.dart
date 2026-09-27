enum AiModelType {
  aiDj,
  libraryTagger,
  audioEmbedding,
  textEmbedding,
  recommendationLlm,
}

enum AiModelDownloadState {
  notDownloaded,
  downloading,
  ready,
  error,
}

class AiModelInfo {
  final String id;
  final String name;
  final String shortDesc;
  final String fullDesc;
  final String fileName;
  final String huggingFaceUrl;
  final int expectedSizeBytes;
  final String displaySize;
  final AiModelType type;

  const AiModelInfo({
    required this.id,
    required this.name,
    required this.shortDesc,
    required this.fullDesc,
    required this.fileName,
    required this.huggingFaceUrl,
    required this.expectedSizeBytes,
    required this.displaySize,
    required this.type,
  });
}

class AiModelConfig {
  static const String modelsDirName = 'ai_models';

  /// SmolLM-135M-Instruct for on-device AI DJ (~85 MB)
  static const AiModelInfo smolLm135m = AiModelInfo(
    id: 'smollm_135m',
    name: 'SmolLM-135M (Local AI DJ)',
    shortDesc: 'Offline conversational DJ & smart playlist curator',
    fullDesc: 'A micro Language Model optimized for on-device inference. Analyzes your local music library to curate contextual playlists, suggest tracks based on vibes, and recommend smart mixes completely offline.',
    fileName: 'SmolLM-135M-Instruct-Q2_K.gguf',
    huggingFaceUrl: 'https://huggingface.co/second-state/SmolLM-135M-Instruct-GGUF/resolve/main/SmolLM-135M-Instruct-Q2_K.gguf',
    expectedSizeBytes: 88201632, // ~84.1 MB
    displaySize: '~85 MB',
    type: AiModelType.aiDj,
  );

  /// YAMNet for audio feature extraction (~17 MB)
  static const AiModelInfo yamnet = AiModelInfo(
    id: 'yamnet',
    name: 'YAMNet (Audio Embeddings)',
    shortDesc: 'Acoustic feature extractor from raw audio waveforms',
    fullDesc: 'Deep neural network trained on AudioSet to extract 1024-dimensional acoustic feature vectors from audio waveforms completely on-device without blocking playback.',
    fileName: 'yamnet.tflite',
    huggingFaceUrl: 'https://huggingface.co/tensorflow/yamnet/resolve/main/yamnet.tflite',
    expectedSizeBytes: 17825792, // ~17 MB
    displaySize: '~17 MB',
    type: AiModelType.audioEmbedding,
  );

  /// MiniLM-L6-v2 for text metadata embeddings (~23 MB)
  static const AiModelInfo minilmV2 = AiModelInfo(
    id: 'minilm_v2',
    name: 'MiniLM-L6-v2 (Text Embeddings)',
    shortDesc: 'Semantic text embeddings for track titles, genres & vibes',
    fullDesc: 'Transformer model mapped to 384-dimensional dense vectors to understand relationships between song titles, artists, vibes, and genres.',
    fileName: 'model.onnx',
    huggingFaceUrl: 'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx',
    expectedSizeBytes: 24117248, // ~23 MB
    displaySize: '~23 MB',
    type: AiModelType.textEmbedding,
  );

  /// Qwen2.5-0.5B-Instruct for recommendation ranking & explanations (~380 MB)
  static const AiModelInfo qwen05b = AiModelInfo(
    id: 'qwen_0_5b',
    name: 'Qwen2.5-0.5B (Recommendation Explainer)',
    shortDesc: 'On-device LLM to rank and explain track recommendations',
    fullDesc: 'Compact instruction-tuned language model that generates natural, contextual 1-sentence explanations for why each track was recommended.',
    fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    huggingFaceUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    expectedSizeBytes: 398458880, // ~380 MB
    displaySize: '~380 MB',
    type: AiModelType.recommendationLlm,
  );

  static const List<AiModelInfo> allModels = [
    smolLm135m,
    yamnet,
    minilmV2,
    qwen05b,
  ];

  static AiModelInfo? getById(String id) {
    for (final m in allModels) {
      if (m.id == id) return m;
    }
    return null;
  }
}
