// U+0590  to U+05FF  - Hebrew
// U+0600  to U+06FF  - Arabic
// U+0700  to U+074F  - Syriac
// U+0750  to U+077F  - Arabic Supplement
// U+0780  to U+07BF  - Thaana
// U+07C0  to U+07FF  - N'Ko
// U+0800  to U+083F  - Samaritan
// U+08A0  to U+08FF  - Arabic Extended-A
// U+FB1D  to U+FB4F  - Hebrew presentation forms
// U+FB50  to U+FDFF  - Arabic presentation forms A
// U+FE70  to U+FEFF  - Arabic presentation forms B

const rtlChars = /[\u0590-\u083F]|[\u08A0-\u08FF]|[\uFB1D-\uFDFF]|[\uFE70-\uFEFF]/mg;

export function isRtl(text) {
  if (text.length === 0) {
    return false;
  }

  const matches = text.match(rtlChars);

  if (!matches) {
    return false;
  }

  // Remove mentions before counting characters to decide RTL ratio
  const justtext = text.replace(/@[0-9a-z_@]+/gi, '')

  return matches.length / justtext.trim().length > 0.3;
};
