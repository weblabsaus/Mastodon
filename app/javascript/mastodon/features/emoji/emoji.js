import unicodeMapping from './emoji_unicode_mapping_light';
import Trie from 'substring-trie';

const trie = new Trie(Object.keys(unicodeMapping));

const assetHost = process.env.CDN_HOST || '';

let allowAnimations = false;

const emojify = (str, customEmojis = {}) => {
  let rtn = '';
  for (;;) {
    let match, i = 0, tag;
    while (i < str.length && (tag = '<&:'.indexOf(str[i])) === -1 && !(match = trie.search(str.slice(i)))) {
      i += str.codePointAt(i) < 65536 ? 1 : 2;
    }
    let rend, replacement = '';
    if (i === str.length) {
      break;
    } else if (str[i] === ':') {
      if (!(() => {
        rend = str.indexOf(':', i + 1) + 1;
        if (!rend) return false; // no pair of ':'
        const lt = str.indexOf('<', i + 1);
        if (!(lt === -1 || lt >= rend)) return false; // tag appeared before closing ':'
        const shortname = str.slice(i, rend);
        // now got a replacee as ':shortname:'
        // if you want additional emoji handler, add statements below which set replacement and return true.
        const nicoru = /^:nicoru(-?\d+)?:$/.exec(shortname);
        if (nicoru) {
          replacement = `<img alt="${shortname}" title="${shortname}" src="/emoji/nicoru.svg" style="height: 1.5em; transform: rotate(${nicoru[1] || 0}deg)"/>`;
          return true;
        }
        if (shortname in customEmojis) {
          const filename = allowAnimations ? customEmojis[shortname].url : customEmojis[shortname].static_url;
          replacement = `<img draggable="false" class="emojione" alt="${shortname}" title="${shortname}" src="${filename}" />`;
          return true;
        }
        return false;
      })()) rend = ++i;
    } else if (tag >= 0) { // <, &
      rend = str.indexOf('>;'[tag], i + 1) + 1;
      if (!rend) break;
      i = rend;
    } else { // matched to unicode emoji
      const { filename, shortCode } = unicodeMapping[match];
      const title = shortCode ? `:${shortCode}:` : '';
      replacement = `<img draggable="false" class="emojione" alt="${match}" title="${title}" src="${assetHost}/emoji/${filename}.svg" />`;
      rend = i + match.length;
    }
    rtn += str.slice(0, i) + replacement;
    str = str.slice(rend);
  }
  return rtn + str;
};

const emojify_knzk = (str, customEmojis = {}) => [
  {re: /5,?000\s*兆円/g, file: '5000tyoen.svg', attrs: 'style="height: 1.8em;"'}, 
  {re: /卍/g, file: 'manzi.svg', attrs: 'style="height: 1.5em;"'}, 
  {re: /熱盛/g, file: 'atumori.svg', attrs: 'style="height: 2.5em;"'}, 
  {re: /バジリスク\s*タイム/g, file: 'basilisktime.png', attrs: 'height="40"'},
  {re: /欲しい！/g, file: 'hosii.png', attrs: 'height="30"'},
].reduce((text, e) => text.replace(e.re, m => `<img alt="${m}" src="/emoji/${e.file}" ${e.attrs}/>`), emojify(str, customEmojis));

export default emojify_knzk;

export const buildCustomEmojis = (customEmojis, overrideAllowAnimations = false) => {
  const emojis = [];

  allowAnimations = overrideAllowAnimations;

  customEmojis.forEach(emoji => {
    const shortcode = emoji.get('shortcode');
    const url       = allowAnimations ? emoji.get('url') : emoji.get('static_url');
    const name      = shortcode.replace(':', '');

    emojis.push({
      id: name,
      name,
      short_names: [name],
      text: '',
      emoticons: [],
      keywords: [name],
      imageUrl: url,
      custom: true,
    });
  });

  return emojis;
};
