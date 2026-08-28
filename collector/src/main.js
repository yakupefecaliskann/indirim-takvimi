// Veri toplama boru hattinin giris noktasi.
//
// Tasarim kurallari:
//  1. Her kaynak izole calisir; biri patlarsa digerleri devam eder.
//  2. Cikti bir onceki surumden anlamli olcude kucukse **yazilmaz** — son iyi
//     veri yayinda kalir. Bozuk bir calistirma uygulamayi bosaltamaz.
//  3. Hicbir sey uydurulmaz. Emin olunmayan tarih hic yazilmaz; uygulama
//     zaten kendi hesapladigi tahmine duser.
//
// Kullanim:
//   node src/main.js                # topla ve data/campaigns.json yaz
//   node src/main.js --dry-run      # yazma, sonucu ekrana bas
//   node src/main.js --only=news    # tek kaynak calistir

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import * as picodi from './sources/picodi.js';
import * as news from './sources/news.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_PATH = join(HERE, '..', '..', 'data', 'campaigns.json');

const SOURCES = [news, picodi];

/** Yeni cikti oncekinin bu oranindan azsa yazma. */
const SHRINK_GUARD = 0.5;

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const onlyArg = args.find((a) => a.startsWith('--only='));
  const only = onlyArg ? onlyArg.slice('--only='.length) : null;

  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  const campaigns = [];
  const offers = [];
  const report = [];

  for (const source of SOURCES) {
    if (only && source.name !== only) continue;
    const started = Date.now();
    try {
      const result = await source.collect({ today, now });
      if (result.campaigns) campaigns.push(...result.campaigns);
      if (result.offers) offers.push(...result.offers);
      report.push({
        source: source.name,
        ok: true,
        campaigns: result.campaigns?.length ?? 0,
        offers: result.offers?.length ?? 0,
        ms: Date.now() - started,
        notes: result.notes ?? [],
      });
    } catch (err) {
      // Kaynak tamamen coktuyse bile calistirma basarisiz sayilmaz.
      report.push({
        source: source.name,
        ok: false,
        error: err.message,
        ms: Date.now() - started,
      });
    }
  }

  const output = {
    version: 1,
    generatedAt: now.toISOString(),
    campaigns: dedupeById(campaigns),
    codes: dedupeById(offers),
  };

  printReport(report, output);

  if (dryRun) {
    console.log('\n--- KURU CALISMA: dosya yazilmadi ---');
    console.log(JSON.stringify(output, null, 2).slice(0, 4000));
    return;
  }

  const previous = await readPrevious();
  const decision = shouldWrite(previous, output, { partialRun: Boolean(only) });
  if (!decision.write) {
    console.log(`\nYAZILMADI: ${decision.reason}`);
    console.log('Onceki veri yayinda kaliyor.');
    return;
  }

  await mkdir(dirname(OUT_PATH), { recursive: true });
  await writeFile(OUT_PATH, JSON.stringify(output, null, 2) + '\n', 'utf8');
  console.log(`\nYAZILDI: ${OUT_PATH}`);
}

/**
 * Yeni ciktinin yayinlanip yayinlanmayacagina karar verir.
 *
 * Bu, boru hattinin en onemli guvenlik agi: bir kaynak sessizce bozulup bos
 * donduğunde uygulamadaki tum firsatlarin silinmesini engeller.
 */
export function shouldWrite(previous, next, { partialRun = false } = {}) {
  const nextTotal = next.campaigns.length + next.codes.length;
  if (nextTotal === 0) {
    return { write: false, reason: 'yeni cikti tamamen bos' };
  }
  if (!previous) return { write: true, reason: 'ilk calistirma' };
  if (partialRun) {
    return { write: false, reason: 'tek kaynak calistirmasi yayinlanmaz' };
  }

  const prevTotal =
    (previous.campaigns?.length ?? 0) + (previous.codes?.length ?? 0);
  if (prevTotal > 0 && nextTotal < prevTotal * SHRINK_GUARD) {
    return {
      write: false,
      reason: `cikti beklenmedik sekilde kuculdu (${prevTotal} -> ${nextTotal})`,
    };
  }
  return { write: true, reason: 'normal guncelleme' };
}

export function dedupeById(items) {
  const seen = new Map();
  for (const item of items) {
    if (item && typeof item.id === 'string') seen.set(item.id, item);
  }
  return [...seen.values()];
}

async function readPrevious() {
  try {
    return JSON.parse(await readFile(OUT_PATH, 'utf8'));
  } catch {
    return null;
  }
}

function printReport(report, output) {
  console.log('=== KAYNAK RAPORU ===');
  for (const r of report) {
    if (r.ok) {
      console.log(
        `  [OK]   ${r.source.padEnd(8)} kampanya:${r.campaigns} firsat:${r.offers} (${r.ms}ms)`,
      );
      for (const n of r.notes) console.log(`         - ${n}`);
    } else {
      console.log(`  [HATA] ${r.source.padEnd(8)} ${r.error} (${r.ms}ms)`);
    }
  }
  console.log(
    `=== TOPLAM: ${output.campaigns.length} kampanya, ${output.codes.length} firsat ===`,
  );
}

const isEntryPoint =
  process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isEntryPoint) {
  main().catch((err) => {
    console.error('Beklenmeyen hata:', err);
    process.exit(1);
  });
}
