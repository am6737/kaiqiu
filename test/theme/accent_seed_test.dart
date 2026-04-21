import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';

void main() {
  group('AccentSeed.parse', () {
    test('parses preset green', () {
      final seed = AccentSeed.parse('preset:green');
      expect(seed, isA<PresetAccentSeed>());
      expect((seed as PresetAccentSeed).preset, PresetAccent.green);
    });

    test('parses all four presets', () {
      for (final name in const ['green', 'orange', 'cyan', 'red']) {
        final seed = AccentSeed.parse('preset:$name');
        expect(seed, isA<PresetAccentSeed>());
      }
    });

    test('parses custom hex', () {
      final seed = AccentSeed.parse('custom:0xFF7A3DEC');
      expect(seed, isA<CustomAccentSeed>());
      expect((seed as CustomAccentSeed).colorValue, 0xFF7A3DEC);
    });

    test('falls back to preset green on garbage', () {
      expect(AccentSeed.parse('garbage'), isA<PresetAccentSeed>());
      expect(AccentSeed.parse(''), isA<PresetAccentSeed>());
      expect(AccentSeed.parse('preset:purple'), isA<PresetAccentSeed>());
      expect(AccentSeed.parse('custom:notahex'), isA<PresetAccentSeed>());
    });

    test('round-trips preset', () {
      final seed = AccentSeed.parse('preset:orange');
      expect(seed.serialize(), 'preset:orange');
    });

    test('round-trips custom', () {
      const seed = CustomAccentSeed(0xFF7A3DEC);
      expect(seed.serialize(), 'custom:0xFF7A3DEC');
      expect(AccentSeed.parse(seed.serialize()), seed);
    });

    test('preset equality', () {
      expect(
        const PresetAccentSeed(PresetAccent.green),
        const PresetAccentSeed(PresetAccent.green),
      );
      expect(
        const PresetAccentSeed(PresetAccent.green),
        isNot(const PresetAccentSeed(PresetAccent.red)),
      );
    });

    test('custom equality', () {
      expect(
        const CustomAccentSeed(0xFFAABBCC),
        const CustomAccentSeed(0xFFAABBCC),
      );
      expect(
        const CustomAccentSeed(0xFFAABBCC),
        isNot(const CustomAccentSeed(0xFF000000)),
      );
    });
  });
}
