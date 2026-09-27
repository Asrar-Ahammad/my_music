import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/data/services/system_volume_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemVolumeService Tests', () {
    late SystemVolumeService volumeService;

    setUp(() {
      volumeService = SystemVolumeService();
    });

    tearDown(() {
      volumeService.dispose();
    });

    test('Initial volume is between 0.0 and 1.0', () {
      expect(volumeService.currentVolume, inInclusiveRange(0.0, 1.0));
    });

    test('setVolume updates currentVolume and emits on stream', () async {
      final volumeEvents = <double>[];
      final sub = volumeService.volumeStream.listen(volumeEvents.add);

      await volumeService.setVolume(0.45);
      expect(volumeService.currentVolume, equals(0.45));

      await volumeService.setVolume(0.85);
      expect(volumeService.currentVolume, equals(0.85));

      // Test clamping
      await volumeService.setVolume(1.5);
      expect(volumeService.currentVolume, equals(1.0));

      await volumeService.setVolume(-0.5);
      expect(volumeService.currentVolume, equals(0.0));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(volumeEvents, containsAllInOrder([0.45, 0.85, 1.0, 0.0]));

      await sub.cancel();
    });
  });
}
