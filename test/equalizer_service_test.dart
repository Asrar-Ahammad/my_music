import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/data/services/equalizer_service.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EqualizerService Tests', () {
    late EqualizerService service;

    setUp(() {
      service = EqualizerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial state has 0.0 gains and disabled', () {
      expect(service.isEnabled, isFalse);
      expect(service.sessionId, equals(0));
      expect(service.bandGains, equals([0.0, 0.0, 0.0, 0.0, 0.0]));
    });

    test('init updates in-memory values gracefully', () async {
      await service.init(
        42,
        isEnabled: true,
        bandGains: [2.0, 4.0, 6.0, 8.0, 10.0],
      );
      // In unit test environment (desktop/host without Android mock), channel call returns false
      expect(service.sessionId, equals(42));
      expect(service.isEnabled, isTrue);
      expect(service.bandGains, equals([2.0, 4.0, 6.0, 8.0, 10.0]));
    });

    test('setEnabled updates isEnabled state', () async {
      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);

      await service.setEnabled(false);
      expect(service.isEnabled, isFalse);
    });

    test('setBandGain updates individual band correctly', () async {
      await service.setBandGain(0, 5.0);
      expect(service.bandGains[0], equals(5.0));

      await service.setBandGain(4, -3.5);
      expect(service.bandGains[4], equals(-3.5));
    });

    test('setAllBands updates all bands', () async {
      await service.setAllBands([1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(service.bandGains, equals([1.0, 2.0, 3.0, 4.0, 5.0]));
    });
  });

  group('Equalizer Presets Tests', () {
    test('Presets map contains expected retro presets', () {
      expect(EqualizerNotifier.presets.containsKey('Flat'), isTrue);
      expect(EqualizerNotifier.presets.containsKey('8-Bit Chiptune'), isTrue);
      expect(EqualizerNotifier.presets.containsKey('Bass Boost'), isTrue);
      expect(EqualizerNotifier.presets.containsKey('Retro Arcade'), isTrue);
      expect(EqualizerNotifier.presets.containsKey('Vocal / Lead'), isTrue);
    });

    test('Each preset has exactly 5 bands', () {
      for (final entry in EqualizerNotifier.presets.entries) {
        expect(entry.value.length, equals(5),
            reason: '${entry.key} must have 5 frequency bands');
      }
    });
  });
}
