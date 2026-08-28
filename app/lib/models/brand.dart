/// Uygulamanın takip ettiği markalar ve grupları.
///
/// Marka listesi uygulamanın içinde sabittir; uzak veri yalnızca bu
/// kimliklere atıfta bulunur. Böylece bilinmeyen bir marka kimliği
/// geldiğinde arayüz çökmez, kayıt sessizce atlanır.
enum BrandCategory { kisiselBakim, giyim, genel }

class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.category,
    this.siteUrl,
  });

  final String id;
  final String name;
  final BrandCategory category;
  final String? siteUrl;
}

const List<Brand> kBrands = <Brand>[
  // Kişisel bakım
  Brand(
    id: 'gratis',
    name: 'Gratis',
    category: BrandCategory.kisiselBakim,
    siteUrl: 'https://www.gratis.com',
  ),
  Brand(
    id: 'watsons',
    name: 'Watsons',
    category: BrandCategory.kisiselBakim,
    siteUrl: 'https://www.watsons.com.tr',
  ),
  Brand(
    id: 'sephora',
    name: 'Sephora',
    category: BrandCategory.kisiselBakim,
    siteUrl: 'https://www.sephora.com.tr',
  ),
  Brand(
    id: 'rossmann',
    name: 'Rossmann',
    category: BrandCategory.kisiselBakim,
    siteUrl: 'https://www.rossmann.com.tr',
  ),
  // Inditex grubu
  Brand(
    id: 'zara',
    name: 'Zara',
    category: BrandCategory.giyim,
    siteUrl: 'https://www.zara.com/tr',
  ),
  Brand(
    id: 'bershka',
    name: 'Bershka',
    category: BrandCategory.giyim,
    siteUrl: 'https://www.bershka.com/tr',
  ),
  Brand(
    id: 'pullandbear',
    name: 'Pull&Bear',
    category: BrandCategory.giyim,
    siteUrl: 'https://www.pullandbear.com/tr',
  ),
  Brand(
    id: 'stradivarius',
    name: 'Stradivarius',
    category: BrandCategory.giyim,
    siteUrl: 'https://www.stradivarius.com/tr',
  ),
  Brand(
    id: 'oysho',
    name: 'Oysho',
    category: BrandCategory.giyim,
    siteUrl: 'https://www.oysho.com/tr',
  ),
  // Markadan bağımsız indirim dönemleri
  Brand(id: 'genel', name: 'Tüm Markalar', category: BrandCategory.genel),
];

/// Inditex grubu aynı anda indirime girdiği için tek bir tarih hesabı
/// bu beş markayı birden kapsar.
const List<String> kInditexBrandIds = <String>[
  'zara',
  'bershka',
  'pullandbear',
  'stradivarius',
  'oysho',
];

final Map<String, Brand> kBrandsById = <String, Brand>{
  for (final Brand b in kBrands) b.id: b,
};

/// Bilinmeyen kimlikler için null döner — arayüz bu kaydı atlar.
Brand? brandById(String id) => kBrandsById[id];
