// Turkce metinden tarih cikarimi.
//
// Bilincli olarak **muhafazakar**: emin olmadigi hicbir seyi tarih saymaz.
// Yanlis bir tarih uretmek, hic tarih uretmemekten cok daha kotu — uygulama
// tarih bulamazsa zaten hesaplanan tahmine dusuyor.

const MONTHS = new Map([
  ['ocak', 1],
  ['subat', 2], ['şubat', 2],
  ['mart', 3],
  ['nisan', 4],
  ['mayis', 5], ['mayıs', 5],
  ['haziran', 6],
  ['temmuz', 7],
  ['agustos', 8], ['ağustos', 8],
  ['eylul', 9], ['eylül', 9],
  ['ekim', 10],
  ['kasim', 11], ['kasım', 11],
  ['aralik', 12], ['aralık', 12],
]);

const MONTH_PATTERN = [...MONTHS.keys()].join('|');

// "24 Haziran", "27 Kasım 2026", "7 ocak'ta"
const DATE_RE = new RegExp(
  String.raw`(\d{1,2})\s*(?:\.\s*)?(${MONTH_PATTERN})\b\s*'?[a-zçğıöşü]{0,4}\s*(\d{4})?`,
  'gi',
);

// Baslangic bildiren ifadeler. "sona er", "bitiyor" gibi ifadeler tarihin
// baslangic degil bitis oldugunu gosterir.
const START_HINTS = /(basl|başl|start|indirime gir|yururluge|yürürlüğe)/i;
const END_HINTS = /(sona er|bitiy|bitec|son gun|son gün|bitis|bitiş)/i;

const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/**
 * Metindeki tum gun+ay ciftlerini dondurur.
 * @returns {{day:number, month:number, year:number|null, looksLikeStart:boolean}[]}
 */
export function parseTurkishDates(text) {
  if (typeof text !== 'string' || !text) return [];
  const results = [];
  for (const m of text.matchAll(DATE_RE)) {
    const day = Number(m[1]);
    const month = MONTHS.get(m[2].toLowerCase());
    if (!month || day < 1 || day > DAYS_IN_MONTH[month - 1]) continue;

    const year = m[3] ? Number(m[3]) : null;
    if (year !== null && (year < 2020 || year > 2100)) continue;

    // Eslesmenin etrafindaki pencereye bakarak baslangic mi bitis mi anla.
    const from = Math.max(0, m.index - 80);
    const to = Math.min(text.length, m.index + m[0].length + 80);
    const ctx = text.slice(from, to);
    const looksLikeStart = START_HINTS.test(ctx) && !END_HINTS.test(ctx);

    results.push({ day, month, year, looksLikeStart, context: ctx.trim() });
  }
  return results;
}

/**
 * Metinde yil yoksa hangi yil oldugunu tahmin eder.
 *
 * Kural: tarih bugunden 45 gunden fazla geride kaliyorsa gelecek yil kastedilmis
 * demektir (haberler yaklasan indirimden bahseder, gecmistekinden degil).
 */
export function inferYear(month, day, now = new Date()) {
  const y = now.getUTCFullYear();
  const candidate = Date.UTC(y, month - 1, day);
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const daysDiff = (candidate - today) / 86400000;
  return daysDiff < -45 ? y + 1 : y;
}

export function toIsoDate(year, month, day) {
  const p = (n) => String(n).padStart(2, '0');
  return `${year}-${p(month)}-${p(day)}`;
}

/**
 * Birden fazla bagimsiz kaynak ayni tarihi soylediyse o tarihi dondurur.
 *
 * Tek bir haberin yanlis okunmasi uygulamaya yanlis tarih dusurmesin diye
 * en az iki oy sart. Bu, boru hattinin en onemli dogruluk korumasi.
 */
export function pickConsensusDate(isoDates, minVotes = 2) {
  if (!Array.isArray(isoDates) || isoDates.length === 0) return null;
  const counts = new Map();
  for (const d of isoDates) counts.set(d, (counts.get(d) ?? 0) + 1);

  let best = null;
  let bestCount = 0;
  for (const [date, count] of counts) {
    if (count > bestCount || (count === bestCount && date < best)) {
      best = date;
      bestCount = count;
    }
  }
  return bestCount >= minVotes ? best : null;
}
