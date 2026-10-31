# GApps Remover (ADB)

ADB ile seçili Google uygulama paketlerini Android'in **user 0** profilinden kaldırır. Sistem bölümündeki APK dosyalarını silmez veya sistem bölümünü değiştirmez. Chrome, Google Haritalar, Google Fotoğraflar ve Android overlay paketleri korunur.

> **Uyarı:** Google Play Hizmetleri, Google Services Framework veya Play Store kaldırılırsa Google hesabıyla oturum açma, push bildirimleri, konum, uygulama içi satın alma ve Google'a bağlı diğer uygulama özellikleri bozulabilir. Bazı uygulamalar açılmayabilir. Geri yükleme her paketin ROM'da hâlâ mevcut olmasına bağlıdır; sorunsuz çalışacağı veya her cihazda geri yüklenebileceği garanti edilmez.

## Gereksinimler

- Bilgisayarda Android Platform Tools (`adb`) kurulu ve `PATH` içinde olmalı.
- Telefonda Geliştirici seçenekleri ve USB hata ayıklama açık olmalı.
- Telefon USB ile bağlanmalı; telefondaki ADB yetkilendirme istemi kabul edilmeli.
- Birden fazla cihaz bağlıysa `adb devices` çıktısından hedef cihazın seri numarasını kullan.

## Kullanım

Betik dosyasını çalıştırılabilir yap:

```sh
chmod +x remove-google-user.sh
```

Önce şu an yüklü olan sabit paket grubunun durumunu kontrol et:

```sh
./remove-google-user.sh status
```

Chrome, Haritalar ve Fotoğraflar hariç Google paketlerinin listesini **değişiklik yapmadan** göster:

```sh
./remove-google-user.sh list-others
```

Listeyi dikkatlice incele. Kaldırmak için:

**DİKKAT!! BOOTLOOP'A SEBEP OLABİLİR**

```sh
./remove-google-user.sh remove-others
```
DAHA GÜVENLİ SEÇENEK TÜM HERŞEYİ SİLMEZ 
```sh
./remove-google-user.sh remove
```

Betik etkilenecek paketleri tekrar gösterir. Devam etmek için yalnızca açıkça onaylıyorsan `REMOVE-GOOGLE` yaz. Farklı işlem olan sınırlı paket grubu için `remove` komutu `REMOVE` onayı ister.

Birden fazla cihaz bağlıysa seri numarasını komutun sonuna ekle:

```sh
./remove-google-user.sh list-others DEVICE_SERIAL
./remove-google-user.sh remove-others DEVICE_SERIAL
```

Alternatif olarak `ANDROID_SERIAL` ortam değişkeni kullanılabilir.

## Geri yükleme

Kaldırma işleminden sonra ROM'da bulunan paketleri user 0 için geri yüklemeyi dene:

```sh
./remove-google-user.sh restore-others
```

Sınırlı paket grubu için:

```sh
./remove-google-user.sh restore
```

Bu komutlar Android `install-existing` komutunu kullanır. APK dosyası ROM'da yoksa geri yükleme başarısız olur; betik APK indirmez veya sistem bölümüne yazmaz.

## Kapsam ve sınırlar

- `remove-others`, user 0'da listelenen `com.google.*` paketlerini ve `com.android.vending` Play Store paketini hedefler.
- Tam paket adları `com.android.chrome`, `com.google.android.apps.maps` ve `com.google.android.apps.photos` korunur. İsimleri farklı özel sürümler bu korumaya dahil olmayabilir.
- Paket adında `.overlay.` bulunan Android overlay paketleri hariç tutulur.
- Bu betik yalnızca paketleri user 0 için kaldırır; fabrika imajından kalıcı olarak silmez. OTA güncellemesi veya fabrika ayarlarına dönüş sonrasında paketler tekrar görünebilir.
- Silme işlemi veri kaybına ve bağımlı uygulamaların bozulmasına yol açabilir. Önemli verileri yedekle; tam olarak hangi paketlerin etkileneceğini görmek için önce `list-others` çalıştır.
- Bu araç her HyperOS sürümünde test edilmiş değildir. Sorun çıkarsa USB hata ayıklama erişimini koru ve `restore-others` ile geri yüklemeyi dene.

Bu araç Android veya Google tarafından desteklenmez.
