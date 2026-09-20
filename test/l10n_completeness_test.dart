import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the translations themselves rather than the widgets that use them.
///
/// A key added to the English template and forgotten in `app_uk.arb` silently
/// falls back to English at runtime — the app keeps working and the defect only
/// shows up during a demo. This test makes it a build failure instead.
void main() {
  final directory = Directory('lib/l10n');

  Map<String, dynamic> load(String code) => jsonDecode(
        File('${directory.path}/app_$code.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final template = load('en');
  final templateKeys = keysOf(template);

  test('the template has a meaningful number of strings', () {
    expect(templateKeys.length, greaterThan(100));
  });

  for (final code in ['uk', 'de']) {
    group('locale $code', () {
      final translation = load(code);
      final keys = keysOf(translation);

      test('declares its own locale', () {
        expect(translation['@@locale'], code);
      });

      test('translates every key of the template', () {
        expect(templateKeys.difference(keys), isEmpty,
            reason: 'missing keys in app_$code.arb');
      });

      test('has no keys the template does not have', () {
        expect(keys.difference(templateKeys), isEmpty,
            reason: 'stale keys in app_$code.arb');
      });

      test('no value is left as the English original', () {
        // Product names and language names are meant to be identical; anything
        // else matching the English string is an untranslated leftover.
        const shared = {
          'appTitle',
          'languageEnglish',
          'languageUkrainian',
          'languageGerman',
          // identical in German by coincidence, not by omission
          'aboutVersion',
          'overlayOriginal',
          'detailsModel',
        };
        final untranslated = [
          for (final key in templateKeys)
            if (!shared.contains(key) && translation[key] == template[key]) key,
        ];
        expect(untranslated, isEmpty);
      });

      test('placeholders match the template exactly', () {
        for (final key in templateKeys) {
          final expected = _placeholders(template[key] as String);
          final actual = _placeholders(translation[key] as String);
          expect(actual, expected,
              reason: 'placeholder mismatch in $code for "$key"');
        }
      });

      test('no value is empty', () {
        for (final key in keys) {
          expect((translation[key] as String).trim(), isNotEmpty,
              reason: '$key is empty in app_$code.arb');
        }
      });
    });
  }
}

Set<String> _placeholders(String value) => RegExp(r'\{(\w+)\}')
    .allMatches(value)
    .map((m) => m.group(1)!)
    .toSet();
