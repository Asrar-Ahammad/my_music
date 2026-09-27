import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/constants/ai_model_config.dart';
import 'package:my_music/data/services/huggingface_model_manager.dart';
import 'package:my_music/domain/models/lrc_model.dart';

void main() {
  group('AI Model Configuration & Manager', () {
    test('Config contains all 4 models (SmolLM, YAMNet, MiniLM, Qwen2.5)', () {
      expect(AiModelConfig.allModels.length, 4);

      final smolLm = AiModelConfig.smolLm135m;
      expect(smolLm.id, 'smollm_135m');
      expect(smolLm.type, AiModelType.aiDj);
      expect(smolLm.fileName, 'SmolLM-135M-Instruct-Q2_K.gguf');
      expect(smolLm.huggingFaceUrl, contains('huggingface.co/second-state/SmolLM-135M-Instruct-GGUF'));
      expect(smolLm.displaySize, '~85 MB');

      final yamnet = AiModelConfig.yamnet;
      expect(yamnet.id, 'yamnet');
      expect(yamnet.type, AiModelType.audioEmbedding);
      expect(yamnet.fileName, 'yamnet.tflite');
      expect(yamnet.displaySize, '~17 MB');

      final minilm = AiModelConfig.minilmV2;
      expect(minilm.id, 'minilm_v2');
      expect(minilm.type, AiModelType.textEmbedding);
      expect(minilm.fileName, 'model.onnx');
      expect(minilm.displaySize, '~23 MB');

      final qwen = AiModelConfig.qwen05b;
      expect(qwen.id, 'qwen_0_5b');
      expect(qwen.type, AiModelType.recommendationLlm);
      expect(qwen.fileName, 'qwen2.5-0.5b-instruct-q4_k_m.gguf');
      expect(qwen.displaySize, '~380 MB');
    });

    test('formatBytes correctly converts file sizes', () {
      expect(HuggingFaceModelManager.formatBytes(0), '0 B');
      expect(HuggingFaceModelManager.formatBytes(512), '512.0 B');
      expect(HuggingFaceModelManager.formatBytes(1024), '1.0 KB');
      expect(HuggingFaceModelManager.formatBytes(1024 * 1024 * 39), '39.0 MB');
      expect(HuggingFaceModelManager.formatBytes(1024 * 1024 * 85), '85.0 MB');
    });

    test('AiModelConfig.getById works for valid and invalid IDs', () {
      expect(AiModelConfig.getById('smollm_135m'), isNotNull);
      expect(AiModelConfig.getById('yamnet'), isNotNull);
      expect(AiModelConfig.getById('minilm_v2'), isNotNull);
      expect(AiModelConfig.getById('qwen_0_5b'), isNotNull);
      expect(AiModelConfig.getById('whisper_tiny'), isNull);
      expect(AiModelConfig.getById('non_existent'), isNull);
    });
  });

  group('Lyrics Anticipatory Lead & Timestamp Alignment', () {
    test('LrcDocument findLineIndexAt applies anticipatory lead to prevent audio lag', () {
      const doc = LrcDocument(
        isSynced: true,
        rawContent: '',
        lines: [
          LrcLine(timestamp: Duration(seconds: 3), text: 'Line 1'),
          LrcLine(timestamp: Duration(seconds: 8), text: 'Line 2'),
          LrcLine(timestamp: Duration(seconds: 14), text: 'Line 3'),
        ],
      );

      // At 2.7s (300ms before Line 1):
      // Without lead, line 1 has not started yet (-1)
      expect(doc.findLineIndexAt(const Duration(milliseconds: 2700)), -1);

      // With 350ms anticipatory lead, 2.7s + 350ms = 3.05s >= 3.0s -> Line 1 activates early!
      expect(
        doc.findLineIndexAt(
          const Duration(milliseconds: 2700),
          anticipatoryLead: const Duration(milliseconds: 350),
        ),
        0,
      );

      // At 7.8s (200ms before Line 2):
      // Without lead, it's still Line 1 (index 0)
      expect(doc.findLineIndexAt(const Duration(milliseconds: 7800)), 0);

      // With 250ms anticipatory lead, 7.8s + 250ms = 8.05s >= 8.0s -> Line 2 activates in advance!
      expect(
        doc.findLineIndexAt(
          const Duration(milliseconds: 7800),
          anticipatoryLead: const Duration(milliseconds: 250),
        ),
        1,
      );
    });
  });
}
