/// Teslim öncesi doldurulacak kişisel ayarlar ve veri kaynağı adresi.
///
/// Buradaki değerler yanlış olsa bile uygulama çalışır: uzak adrese
/// ulaşılamazsa hesaplanan takvime düşer.
library;

/// Karşılama ekranında görünecek isim.
const String kHerName = 'Melisa';

/// Karşılama ekranındaki kişisel not.
const String kWelcomeMessage =
    'Sevdiğin markaların indirim günlerini tek tek takip etmene gerek yok '
    'artık, bu iş bende. Gün yaklaştıkça sana haber vereceğim. '
    'İyi alışverişler 💕';

/// Veri dosyasının yayınlandığı GitHub deposu.
const String kGithubUser = 'yakupefecaliskann';
const String kGithubRepo = 'indirim-takvimi';
const String kGithubBranch = 'main';

String get kDataUrl =>
    'https://raw.githubusercontent.com/$kGithubUser/$kGithubRepo/$kGithubBranch/data/campaigns.json';

/// Uzak veri bu sıklıktan daha sık çekilmez.
const Duration kMinFetchInterval = Duration(hours: 6);
