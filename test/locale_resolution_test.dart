import 'package:flutter_test/flutter_test.dart';
import 'package:translations_service_integration/main.dart';

// Shorthand: creates a Language with code as name for brevity in tests.
Language l(String code) => Language(code, code);

void main() {
  Language? resolve(String tag, List<Language> available) =>
      resolveLocaleForTesting(tag, available);

  group('exact match', () {
    test('matches on identical code', () {
      final available = [l('en'), l('fr'), l('de')];
      expect(resolve('en', available), l('en'));
    });

    test('is case-insensitive', () {
      final available = [l('en-US'), l('fr')];
      expect(resolve('EN-US', available), l('en-US'));
      expect(resolve('en-us', available), l('en-US'));
    });

    test('prefers exact match over sibling', () {
      final available = [l('en-GB'), l('en')];
      expect(resolve('en', available), l('en'));
    });
  });

  group('CLDR parent chain', () {
    test('es-MX resolves to es-419 (single hop)', () {
      final available = [l('es-419'), l('es-ES')];
      expect(resolve('es-MX', available), l('es-419'));
    });

    test('en-AT resolves to en-001 via en-150 (multi-hop)', () {
      final available = [l('en-001'), l('de-DE')];
      expect(resolve('en-AT', available), l('en-001'));
    });

    test('nb resolves to no (single hop)', () {
      final available = [l('no'), l('sv')];
      expect(resolve('nb', available), l('no'));
    });

    test('nn resolves to no (single hop)', () {
      final available = [l('no'), l('sv')];
      expect(resolve('nn', available), l('no'));
    });

    test('und parent is never returned as a match even if und is in the list', () {
      // sr-Latn → parent 'und'; the chain stops and 'und' is not selected
      // sibling sr-latn-*: none; strip to sr: no sr in this list → null
      expect(resolve('sr-Latn', [l('und'), l('hr')]), isNull);
    });

    test('und stops parent chain but strip-and-recurse continues', () {
      // sr-Latn → und (chain stops) → sibling sr-latn-*: none
      // → strip to sr → exact match sr
      expect(resolve('sr-Latn', [l('sr'), l('hr')]), l('sr'));
    });

    test('cycle guard prevents infinite loop on malformed data', () {
      // _parentLocales has no cycles in practice, but the visited-set guards it.
      // Verify a long chain terminates correctly without hanging.
      final available = [l('root')];
      expect(resolve('en-AT', available), isNull); // chain exhausts, no match
    });
  });

  group('sibling scan', () {
    test('en with [en-GB, en-US] returns first in server order', () {
      final available = [l('en-GB'), l('en-US')];
      expect(resolve('en', available), l('en-GB'));
    });

    test('server order determines sibling tiebreaker', () {
      final available = [l('en-US'), l('en-GB')];
      expect(resolve('en', available), l('en-US'));
    });

    test('zh-Hant with [zh-Hant-TW] returns sibling', () {
      final available = [l('zh-Hant-TW'), l('zh-Hans-CN')];
      expect(resolve('zh-Hant', available), l('zh-Hant-TW'));
    });
  });

  group('strip-and-recurse', () {
    test('en-GB with [en-US, de-DE] strips to en then sibling matches en-US', () {
      // en-GB → parent en-001 (not in list)
      // sibling en-gb-*: none
      // strip to en → sibling en-* → en-US
      final available = [l('en-US'), l('de-DE')];
      expect(resolve('en-GB', available), l('en-US'));
    });

    test('zh-Hant-HK strips to zh-Hant then sibling scan finds zh-Hant-TW', () {
      final available = [l('zh-Hant-TW'), l('zh-Hans-CN')];
      expect(resolve('zh-Hant-HK', available), l('zh-Hant-TW'));
    });

    test('three-segment tag strips progressively', () {
      // pt-BR-x strips to pt-BR (no match, no parent, no sibling),
      // then to pt which exact-matches
      final available = [l('pt')];
      expect(resolve('pt-BR-x', available), l('pt'));
    });
  });

  group('plan resolution table', () {
    test('es-MX | [es-419, es-ES] → es-419 via CLDR parent', () {
      expect(resolve('es-MX', [l('es-419'), l('es-ES')]), l('es-419'));
    });

    test('en-GB | [en-US, de-DE] → en-US via strip+sibling', () {
      expect(resolve('en-GB', [l('en-US'), l('de-DE')]), l('en-US'));
    });

    test('en-AT | [en-001, de-DE] → en-001 via CLDR chain', () {
      expect(resolve('en-AT', [l('en-001'), l('de-DE')]), l('en-001'));
    });

    test('zh-Hant-HK | [zh-Hant-TW, zh-Hans-CN] → zh-Hant-TW via strip+sibling', () {
      expect(resolve('zh-Hant-HK', [l('zh-Hant-TW'), l('zh-Hans-CN')]), l('zh-Hant-TW'));
    });

    test('en | [en-GB, en-US] → en-GB via sibling (server order)', () {
      expect(resolve('en', [l('en-GB'), l('en-US')]), l('en-GB'));
    });

    test('uk-UA | [de-DE] → null (no path exists)', () {
      expect(resolve('uk-UA', [l('de-DE')]), isNull);
    });
  });

  group('edge cases', () {
    test('empty available list returns null', () {
      expect(resolve('en', []), isNull);
    });

    test('single-item list matches if resolution succeeds', () {
      expect(resolve('es-MX', [l('es-419')]), l('es-419'));
    });

    test('single-item list returns null when no resolution path', () {
      expect(resolve('uk-UA', [l('de-DE')]), isNull);
    });

    test('exact match on base language', () {
      expect(resolve('uk', [l('uk')]), l('uk'));
    });

    test('unknown tag with no parent and no sibling returns null', () {
      expect(resolve('xx-YY', [l('de')]), isNull);
    });

    test('resolves case-mixed tag against mixed-case available code', () {
      final available = [l('es-419')];
      expect(resolve('ES-419', available), l('es-419'));
    });

    test('saved preference: es-MX resolves to es-419 when es-MX removed', () {
      // Simulates the saved-preference flow: user had es-MX, now only es-419 is offered
      final available = [l('es-419'), l('en')];
      expect(resolve('es-MX', available), l('es-419'));
    });

    test('saved preference: exact code still preferred if still present', () {
      final available = [l('es-419'), l('es-MX'), l('en')];
      expect(resolve('es-MX', available), l('es-MX'));
    });

    test('tag that is exactly a parent locale code is exact-matched', () {
      // es-419 is itself a parent for es-* LatAm variants; exact-match works
      final available = [l('es-419'), l('es')];
      expect(resolve('es-419', available), l('es-419'));
    });
  });
}
