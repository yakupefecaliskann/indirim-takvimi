// Kaynak: Picodi Turkiye marka sayfalari.
//
// Neden bu kaynak: markalarin kendi siteleri ya JavaScript ile yukleniyor
// (Gratis) ya da bot korumasi nedeniyle 403 donuyor (Watsons, Sephora).
// Picodi marka sayfalari duz HTML veriyor ve robots.txt bu sayfalari
// yasaklamiyor (yalnizca /tr/kupon/*, /tr/coupon/*, /tr/offer/* yasakli).
//
// ONEMLI SINIR: kupon **kod dizeleri** HTML'de yok; tiklamayla /tr/kupon/*
// uzerinden aciliyor ve orasi robots.txt'de yasakli. Bu yuzden kod dizeleri
// toplanmiyor. Kod gerektiren firsatlar `requiresCode: true` ile isaretlenip
// kaynak baglantisiyla birlikte veriliyor — uydurma kod uretilmiyor.

import * as cheerio from 'cheerio';
import { fetchText, sleep } from '../http.js';

/** Uygulamadaki marka kimligi -> Picodi sayfa adi. */
const BRAND_SLUGS = {
  gratis: 'gratis',
  watsons: 'watsons',
  sephora: 'sephora',
  rossmann: 'rossmann',
  zara: 'zara',
  bershka: 'bershka',
  pullandbear: 'pullandbear',
  stradivarius: 'stradivarius',
  oysho: 'oysho',
};

const BASE = 'https://www.picodi.com/tr/';

export const name = 'picodi';

/**
 * @param {{today: string}} ctx
 * @returns {Promise<{offers: object[], notes: string[]}>}
 */
export async function collect({ today }) {
  const offers = [];
  const notes = [];

  for (const [brandId, slug] of Object.entries(BRAND_SLUGS)) {
    const url = BASE + slug;
    try {
      const html = await fetchText(url);
      const parsed = parsePicodiPage(html, { brandId, url, today });
      offers.push(...parsed);
      notes.push(`${brandId}: ${parsed.length} firsat`);
    } catch (err) {
      // Tek bir markanin basarisiz olmasi digerlerini etkilemez.
      notes.push(`${brandId}: HATA ${err.message}`);
    }
    // Kaynaga yuk bindirmemek icin istekler arasi bekleme.
    await sleep(1500);
  }

  return { offers, notes };
}

/**
 * Picodi marka sayfasindaki firsatlari ayristirir. Saf fonksiyon — test edilir.
 */
export function parsePicodiPage(html, { brandId, url, today }) {
  const $ = cheerio.load(html);
  const offers = [];

  $('li.of').each((_, el) => {
    const $el = $(el);
    const classes = ($el.attr('class') || '').split(/\s+/);
    const isCode = classes.includes('type-code');
    const isPromo = classes.includes('type-promo');
    if (!isCode && !isPromo) return;

    const offerId = $el.attr('data-offer-id');
    if (!offerId) return;

    const title = clean($el.find('.of__title').first().text());
    if (!title) return;

    const description = clean($el.find('.of__description').first().text());
    const expiresAt = parseExpiry($el.attr('data-c'));

    offers.push({
      id: `picodi-${brandId}-${offerId}`,
      brand: brandId,
      title,
      description,
      // Kod dizesi kaynakta acik degil; uydurulmuyor.
      code: null,
      requiresCode: isCode,
      expiresAt,
      lastSeenAt: today,
      sourceUrl: url,
    });
  });

  return offers;
}

/**
 * `data-c` degeri "2099/12/31T23:59:59" biciminde.
 * 2090 sonrasi "suresiz" anlamina geliyor; bunu son kullanma tarihi saymiyoruz.
 */
export function parseExpiry(raw) {
  if (typeof raw !== 'string') return null;
  const m = raw.match(/^(\d{4})\/(\d{2})\/(\d{2})/);
  if (!m) return null;
  const year = Number(m[1]);
  if (year >= 2090) return null;
  return `${m[1]}-${m[2]}-${m[3]}`;
}

const clean = (s) => (s || '').replace(/\s+/g, ' ').trim();
