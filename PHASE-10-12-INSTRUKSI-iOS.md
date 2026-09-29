# PHASE 10–12 — Instruksi iOS (Mac, Xcode, iPhone, TestFlight)

> Dokumen ini disusun karena **PHASE 10–12 tidak bisa dieksekusi di mesin Windows**
> (butuh Mac + Xcode + akun Apple Developer). Isinya langkah lengkap, urut, agar
> siapa pun dengan Mac bisa menyelesaikan port iOS tanpa menebak-nebak.
>
> Status Windows (selesai): PHASE 0–9 + PHASE 8 (adaptive iOS di sisi Dart).
> `flutter analyze` 0 issue, `flutter test` **166/166 hijau**,
> `flutter build apk --release` sukses → `build\app\outputs\flutter-apk\app-release.apk`
> (applicationId `com.dompetku.app`, versionName `1.0.0`, minSdk 24, label DompetKu).

---

## Prasyarat (sekali di Mac)

1. **Mac** dengan macOS terbaru yang didukung Xcode.
2. **Xcode** terbaru dari App Store (≈15–20 GB) + Command Line Tools:
   `xcode-select --install`
3. **Flutter SDK (stable)** — versi sama dengan Windows:
   `git clone https://github.com/flutter/flutter.git -b stable`
   lalu `flutter doctor` sampai centang iOS/Android toolchain aman.
4. **CocoaPods**: `sudo gem install cocoapods`
5. **Akun Apple Developer** berbayar ($99/tahun) — wajib untuk TestFlight.
   Login di Xcode → Settings → Accounts.
6. Salin proyek ke Mac, misal ke `~/DompetKu-Port/dompetku_port`:
   di Windows: kompres folder `dompetku_port` (abaikan `build/`, `.dart_tool/`,
   `.dart_tool/`, `android/.gradle/`) → zip → pindahkan.

---

## PHASE 10 — Build & simulasi iOS di Mac

### 10.1 Siapkan proyek

```bash
cd ~/DompetKu-Port/dompetku_port
flutter pub get
flutter analyze        # wajib: No issues found
flutter test           # wajib: 166/166 All tests passed
```

### 10.2 Generate folder iOS

Folder `ios/` sengaja tidak dibuat di Windows (tidak bisa). Di Mac:

```bash
flutter create --platforms=ios .
```

Periksa `ios/Runner.xcodeproj` — buka **Xcode**:

* `Runner` → **General**:
  * Display Name: **DompetKu**
  * Bundle Identifier: **`com.dompetku.app`** (harus persis — paritas Android)
  * Version: **1.0.0**, Build: **1**
  * Minimum Deployments: iOS **12.0** (atau default Flutter, minimal 12)
* `Runner` → **Signing & Capabilities**:
  * Team: pilih akun Developer kamu
  * Automatically manage signing: ✅
* `ios/Runner/Info.plist` — pastikan `CFBundleDisplayName` = `DompetKu`.
  Tidak perlu permission tambahan (aplikasi 100% offline, tanpa kamera/galeri/internet).

Catatan `flutter create` bisa menimpa `pubspec.yaml`/`lib/`? **Tidak** —
`flutter create .` pada proyek yang sudah ada hanya menambah platform yang belum ada.
Tetap lakukan `git status`/diff bila proyek memakai git.

### 10.3 Jalankan di Simulator

```bash
open -a Simulator        # pilih iPhone (mis. iPhone 16)
flutter run              # rilis: flutter run --release
```

### 10.4 Smoke test Simulator (checklist wajib — lihat §Checklist)

Jalankan checklist 13 baris di bawah pada Simulator. **Semua harus lulus**
sebelum lanjut PHASE 11.

---

## PHASE 11 — Uji di iPhone fisik

1. **Aktifkan Developer Mode**: iPhone → Settings → Privacy & Security →
   Developer Mode → ON → restart.
2. Kabel USB → percayai komputer → Xcode → Window → Devices and Simulators
   harus terlihat.
3. Xcode → Runner → Signing & Caps → pilih **Personal Team**; bila muncul
   error provisioning, tambahkan akun di Xcode → Settings → Accounts →
   Manage Certificates → Apple Development (auto).
4. Build & jalankan rilis di perangkat:

```bash
flutter devices           # catat id perangkat
flutter run --release -d <device-id>
```

5. **Uji nyata di iPhone** (paritas perilaku, bukan tampilan):

| # | Uji | Ekspektasi |
|---|-----|-----------|
| 1 | Input cepat `makan ayam 30000` | kategori Makanan, nominal 30000, catatan `ayam` |
| 2 | Simpan tanpa nominal | toast `Masukkan nominal terlebih dahulu.` |
| 3 | Long-press baris di Riwayat | dialog `Hapus transaksi ini?` + `"<label>" senilai Rp… akan dihapus permanen.` |
| 4 | Budget 500000, belanja 600000 | progress >100%, `Anda telah melebihi budget bulan ini.` |
| 5 | Pengaturan → Tampilan → Gelap | aplikasi gelap, label nilai berubah |
| 6 | Export CSV | file `dompetku_<ts>.csv` terbagi ke Files/Share sheet |
| 7 | Import CSV hasil export | `N transaksi diimpor, 0 duplikat dilewati.` |
| 8 | Import file non-CSV | `File tidak valid atau tidak ada data yang bisa diimpor.` |
| 9 | Backup Database | file `dompetku_backup_<ts>.db` tersimpan |
| 10 | Kategori terpakai → Hapus | `Kategori ini digunakan oleh N transaksi dan tidak bisa dihapus.` |
| 11 | Tekan tombol kembali/keluar form ada isian | `Data belum disimpan` / `Ada data yang belum disimpan. Buang perubahan?` |
| 12 | Airplane mode ON | semua fitur tetap jalan (offline penuh) |
| 13 | Kill & buka lagi aplikasi | data tetap ada (SQLite lokal `dompetku.db`) |

