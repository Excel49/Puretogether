# Kebutuhan Fitur Software Mobile (PureTogether App)
Dokumen ini merangkum fungsionalitas dan User Interface (UI) yang harus ada di dalam aplikasi mobile berdasarkan *endpoints* (API) dan data yang dikirimkan oleh firmware robot (`main/main.ino`).

## 1. Konektivitas & Jaringan
- **Wi-Fi Hotspot Connection**: Aplikasi harus bisa memberikan petunjuk bahwa HP pengguna harus terhubung ke Wi-Fi SSID `PureTogether` (dengan password `12345678`).
- **HTTP Polling**: Aplikasi harus secara konstan melakukan request `HTTP GET` ke `http://192.168.4.1/` (tiap 1 detik) untuk mengambil data JSON *real-time* dari robot.

## 2. Dashboard Pemantauan (Monitoring Data)
Data JSON dari robot berisi: `{"status":"...", "mode":"...", "debu_value":..., "battery_voltage":..., "map_data":"..."}`. Aplikasi mobile membutuhkan UI untuk menampilkan:
- **Status Kualitas Udara**: Menampilkan label "Aman" (hijau) atau "Bahaya" (merah/peringatan) jika debu melebihi ambang batas.
- **Kadar Debu (Density)**: Menampilkan nilai debu saat ini (contoh: `45.2 µg/m³`).
- **Tegangan Baterai**: Menampilkan voltase baterai (contoh: `12.0 V`), idealnya dikonversi menjadi persentase baterai agar mudah dipahami pengguna.
- **Mode Robot Saat Ini**: Menampilkan teks mode aktif, yaitu:
  - *Garis* (Line Follower / Auto)
  - *Remote Manual*
  - *Mapping Track* (Sedang melakukan kalibrasi)

## 3. Fitur Kontrol Opsional (Remote Manual)
Aplikasi harus menyediakan layar khusus (seperti D-Pad atau Joystick) yang memiliki kumpulan tombol (Buttons) untuk mengirim HTTP GET Request:
- **Tombol Mode**:
  - `Set Auto`: Mengirim request ke `/mode?val=auto` (Robot berjalan mandiri).
  - `Set Manual`: Mengirim request ke `/mode?val=manual` (Robot diam dan menunggu navigasi aplikasi).
- **Tombol Arah Motor (Hanya aktif saat Mode Manual)**:
  - `Maju (Forward)`: Mengirim request ke `/cmd?act=fwd`
  - `Mundur (Reverse)`: Mengirim request ke `/cmd?act=rev`
  - `Kiri (Left)`: Mengirim request ke `/cmd?act=left`
  - `Kanan (Right)`: Mengirim request ke `/cmd?act=right`
  - `Berhenti (Stop)`: Mengirim request ke `/cmd?act=stop`

## 4. Fitur Kalibrasi / Mapping Jalur
- **Tombol Mulai Kalibrasi**: Tombol perintah utama yang saat diklik akan mengirimkan request ke `/start-map`.
- Saat tombol ini diklik, robot tidak akan langsung memetakan jalan, melainkan dia akan menyalakan LED biru kedip-kedip, kemudian *Standby* untuk berinteraksi dengan garis start. Semuanya harus memiliki notifikasi/feedback UI di aplikasi agar pengguna tahu robot sedang menunggu di garis start/finish.
- **Tampilan Peta Pipa/Track (Map Data)**: Data *string* mentah berupa `L1000,K,L2000,Ki,` harus dikonversi oleh logic aplikasi mobile (menggunakan fungsi UI perantara / *canvas widget*) untuk menggambarkan jalur rute patroli robot.
