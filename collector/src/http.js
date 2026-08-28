// Nazik HTTP istemcisi.
//
// Kaynaklara yuk bindirmemek icin: gercek bir tarayici kimligi, istekler
// arasinda gecikme, kisa zaman asimi ve sinirli yeniden deneme.

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function fetchText(url, { timeoutMs = 15000, retries = 1 } = {}) {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        headers: {
          'user-agent': UA,
          'accept-language': 'tr-TR,tr;q=0.9,en;q=0.8',
          accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
        signal: controller.signal,
        redirect: 'follow',
      });
      clearTimeout(timer);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.text();
    } catch (err) {
      clearTimeout(timer);
      lastError = err;
      if (attempt < retries) await sleep(1500 * (attempt + 1));
    }
  }
  throw lastError;
}
