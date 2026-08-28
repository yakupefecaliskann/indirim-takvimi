import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseTurkishDates,
  inferYear,
  pickConsensusDate,
  toIsoDate,
} from '../src/dates.js';

test('gun + ay yakalanir', () => {
  const found = parseTurkishDates('İndirim 24 Haziran tarihinde başlıyor');
  assert.equal(found.length, 1);
  assert.deepEqual({ d: found[0].day, m: found[0].month }, { d: 24, m: 6 });
});

test('Turkce karakter olmadan yazilan aylar da yakalanir', () => {
  assert.equal(parseTurkishDates('7 Ocak')[0].month, 1);
  assert.equal(parseTurkishDates('1 subat')[0].month, 2);
  assert.equal(parseTurkishDates('5 agustos')[0].month, 8);
  assert.equal(parseTurkishDates('30 aralik')[0].month, 12);
  assert.equal(parseTurkishDates('11 Kasım')[0].month, 11);
});

test('yil metinde varsa kullanilir', () => {
  const found = parseTurkishDates('27 Kasım 2026 Black Friday');
  assert.equal(found[0].year, 2026);
});

test('gecersiz gun elenir', () => {
  assert.equal(parseTurkishDates('32 Ocak').length, 0);
  assert.equal(parseTurkishDates('0 Ocak').length, 0);
});

test('ayni metindeki birden fazla tarih yakalanir', () => {
  const found = parseTurkishDates('online 24 Haziran, magazalarda 25 Haziran');
  assert.equal(found.length, 2);
});

test('baslangic baglami isaretlenir', () => {
  const [a] = parseTurkishDates('indirim 24 Haziran günü başlıyor');
  assert.equal(a.looksLikeStart, true);
  const [b] = parseTurkishDates('indirim 24 Haziran günü sona erdi');
  assert.equal(b.looksLikeStart, false);
});

test('inferYear: gecmis ay gelecek yila kayar', () => {
  const now = new Date('2026-08-28T00:00:00Z');
  // Ocak cok geride kaldi -> gelecek yil
  assert.equal(inferYear(1, 7, now), 2027);
  // Kasim bu yil daha gelmedi -> bu yil
  assert.equal(inferYear(11, 27, now), 2026);
});

test('inferYear: yakin gecmisteki tarih bu yilda kalir', () => {
  const now = new Date('2026-08-28T00:00:00Z');
  // Agustos basi sadece birkac hafta once
  assert.equal(inferYear(8, 1, now), 2026);
});

test('pickConsensusDate: en az iki kaynak ayni tarihte anlasmali', () => {
  assert.equal(pickConsensusDate(['2026-06-24']), null);
  assert.equal(pickConsensusDate(['2026-06-24', '2026-06-24']), '2026-06-24');
});

test('pickConsensusDate: cogunluk kazanir', () => {
  const votes = ['2026-06-24', '2026-06-24', '2026-06-24', '2026-06-25', '2026-06-25'];
  assert.equal(pickConsensusDate(votes), '2026-06-24');
});

test('pickConsensusDate: bos girdi null', () => {
  assert.equal(pickConsensusDate([]), null);
});

test('toIsoDate gun basina sabitler', () => {
  assert.equal(toIsoDate(2026, 6, 24), '2026-06-24');
  assert.equal(toIsoDate(2027, 1, 6), '2027-01-06');
});
