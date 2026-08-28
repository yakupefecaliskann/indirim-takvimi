import test from 'node:test';
import assert from 'node:assert/strict';

import { shouldWrite, dedupeById } from '../src/main.js';
import { extractStartDate, isNearMonth, parseRssItems } from '../src/sources/news.js';

const now = new Date('2026-08-28T00:00:00Z');

test('shouldWrite: bos cikti asla yayinlanmaz', () => {
  const next = { campaigns: [], codes: [] };
  assert.equal(shouldWrite({ campaigns: [1], codes: [2] }, next).write, false);
});

test('shouldWrite: ilk calistirmada yazar', () => {
  const next = { campaigns: [{ id: 'a' }], codes: [] };
  assert.equal(shouldWrite(null, next).write, true);
});

test('shouldWrite: ciddi kuculmede yazmaz (son iyi veri korunur)', () => {
  const previous = { campaigns: new Array(10).fill({}), codes: new Array(30).fill({}) };
  const next = { campaigns: [{ id: 'a' }], codes: [{ id: 'b' }] };
  const d = shouldWrite(previous, next);
  assert.equal(d.write, false);
  assert.match(d.reason, /kucul/);
});

test('shouldWrite: normal guncellemede yazar', () => {
  const previous = { campaigns: new Array(10).fill({}), codes: new Array(30).fill({}) };
  const next = { campaigns: new Array(10).fill({ id: 'a' }), codes: new Array(28).fill({ id: 'b' }) };
  assert.equal(shouldWrite(previous, next).write, true);
});

test('shouldWrite: tek kaynak calistirmasi yayinlanmaz', () => {
  const previous = { campaigns: [{}], codes: [{}] };
  const next = { campaigns: [{ id: 'a' }], codes: [{ id: 'b' }] };
  assert.equal(shouldWrite(previous, next, { partialRun: true }).write, false);
});

test('dedupeById: son kayit kazanir, sira korunur', () => {
  const out = dedupeById([
    { id: 'a', v: 1 },
    { id: 'b', v: 2 },
    { id: 'a', v: 3 },
    null,
    { noId: true },
  ]);
  assert.equal(out.length, 2);
  assert.equal(out.find((x) => x.id === 'a').v, 3);
});

test('isNearMonth: ocak ile aralik komsu sayilir', () => {
  assert.equal(isNearMonth(12, 1), true);
  assert.equal(isNearMonth(1, 1), true);
  assert.equal(isNearMonth(2, 1), true);
  assert.equal(isNearMonth(6, 1), false);
});

test('extractStartDate: yaklasan tarihi bulur', () => {
  const text = 'Inditex yaz indirimi 24 Haziran Çarşamba günü online başlıyor';
  const haziranOncesi = new Date('2026-06-01T00:00:00Z');
  assert.equal(extractStartDate(text, 6, haziranOncesi), '2026-06-24');
});

test('extractStartDate: gecmis olayi gelecek yila tasimaz', () => {
  // Agustosta okunan haziran haberi gecen haziranla ilgilidir; 2027 duyurusu
  // uydurmak yerine hicbir sey donmeli.
  const text = 'Inditex yaz indirimi 24 Haziran günü başlıyor';
  assert.equal(extractStartDate(text, 6, now), null);
});

test('extractStartDate: cok uzak tarihi reddeder', () => {
  const text = 'Yaz indirimi 24 Haziran 2028 tarihinde başlıyor';
  assert.equal(extractStartDate(text, 6, now), null);
});

test('extractStartDate: yanlis aydaki tarihi reddeder', () => {
  const text = 'Kampanya 3 Mart tarihinde başlıyor';
  assert.equal(extractStartDate(text, 6, now), null);
});

test('extractStartDate: bitis baglamindaki tarihi baslangic saymaz', () => {
  const text = 'Yaz indirimi 31 Ağustos tarihinde sona eriyor';
  assert.equal(extractStartDate(text, 6, now), null);
});

test('extractStartDate: tarih yoksa null', () => {
  assert.equal(extractStartDate('indirim yakinda başlıyor', 6, now), null);
  assert.equal(extractStartDate('', 6, now), null);
});

test('extractStartDate: ocak tarihi gelecek yila kayar', () => {
  const text = 'Zara kış indirimi 6 Ocak günü başlıyor';
  assert.equal(extractStartDate(text, 1, now), '2027-01-06');
});

test('parseRssItems: baslik ve aciklamayi birlestirir', () => {
  const xml = `<?xml version="1.0"?><rss><channel>
    <item><title>Zara indirimi</title><description>&lt;p&gt;24 Haziran&lt;/p&gt;</description>
    <link>https://example.com/a</link></item>
  </channel></rss>`;
  const items = parseRssItems(xml);
  assert.equal(items.length, 1);
  assert.match(items[0].text, /Zara indirimi/);
  assert.match(items[0].text, /24 Haziran/);
  assert.equal(items[0].link, 'https://example.com/a');
});

test('parseRssItems: bozuk XML cokmez', () => {
  assert.deepEqual(parseRssItems('bu xml degil'), []);
  assert.deepEqual(parseRssItems(''), []);
});
