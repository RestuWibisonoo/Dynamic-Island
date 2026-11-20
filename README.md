# 🏝️ MacBook Dynamic Island (Native macOS App)

Aplikasi **Dynamic Island** natif untuk macOS, dirancang dengan **Swift 6, SwiftUI, dan AppKit** agar terasa menyatu sempurna (*first-party feel*) dengan MacBook Pro, MacBook Air, maupun Mac tanpa notch (iMac, Mac mini, monitor eksternal).

---

## ✨ Fitur Utama

- 📐 **Deteksi Notch Otomatis (Pixel-Perfect)**:
  - Menggunakan API `NSScreen.auxiliaryTopLeftArea` dan `safeAreaInsets.top` untuk memposisikan pulau pas di sekeliling notch fisik MacBook.
  - Jika digunakan pada monitor eksternal atau Mac tanpa notch, otomatis berubah menjadi **Floating Dynamic Pill**.
- 🪟 **Non-Activating NSPanel**:
  - Mengambang di atas semua aplikasi dan virtual desktop (Spaces / Fullscreen).
  - Tidak mencuri fokus aplikasi kerja Anda saat di-klik atau di-hover.
- 🎨 **Adaptive Theme & Apple HIG Aesthetic**:
  - Pilihan tema: **OLED Pure Black** (menyatu dengan notch), **Frosted Glass** (translucent vibrant), dan **Sistem macOS** (otomatis light/dark mode & aksen warna sistem).
  - Lekukan halus continuous corner radius dan border tipis 1px khas Apple.
- 🚀 **Otomatis Aktif Saat Mac Dinyalakan (Launch at Login)**:
  - Terintegrasi dengan Apple `SMAppService` dengan toggle langsung dari menu bar.
- 🌊 **Fluid Spring Animation**:
  - Transisi elastis saat kursor di-hover atau ditarik keluar.

---

## 🛠️ Cara Menjalankan

### 1. Menjalankan Langsung (Mode Pengembangan)
```bash
make run
# atau
swift run
```

### 2. Membangun Menjadi Aplikasi macOS (`DynamicIsland.app`)
```bash
make bundle
```
File `DynamicIsland.app` akan dibuat dan bisa langsung disalin ke folder `/Applications`.

---

## 🗺️ Roadmap Pengembangan
- [x] **Tahap 1**: Inisialisasi Proyek, Core Screen/Notch Detector, NSPanel non-activating, Theme Manager, Launch at Login, Animasi Hover Spring dasar.
- [ ] **Tahap 2**: Integrasi Media Player (Spotify & Apple Music via ScriptingBridge/AppleScript) + Live Waveform visualizer.
- [ ] **Tahap 3**: Drop Shelf (Drag & drop file stash di notch untuk transfer cepat).
- [ ] **Tahap 4**: System HUD (Indikator volume, kecerahan layar, status baterai & charger ring).
- [ ] **Tahap 5**: Window Preferensi & Kustomisasi Lengkap.
