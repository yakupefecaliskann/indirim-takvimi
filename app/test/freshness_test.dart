import 'package:flutter_test/flutter_test.dart';
import 'package:indirim_takvimi/data/merge.dart';
import 'package:indirim_takvimi/ui/countdown_format.dart';

/// Ağ hatasında önbelleğe düşmek doğru davranış; bunu **başarılı bir
/// güncelleme** saymak değil. Bu ayrım bozulursa tek bir ağ hatası bir sonraki
/// denemeyi saatlerce kilitler ve ayarlar ekranı yanlış bilgi verir.
void main() {
  group('RemoteData tazelik işareti', () {
    test('ağdan ayrıştırılan veri taze sayılır', () {
      const String json =
          '{"campaigns":[{"id":"a","brands":["zara"],"title":"A",'
          '"startsAt":"2026-12-01"}]}';
      expect(RemoteData.parse(json).fromCache, isFalse);
    });

    test('asCached veriyi koruyarak önbellek damgası vurur', () {
      const String json =
          '{"generatedAt":"2026-08-28T10:00:00Z",'
          '"campaigns":[{"id":"a","brands":["zara"],"title":"A",'
          '"startsAt":"2026-12-01"}],'
          '"codes":[{"id":"k1","brand":"zara","title":"K"}]}';
      final RemoteData fresh = RemoteData.parse(json);
      final RemoteData cached = fresh.asCached();

      expect(cached.fromCache, isTrue);
      expect(cached.campaigns.length, fresh.campaigns.length);
      expect(cached.codes.length, fresh.codes.length);
      expect(cached.generatedAt, fresh.generatedAt);
      // Kaynak nesne değişmemeli.
      expect(fresh.fromCache, isFalse);
    });

    test('asCached zaten önbellekli veride aynı nesneyi döner', () {
      final RemoteData cached = RemoteData.parse('{}').asCached();
      expect(identical(cached.asCached(), cached), isTrue);
    });

    test('boş veri hiçbir zaman taze sayılmaz', () {
      expect(RemoteData.empty.fromCache, isTrue);
    });
  });

  group('lastFetchLabel', () {
    final DateTime now = DateTime(2026, 8, 28, 15, 30);

    test('hiç çekilmediyse belli eder', () {
      expect(lastFetchLabel(null, now), 'Henüz güncellenmedi');
    });

    test('bugünse saati de söyler', () {
      expect(
        lastFetchLabel(DateTime(2026, 8, 28, 9, 5), now),
        'Bugün 09:05 güncellendi',
      );
    });

    test('dün ve daha eskisi gün olarak anlatılır', () {
      expect(lastFetchLabel(DateTime(2026, 8, 27, 23, 0), now), 'Dün güncellendi');
      expect(
        lastFetchLabel(DateTime(2026, 8, 25), now),
        '3 gün önce güncellendi',
      );
    });

    test('"doğrulandı" metniyle karıştırılmıyor', () {
      // Eski hata: veri çekme zamanı, fırsat doğrulama metniyle gösteriliyordu.
      expect(lastFetchLabel(now, now), isNot(contains('doğrulandı')));
      expect(lastSeenLabel(now, now), contains('doğrulandı'));
    });
  });
}
