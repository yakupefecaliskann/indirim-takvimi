import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parsePicodiPage, parseExpiry } from '../src/sources/picodi.js';

const HERE = dirname(fileURLToPath(import.meta.url));
// Gercek Picodi ciktisindan alinmis fixture — uydurma HTML degil.
const HTML = readFileSync(join(HERE, 'fixtures', 'picodi-gratis.html'), 'utf8');

const opts = {
  brandId: 'gratis',
  url: 'https://www.picodi.com/tr/gratis',
  today: '2026-08-28',
};

test('gercek sayfadan tum firsatlar cikarilir', () => {
  const offers = parsePicodiPage(HTML, opts);
  assert.equal(offers.length, 7);
});

test('firsat alanlari dogru doldurulur', () => {
  const [first] = parsePicodiPage(HTML, opts);
  assert.equal(first.brand, 'gratis');
  assert.equal(first.lastSeenAt, '2026-08-28');
  assert.equal(first.sourceUrl, opts.url);
  assert.ok(first.id.startsWith('picodi-gratis-'));
  assert.ok(first.title.length > 0);
});

test('kod dizesi asla uydurulmaz', () => {
  const offers = parsePicodiPage(HTML, opts);
  assert.ok(offers.every((o) => o.code === null));
});

test('kimlikler benzersiz ve kararli', () => {
  const a = parsePicodiPage(HTML, opts).map((o) => o.id);
  const b = parsePicodiPage(HTML, opts).map((o) => o.id);
  assert.deepEqual(a, b);
  assert.equal(new Set(a).size, a.length);
});

test('bos HTML cokmez', () => {
  assert.deepEqual(parsePicodiPage('', opts), []);
  assert.deepEqual(parsePicodiPage('<html><body></body></html>', opts), []);
});

test('bozuk HTML cokmez', () => {
  const broken = '<li class="of of--row type-promo" data-offer-id="1"><div>';
  assert.deepEqual(parsePicodiPage(broken, opts), []);
});

test('baslik yoksa kayit atlanir', () => {
  const noTitle =
    '<ul><li class="of of--row type-promo" data-offer-id="9"><h3 class="of__title"></h3></li></ul>';
  assert.deepEqual(parsePicodiPage(noTitle, opts), []);
});

test('type-code isaretli firsat kod gerektiriyor olarak damgalanir', () => {
  const codeOffer =
    '<ul><li class="of of--row type-code" data-offer-id="55">' +
    '<h3 class="of__title">Watsons %50</h3></li></ul>';
  const [o] = parsePicodiPage(codeOffer, opts);
  assert.equal(o.requiresCode, true);
  assert.equal(o.code, null);
});

test('parseExpiry: 2090 sonrasi suresiz sayilir', () => {
  assert.equal(parseExpiry('2099/12/31T23:59:59'), null);
  assert.equal(parseExpiry('2026/09/30T23:59:59'), '2026-09-30');
  assert.equal(parseExpiry(undefined), null);
  assert.equal(parseExpiry('sacma'), null);
});