6. Uji tema **Ikuti sistem** dengan mode gelap iOS.

---

## PHASE 12 — TestFlight

> TestFlight = distribusi **internal/alpha**. Jangan tekan
> *"Submit to App Store Review"* — target di sini hanya TestFlight.

### 12.1 Buat aplikasi di App Store Connect

1. Buka https://appstoreconnect.apple.com → **My Apps** → **＋ New App**:
   * Platform: **iOS**
   * Bundle ID: pilih **`com.dompetku.app`** (daftarkan dulu di
     Developer Portal → Identifiers → App IDs kalau belum ada)
   * Name: **DompetKu** (atau `DompetKu – Catat Pengeluaran` bila nama bentrok)
   * Primary Language: Indonesia
   * SKU: bebas, mis. `dompetku-100`
2. Tab **TestFlight** → tambahkan **Internal Group** (anggota timmu sendiri,
   tanpa beta review untuk grup internal).

### 12.2 Build & unggah IPA

Di Mac:

```bash
flutter build ipa --release
# hasil: build/ios/ipa/dompetku_port.ipa
```

Uggah salah satu cara:

* **Xcode (disarankan)**: buka `ios/Runner.xcworkspace` → Product → Archive →
  Distribute App → TestFlight & App Store → Upload.
* Atau **Transporter** (App Store) → unggah `dompetku_port.ipa`.

Catatan: bila nama IPA default kurang rapi, cukup diganti di App Store Connect
(build-nya sama). Verifikasi di Archive: bundle id `com.dompetku.app`,
versi 1.0.0 build 1.

### 12.3 Sebarkan ke tester

1. App Store Connect → TestFlight → pilih build → **Distribute to Internal
   Group** — build muncul dalam beberapa menit (biasanya ≤ 1 jam).
2. Tester (kamu) menerima email undangan → install **TestFlight** di iPhone →
   terima undangan → install DompetKu 1.0.0.
3. Uji ulang checklist §PHASE 11 di build TestFlight (build rilis, bukan debug).

### 12.4 Catatan review / metadata (kalau suatu saat naik App Store)

* Aplikasi **offline penuh**: tidak ada akun, tidak ada server, tidak ada iklan.
* Kategori: Finance / Utilities.
* Privacy Nutrition Labels: **No Data Collected** (semua data di perangkat).
* Review notes: "DompetKu is a fully offline personal expense tracker.
  All data is stored locally in SQLite; no account or network access is used."

---

## Checklist paritas 13 baris (verakhir, sebelum menyebut "iOS selesai")

| # | Area | Status Windows (D0–D9) | Verifikasi Mac (P10–12) |
|---|------|------------------------|--------------------------|
| 1 | Beranda (total hari ini + ringkasan 4 baris + list) | ✅ | ☐ |
| 2 | Riwayat (search debounce 250 ms, 5 chip, kategori, sort, hapus) | ✅ | ☐ |
| 3 | Laporan (periode, total, grafik 7 hari, breakdown, budget §11) | ✅ | ☐ |
| 4 | Tambah/Edit (quick input, nominal terkelompok, draft guard) | ✅ | ☐ |
| 5 | Kategori (CRUD, LastCategory, InUse(n), palet 10 warna) | ✅ | ☐ |
| 6 | Budget bulanan (persis rumus §11, pesan 80%/over) | ✅ | ☐ |
| 7 | Pengaturan (tema `night_mode`, export/import/backup, versi) | ✅ | ☐ |
| 8 | Quick input parser (91 alias/12 grup, 19 test regresi) | ✅ | ☐ |
| 9 | CSV (RFC4180, roundtrip, duplikat, fallback Lainnya) | ✅ | ☐ |
| 10 | Backup mentah `dompetku.db` byte-per-byte | ✅ | ☐ |
| 11 | Tema gelap/terang/ikut sistem (SharedPreferences) | ✅ | ☐ |
| 12 | SQLite lokal `dompetku.db`, skema §15, seed 12 kategori | ✅ | ☐ |
| 13 | Offline penuh (tanpa AI/cloud/login/fitur baru) | ✅ | ☐ |

---

## Batasan yang diketahui (transparan)

* **Tema seed warna** = `#0F766E` (dari `colors.xml` Android) — Material 3,
  bukan salinan pixel-per-pixel tema AppCompat; paritas fungsional & teks yang
  dipastikan penuh.
* **Dialog form kategori & date picker** tetap varian Material di iOS
  (Flutter tidak punya varian Cupertino setara untuk form kompleks tanpa
  mengubah perilaku). Dialog konfirmasi & budget **sudah adaptif** (Cupertino
  di iOS/macOS), transisi antar-layar memakai slide Cupertino di iOS.
* **Toast** memakai SnackBar (Material). Paritas teks 100% identik.
* `targetSdk` Android hasil build Flutter = 36 (Android 1.0 = 35) — lebih
  baru; tidak memengaruhi perilaku aplikasi.
