# EduFess (Education & Menfess)
### Aplikasi Media Berbagi Pengetahuan Sekolah dan Layanan Bimbingan Konseling Privat

[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.0-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase%20PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Tests](https://img.shields.io/badge/Tests-281%20Passed-brightgreen)](https://github.com/Milanovelia/EDUFESS)
[![Linter](https://img.shields.io/badge/flutter%20analyze-0%20issues-success)](https://github.com/Milanovelia/EDUFESS)

---

## 📖 Tentang EduFess

**EduFess** (akronim dari *Education & Confess / Menfess*) adalah aplikasi mobile berbasis Android yang menggabungkan dua pilar utama dalam lingkungan sekolah:
1. **Pilar Utama — Menfess Akademik (Publik & Anonim)**: Ruang publik bagi siswa untuk saling berbagi catatan materi pelajaran, tanya jawab, rangkuman, tips belajar, dan permintaan bahan ajar dalam feed komunitas. Postingan dapat diterbitkan menggunakan nama pseudonim asli maupun mode anonim dengan alias acak terkontrol server (`Siswa Anonim #XXXX`).
2. **Pilar Pendukung — Bimbingan Konseling Privat (BK)**: Jalur komunikasi rahasia dan aman menuju layanan bimbingan konseling sekolah yang terisolasi penuh dari lalu lintas sosial, dilengkapi dengan fitur konseling tertutup berorientasi alias (`Siswa BK #XXXX`), penjadwalan janji temu tatap muka, pencatatan suasana hati harian non-diagnostik (Mood Check-In), dan kanal kepedulian teman sebaya (Peduli Teman).

> **Prinsip Utama:** *Pseudonymous is not fully anonymous*. Tampilan antarmuka publik tidak pernah mengekspos identitas asli siswa, namun basis data backend tetap mencatat ID pengguna demi akuntabilitas dan pencegahan penyalahgunaan.

---

## 👥 Peran Pengguna (Roles)

- **Student (Siswa)**:
  - Peran bawaan saat mendaftar menggunakan kode undangan (*invitation code*).
  - Hak akses: Membaca & menerbitkan Menfess (publik/anonim), interaksi Helpful (❤️), Bookmark (🔖), Komentar bertingkat, penandaan Jawaban Terbaik (*Best Answer*), Edit & Soft-delete postingan sendiri, pencarian Explore, persetujuan BK, percakapan konseling milik sendiri, booking janji temu, Mood Check-In, dan laporan Peduli Teman.
- **Counselor (Guru BK)**:
  - Diprovisikan oleh operator sekolah.
  - Hak akses: Antrean konseling berbasis alias, klaim sesi siswa binaan, pertukaran pesan bimbingan, pengelolaan slot ketersediaan janji temu (*availability*), triage janji, pemantauan riwayat mood siswa binaan, penanganan kasus Peduli Teman, dan pengungkapan identitas darurat (*identity reveal* teraudit).
  - *Batasan*: Tidak otomatis menjadi moderator konten sosial Menfess.
- **Admin (Moderator Sosial)**:
  - Mengelola ketertiban dan etika komunitas Menfess sekolah.
  - Hak akses: Antrean laporan konten bermasalah, peninjauan alasan, serta aksi *Dismiss* (abaikan) atau *Remove* (hapus konten dari feed).
  - *Batasan Mutlak*: Diblokir dari seluruh data percakapan konseling, riwayat mood, janji temu, dan laporan Peduli Teman pada domain BK.

---

## 🛠️ Tumpukan Teknologi (Tech Stack)

- **Framework**: Flutter 3.47.0 (Channel stable) / Dart ^3.13.0
- **Target Platform**: Android-First (Material 3, Google Sans Typography)
- **State Management**: `flutter_riverpod: ^3.4.2`
- **Routing & Navigasi**: `go_router: ^18.0.0` (dengan synchronous auth redirect guard)
- **Backend & Database**: Supabase (PostgreSQL 15+, Auth, PostgREST API, Row Level Security)
- **Konfigurasi Environment**: `flutter_dotenv: ^6.0.1`

---

## 🔒 Model Keamanan & Privasi

1. **Pemisahan Domain BK dan Sosial**: Data percakapan, pesan, janji temu, mood, dan laporan kepedulian dienkapsulasi pada tabel terpisah tanpa keterkaitan foreign key publik ke feed media sosial.
2. **Kerahasiaan Alamat Email**: Email pengguna tidak pernah diekspos pada proyeksi feed publik, hasil pencarian, profil, maupun antrean konseling.
3. **Alias Anonim Dihasilkan di Sisi Server (Server-Side Trigger)**: Alias `Siswa Anonim #XXXX` dibuat otomatis menggunakan fungsi digest SHA-256 kriptografis di tingkat PostgreSQL; klien tidak dapat memalsukan nama samaran.
4. **Otorisasi Absolut Row Level Security (RLS)**: Validasi hak akses dilakukan di server basis data melalui `auth.uid()` dan pemeriksaan fungsi peran `SECURITY DEFINER` dengan `SET search_path = ''`.
5. **Audit Pembukaan Identitas**: Guru BK hanya dapat membuka identitas asli siswa pada situasi darurat bimbingan dengan mewajibkan pengisian alasan yang dicatat permanen ke tabel audit `bk_identity_access_log`.
6. **Mood Check-In Non-Diagnostik**: Skala perasaan 1–5 bersifat refleksi diri append-only; dilarang melakukan diagnosis medis psikiatri atau penilaian risiko otomatis.
7. **Notifikasi Beretika**: Pemberitahuan pada bilah status ponsel menggunakan kalimat generik (contoh: *"Ada pesan baru di Ruang BK"*) guna mencegah kebocoran informasi pribadi di layar ponsel.

---

## 📁 Struktur Direktori Proyek (Feature-First)

```text
lib/
├── app/                  # Inisialisasi global aplikasi, theme, router, shell
│   ├── app.dart
│   ├── app_shell.dart    # Bilah navigasi bawah 5 tab
│   ├── router.dart       # Konfigurasi GoRouter dan guard sesi
│   └── theme/            # Tema Material 3 adaptif & tipografi Google Sans
├── core/                 # Komponen bersama, konstanta, penanganan galat
│   ├── config/           # AppEnv & bootstrap Supabase
│   ├── constants/        # Nilai spasi dan batasan tata letak
│   ├── errors/           # Kelas eksepsi aplikasi
│   └── widgets/          # Komponen StateViews (Loading, Empty, Error)
└── features/             # Modul fungsional independen
    ├── auth/             # Modul login, registrasi kode undangan, sesi
    ├── feed/             # Home Menfess feed, kartu post, detail, komentar
    ├── create_post/      # Formulir publikasi Menfess (publik / anonim)
    ├── explore/          # Pencarian teks debounce 400ms & filter kategori
    ├── counseling/       # Percakapan BK, janji temu, mood, peduli teman
    ├── moderation/       # Antrean penanganan laporan konten bagi admin
    ├── notifications/    # Pusat notifikasi internal aplikasi
    ├── profile/          # Profil akun, tampilan peran, keluar akun
    └── saved/            # Daftar postingan Menfess yang disimpan
supabase/
├── migrations/           # 34 berkas migrasi SQL (M1 s.d. M13 + patches)
└── verification/         # Rangkaian skrip uji verifikasi keamanan RLS
test/                     # 281 uji coba otomatis (unit, widget, provider)
laporan/                  # Dokumen master PRD/SRD Word (.docx) & Markdown
```

---

## 🚀 Panduan Menjalankan Proyek (Setup)

### 1. Prasyarat
- Flutter SDK versi stable (jalankan `flutter doctor -v` untuk memastikan Android toolchain terpasang dengan baik).
- Perangkat Android fisik atau Emulator Android (API Level 21 ke atas).

### 2. Konfigurasi Lingkungan (.env)
Salin berkas `.env.example` menjadi `.env` di direktori utama proyek, lalu isi nilai kredensial Supabase Anda:
```text
SUPABASE_URL=https://proyek-anda.supabase.co
SUPABASE_ANON_KEY=kunci-anon-publik-anda
```
*(Catatan: Berkas `.env` bersifat rahasia dan telah didaftarkan pada `.gitignore`).*

### 3. Mengunduh Dependensi & Menjalankan Analisis
```bash
# Mengunduh paket dependensi
flutter pub get

# Memeriksa kepatuhan kode statis (wajib 0 issue)
flutter analyze

# Menjalankan seluruh pengujian otomatis (281 test suite)
flutter test
```

### 4. Menjalankan Aplikasi
```bash
flutter run
```

---

## 📊 Status Pengujian & Penjaminan Mutu (Quality Assurance)

- **Static Analysis**: `flutter analyze` — **No issues found!**
- **Automated Tests**: `flutter test` — **281/281 PASS (100% Lulus)**
- **SQL Security Tests**: 12 berkas verifikasi keamanan SQL berhasil diuji pada Supabase CLI
- **Build Target**: APK Debug & Signed Release ready (`com.edufess.edufess`)

---

## 📄 Dokumen Laporan Lengkap
Berkas dokumentasi spesifikasi rekayasa perangkat lunak terpadu tersedia pada direktori `laporan/`:
- **[`laporan/Laporan_PRD_SRD_EduFess_FIX.docx`](laporan/Laporan_PRD_SRD_EduFess_FIX.docx)**: Dokumen Word resmi lengkap dengan 20 tabel terperinci, spesifikasi use case UC-01 s.d. UC-08, 10 invariansi privasi, dan diagram visual (Use Case, Class, Activity BK & Peduli Teman, DFD Level 0, ERD, serta Wireframe antarmuka 7.1 s.d. 7.8).
- **[`laporan/Laporan_Master_Final_EduFess.docx`](laporan/Laporan_Master_Final_EduFess.docx)**: Dokumen master final komprehensif mencakup seluruh progres 1–4 dan target 4–5 pertemuan ke depan.

---

## ⚖️ Lisensi & Hak Cipta
Hak Cipta © 2026 **Mila Novelia** (NPM 2413025051)  
Program Studi Pendidikan Teknologi Informasi, Jurusan PMIPA, FKIP, Universitas Lampung.  
*Dikembangkan untuk memenuhi tugas mata kuliah Mobile Programming (Dosen Pengampu: Ghea Chandra Surawan, M.Pd.).*
