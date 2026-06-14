export interface Language {
  code: string;
  name: string;
}

// CLDR parent locale map — keys and values are lowercased for case-insensitive lookup
const parentLocales: Record<string, string> = {
  'en-150': 'en-001', 'en-ag': 'en-001', 'en-ai': 'en-001', 'en-au': 'en-001',
  'en-bb': 'en-001', 'en-bm': 'en-001', 'en-bs': 'en-001', 'en-bw': 'en-001',
  'en-bz': 'en-001', 'en-cc': 'en-001', 'en-ck': 'en-001', 'en-cm': 'en-001',
  'en-cx': 'en-001', 'en-cy': 'en-001', 'en-dg': 'en-001', 'en-dm': 'en-001',
  'en-er': 'en-001', 'en-fj': 'en-001', 'en-fk': 'en-001', 'en-fm': 'en-001',
  'en-gb': 'en-001', 'en-gd': 'en-001', 'en-gg': 'en-001', 'en-gh': 'en-001',
  'en-gi': 'en-001', 'en-gm': 'en-001', 'en-gs': 'en-001', 'en-gy': 'en-001',
  'en-hk': 'en-001', 'en-id': 'en-001', 'en-ie': 'en-001', 'en-il': 'en-001',
  'en-im': 'en-001', 'en-in': 'en-001', 'en-io': 'en-001', 'en-je': 'en-001',
  'en-jm': 'en-001', 'en-ke': 'en-001', 'en-ki': 'en-001', 'en-kn': 'en-001',
  'en-ky': 'en-001', 'en-lc': 'en-001', 'en-lr': 'en-001', 'en-ls': 'en-001',
  'en-mg': 'en-001', 'en-mo': 'en-001', 'en-ms': 'en-001', 'en-mt': 'en-001',
  'en-mu': 'en-001', 'en-mv': 'en-001', 'en-mw': 'en-001', 'en-my': 'en-001',
  'en-na': 'en-001', 'en-nf': 'en-001', 'en-ng': 'en-001', 'en-nr': 'en-001',
  'en-nu': 'en-001', 'en-nz': 'en-001', 'en-pg': 'en-001', 'en-pk': 'en-001',
  'en-pn': 'en-001', 'en-pw': 'en-001', 'en-rw': 'en-001', 'en-sb': 'en-001',
  'en-sc': 'en-001', 'en-sd': 'en-001', 'en-sg': 'en-001', 'en-sh': 'en-001',
  'en-sl': 'en-001', 'en-ss': 'en-001', 'en-sx': 'en-001', 'en-sz': 'en-001',
  'en-tc': 'en-001', 'en-tk': 'en-001', 'en-to': 'en-001', 'en-tt': 'en-001',
  'en-tv': 'en-001', 'en-tz': 'en-001', 'en-ug': 'en-001', 'en-vc': 'en-001',
  'en-vg': 'en-001', 'en-vu': 'en-001', 'en-ws': 'en-001', 'en-za': 'en-001',
  'en-zm': 'en-001', 'en-zw': 'en-001',
  'en-at': 'en-150', 'en-be': 'en-150', 'en-ch': 'en-150', 'en-cz': 'en-150',
  'en-de': 'en-150', 'en-dk': 'en-150', 'en-ee': 'en-150', 'en-es': 'en-150',
  'en-fi': 'en-150', 'en-fr': 'en-150', 'en-ge': 'en-150', 'en-hu': 'en-150',
  'en-it': 'en-150', 'en-lt': 'en-150', 'en-lv': 'en-150', 'en-nl': 'en-150',
  'en-no': 'en-150', 'en-pl': 'en-150', 'en-pt': 'en-150', 'en-ro': 'en-150',
  'en-se': 'en-150', 'en-si': 'en-150', 'en-sk': 'en-150', 'en-ua': 'en-150',
  'hi-latn': 'en-in',
  'es-ar': 'es-419', 'es-bo': 'es-419', 'es-br': 'es-419', 'es-bz': 'es-419',
  'es-cl': 'es-419', 'es-co': 'es-419', 'es-cr': 'es-419', 'es-cu': 'es-419',
  'es-do': 'es-419', 'es-ec': 'es-419', 'es-gt': 'es-419', 'es-hn': 'es-419',
  'es-jp': 'es-419', 'es-mx': 'es-419', 'es-ni': 'es-419', 'es-pa': 'es-419',
  'es-pe': 'es-419', 'es-pr': 'es-419', 'es-py': 'es-419', 'es-sv': 'es-419',
  'es-us': 'es-419', 'es-uy': 'es-419', 'es-ve': 'es-419',
  'ht': 'fr-ht', 'nb': 'no', 'nn': 'no', 'no-no': 'no',
  'pt-ao': 'pt-pt', 'pt-ch': 'pt-pt', 'pt-cv': 'pt-pt', 'pt-fr': 'pt-pt',
  'pt-gq': 'pt-pt', 'pt-gw': 'pt-pt', 'pt-lu': 'pt-pt', 'pt-mo': 'pt-pt',
  'pt-mz': 'pt-pt', 'pt-st': 'pt-pt', 'pt-tl': 'pt-pt',
  'az-arab': 'und', 'az-cyrl': 'und', 'bal-latn': 'und', 'blt-latn': 'und',
  'bm-nkoo': 'und', 'bs-cyrl': 'und', 'byn-latn': 'und', 'cu-glag': 'und',
  'dje-arab': 'und', 'dyo-arab': 'und', 'en-dsrt': 'und', 'en-shaw': 'und',
  'ff-adlm': 'und', 'ff-arab': 'und', 'ha-arab': 'und', 'iu-latn': 'und',
  'kaa-latn': 'und', 'kk-arab': 'und', 'kok-latn': 'und', 'ks-deva': 'und',
  'ku-arab': 'und', 'kxv-deva': 'und', 'kxv-orya': 'und', 'kxv-telu': 'und',
  'ky-arab': 'und', 'ky-latn': 'und', 'ml-arab': 'und', 'mn-mong': 'und',
  'mni-mtei': 'und', 'ms-arab': 'und', 'pa-arab': 'und', 'sat-deva': 'und',
  'sd-deva': 'und', 'sd-khoj': 'und', 'sd-sind': 'und', 'shi-latn': 'und',
  'so-arab': 'und', 'sr-latn': 'und', 'sw-arab': 'und', 'suz-sunu': 'und',
  'tg-arab': 'und', 'ug-cyrl': 'und', 'uz-arab': 'und', 'uz-cyrl': 'und',
  'vai-latn': 'und', 'wo-arab': 'und', 'yo-arab': 'und', 'yue-hans': 'und',
  'zh-hant': 'und', 'zh-hant-mo': 'zh-hant-hk',
};

