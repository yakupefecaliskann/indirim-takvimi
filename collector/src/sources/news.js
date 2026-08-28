// Kaynak: Google News RSS (Turkce). **Bonus katman — omurga degil.**
//
// Amac: hesaplanan *tahmini* tarihi, haberlerde ilan edilmis *kesin* tarihle
// degistirmek. Uretilen kampanya kimlikleri uygulamadaki hesaplanan takvimin
// kimlikleriyle birebir ayni (`inditex-yaz-2027` gibi) — birlestirme bu kimlik
// uzerinden calisiyor.
//
// OLCULMUS SINIR (2026-08 itibariyla, canli olarak test edildi):
// Google News RSS aciklamalari makale **govdesini icermiyor**, yalnizca basligi
// tekrarliyor. Indirim tarihi ise govdede geciyor. Makale baglantilari da
// news.google.com yonlendirmesi oldugu icin dogrudan cekilemiyor (JS kabugu
// donuyor). 266 haber uzerinde olculdu: yalnizca 11'inde tarih vardi, 3'u
// "baslangic" baglamindaydi ve **ucu de eski haberlere ait yanlis pozitifti**
// — asagidaki filtreler ucunu de eledi.
//
// Bu yuzden bu kaynak cogu zaman bos doner ve bu **beklenen davranistir**:
// uygulama hesapladigi tahminde kalir. Yine de ucuz (calistirma basina 3-5
// istek) ve guvenli: basligin tarih tasidigi durumlari yakalar, yanlis tarih
// uretmez. Uygulamanin dogru calismasi bu katmana bagli degil.

import * as cheerio from 'cheerio';
import { fetchText, sleep } from '../http.js';
import {
  parseTurkishDates,
  inferYear,
  toIsoDate,
  pickConsensusDate,
} from '../dates.js';

export const name = 'news';

const INDITEX = ['zara', 'bershka', 'pullandbear', 'stradivarius', 'oysho'];

/**
 * Takip edilen olaylar.
 *
 * `monthHint`, cikarilan tarihin beklenen ayda olup olmadigini denetler —
 * alakasiz bir haberden gelen rastgele tarihin sisteme sizmasini engelleyen
 * en onemli filtre.
 */
const EVENTS = [
  {
    idFor: (y) => `inditex-yaz-${y}`,
    title: 'Inditex Yaz Sezon Sonu İndirimi',
    brands: INDITEX,
    monthHint: 6,
    queries: [
      'Zara yaz indirimi ne zaman başlıyor',
      'Inditex yaz indirimi tarihi Bershka Pull and Bear',
    ],
  },
  {
    idFor: (y) => `inditex-kis-${y}`,
    title: 'Inditex Kış Sezon Sonu İndirimi',
    brands: INDITEX,
    monthHint: 1,
    queries: [
      'Zara kış indirimi ne zaman başlıyor',
      'Inditex kış sezon sonu indirimi tarihi',
    ],
  },
  {
    idFor: (y) => `black-friday-${y}`,
    title: 'Black Friday (Kara Cuma)',
    brands: ['genel'],
    monthHint: 11,
    queries: ['Black Friday Kara Cuma ne zaman Türkiye'],
  },
];

const rssUrl = (q) =>
  `https://news.google.com/rss/search?q=${encodeURIComponent(q)}&hl=tr&gl=TR&ceid=TR:tr`;

export async function collect({ today, now = new Date() }) {
  const campaigns = [];
  const notes = [];

  for (const event of EVENTS) {
    const votes = [];
    const sources = [];

    for (const q of event.queries) {
      try {
        const xml = await fetchText(rssUrl(q));
        const items = parseRssItems(xml);
        for (const item of items) {
          const iso = extractStartDate(item.text, event.monthHint, now);
          if (iso) {
            votes.push(iso);
            sources.push(item.link);
          }
        }
      } catch (err) {
        notes.push(`${event.idFor('?')} sorgu hatasi: ${err.message}`);
      }
      await sleep(1200);
    }

    // En az iki bagimsiz haber ayni tarihte anlasmadikca tahmini ezmiyoruz.
    const agreed = pickConsensusDate(votes);
    if (!agreed) {
      notes.push(
        `${event.title}: uzlasma yok (${votes.length} aday) — tahmin korunuyor`,
      );
      continue;
    }

    const year = Number(agreed.slice(0, 4));
    campaigns.push({
      id: event.idFor(year),
      brands: event.brands,
      title: event.title,
      startsAt: agreed,
      confidence: 'announced',
      source: 'news',
      sourceUrl: sources[0] ?? null,
      lastSeenAt: today,
    });
    notes.push(`${event.title}: ${agreed} (${votes.length} oy)`);
  }

  return { campaigns, notes };
}

/** RSS XML'inden baslik + aciklama metinlerini cikarir. */
export function parseRssItems(xml) {
  const $ = cheerio.load(xml, { xmlMode: true });
  const items = [];
  $('item').each((_, el) => {
    const $el = $(el);
    const title = $el.find('title').first().text();
    const description = $el.find('description').first().text();
    items.push({
      text: `${title} ${stripTags(description)}`,
      link: $el.find('link').first().text() || null,
    });
  });
  return items;
}

/**
 * Uzak gelecege dusen tarihler kabul edilmez.
 *
 * Markalar indirimi haftalar oncesinden duyurur, bir yil oncesinden degil.
 * Ornek: agustos ayinda okunan "24 Haziran'da basliyor" haberi aslinda gecen
 * haziranla ilgilidir; bunu 2027'ye tasimak **uydurma bir duyuru** uretmek
 * olurdu. Ufku asan tarih atilir ve uygulama hesapladigi tahminde kalir.
 */
const MAX_HORIZON_DAYS = 220;

/**
 * Bir haber metninden baslangic tarihi cikarir.
 *
 * Dort kosul birden saglanmali: tarih baslangic baglaminda gecmeli, beklenen
 * aya (+/- 1 ay) dusmeli, gecerli bir takvim gunu olmali ve yakin gelecekte
 * bulunmali.
 */
export function extractStartDate(
  text,
  monthHint,
  now = new Date(),
  { maxHorizonDays = MAX_HORIZON_DAYS } = {},
) {
  for (const d of parseTurkishDates(text)) {
    if (!d.looksLikeStart) continue;
    if (!isNearMonth(d.month, monthHint)) continue;

    const year = d.year ?? inferYear(d.month, d.day, now);
    const iso = toIsoDate(year, d.month, d.day);
    const days = daysFromNow(iso, now);
    // Gecmis tarih duyuru degildir; cok uzak tarih de guvenilir degildir.
    if (days < 0 || days > maxHorizonDays) continue;
    return iso;
  }
  return null;
}

function daysFromNow(iso, now) {
  const [y, m, d] = iso.split('-').map(Number);
  const target = Date.UTC(y, m - 1, d);
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.round((target - today) / 86400000);
}

/** Ay dairesel; ocak (1) ile aralik (12) komsudur. */
export function isNearMonth(month, hint) {
  const diff = Math.abs(month - hint);
  return Math.min(diff, 12 - diff) <= 1;
}

const stripTags = (s) => (s || '').replace(/<[^>]*>/g, ' ');