/**
 * Resolves a BCP 47 tag against a list of available languages.
 * Resolution order per tag:
 *   1. Exact match (case-insensitive)
 *   2. Walk CLDR parent chain (stop at "und" or no entry)
 *   3. Sibling scan: available languages starting with tag + '-'
 *   4. Strip last segment, recurse
 */
export function resolveLocale(tag: string, available: Language[]): Language | null {
  const normalised = tag.toLowerCase();

  const exact = available.find((l) => l.code.toLowerCase() === normalised);
  if (exact) return exact;

  let current: string | undefined = normalised;
  const visited = new Set<string>();
  while (true) {
    const parent = parentLocales[current]?.toLowerCase();
    if (!parent || parent === 'und' || visited.has(parent)) break;
    visited.add(parent);
    const parentMatch = available.find((l) => l.code.toLowerCase() === parent);
    if (parentMatch) return parentMatch;
    current = parent;
  }

  const prefix = `${normalised}-`;
  const sibling = available.find((l) => l.code.toLowerCase().startsWith(prefix));
  if (sibling) return sibling;

  const lastDash = normalised.lastIndexOf('-');
  if (lastDash === -1) return null;
  return resolveLocale(normalised.substring(0, lastDash), available);
}

/**
 * Selects the best matching language given the user's preferred locales.
 *
 * @param userLanguages     Ordered BCP 47 tags from the user/device (e.g. navigator.languages)
 * @param defaultLanguage   App-configured fallback language code (e.g. from info.json), or null
 * @param availableLanguages  Languages available in this translation set
 * @returns The best matching Language, never null (falls back to first available)
 */
export function selectBestLanguage(
  userLanguages: string[],
  defaultLanguage: string | null,
  availableLanguages: Language[],
): Language {
  for (const locale of userLanguages) {
    const resolved = resolveLocale(locale, availableLanguages);
    if (resolved) return resolved;
  }

  if (defaultLanguage) {
    const resolved = resolveLocale(defaultLanguage, availableLanguages);
    if (resolved) return resolved;
  }

  const en = resolveLocale('en', availableLanguages);
  if (en) return en;

  return availableLanguages[0];
}
