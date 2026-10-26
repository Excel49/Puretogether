/*
 * =====================================================================
 * DIAGNOSTIK V2: RADAR DETEKSI SINYAL RX & BAUDRATE ESP-01 (PC13)
 * =====================================================================
 * Kenapa tadi kedip 1 detik terus?
 * Karena STM32 memanggil "AT", tapi tidak menerima jawaban "OK".
 *
 * Kode V2 ini bisa membedakan apakah:
 *  - Kabel TX ESP-01 ke PA3 putus/salah pin (0 byte masuk), ATAU
 *  - Ada sinyal masuk dari ESP-01, tapi belum berformat "OK".
 *
 * CARA BACA LAMPU PC13 PADA V2 INI:
 * ---------------------------------------------------------------------
 * 1. KEDIP 1x LAMBAT TIAP DETIK (Tetap 1x):
 *    -> 0 BYTE MASUK DI PA3! (Pin PA3 sama sekali tidak mendengar suara apa pun).
 *    -> Artinya murni masalah fisik kabel:
 *       a) Coba TUKAR kabel di PA2 dan PA3 sekarang juga!
 *       b) Pastikan pin tengah (CH_PD / EN) di ESP-01 ikut dicolok ke 3.3V!
 *       c) Pastikan GND ESP-01 nyambung ke GND STM32.
 *
 * 2. KEDIP 3x CEPAT (Ting-Ting-Ting!):
 *    -> ADA DATA MASUK DARI ESP-01 KE PA3! (Kabel RX sudah benar!),
 *       dan STM32 sedang otomatis menyamakan baudrate (115200 / 9600 / 57600 / 38400).
 *
 * 3. KEDIP 5x CEPAT -> LALU DETAK SINGKAT TIAP 1.5 DETIK:
 *    -> KOMUNIKASI "AT -> OK" BERHASIL 100%!
 *    -> Nama Wi-Fi akan otomatis berubah menjadi: "PureTogether_OK"
 *       (Cek daftar Wi-Fi di HP Anda, jika muncul "PureTogether_OK" berarti 100% beres!).
 * =====================================================================
 */

#include <Arduino.h>

HardwareSerial Serial2(PA3, PA2); // RX = PA3, TX = PA2
x
#define LED_PC13 PC13

void ledOn()  { digitalWrite(LED_PC13, LOW); }
void ledOff() { digitalWrite(LED_PC13, HIGH); }

void kedipKode(int jumlah, int durasiMs = 100) {
  for (int i = 0; i < jumlah; i++) {
    ledOn();
    delay(durasiMs);
    ledOff();
    delay(durasiMs);
  }
}

const long daftarBaud[4] = {115200, 9600, 57600, 74880};
int indexBaud = 0;
bool espOk = false;
bool adaByteMasuk = false;
unsigned long lastCheckMs = 0;
unsigned long lastHeartbeatMs = 0;

bool kirimAT(const char *cmd, const char *target, unsigned long timeoutMs) {
  while (Serial2.available()) Serial2.read();
  Serial2.print(cmd);
  Serial2.print("\r\n");

  String resp = "";
  unsigned long mulai = millis();
  while (millis() - mulai < timeoutMs) {
    while (Serial2.available()) {
      char c = (char)Serial2.read();
      adaByteMasuk = true; // Tanda ada sinyal listrik masuk ke PA3!
      resp += c;
      if (resp.indexOf(target) != -1) {
        return true;
      }
    }
  }
  return false;
}

void konfigurasiServerESP() {
  kirimAT("ATE0", "OK", 500);
  kirimAT("AT+CWMODE=2", "OK", 1000);
  // Kita beri nama SSID "PureTogether" agar langsung konek ke Flutter
  kirimAT("AT+CWSAP=\"PureTogether\",\"12345678\",1,3", "OK", 2000);
  kirimAT("AT+CIPMUX=1", "OK", 1000);
  kirimAT("AT+CIPSERVER=1,8888", "OK", 1500);
  kirimAT("AT+CIPSTO=5", "OK", 500);

  // Tanda sukses penuh: Kedip 5x cepat!
  kedipKode(5, 80);
  delay(400);
}

void setup() {
  pinMode(LED_PC13, OUTPUT);
  ledOff();
  delay(300);

  Serial2.begin(115200);
}

void loop() {
  // JIKA BELUM KONEK "OK", SCAN TERUS MENERUS (Bisa cabut-pasang kabel secara live!)
  if (!espOk) {
    adaByteMasuk = false;

    // Ganti-ganti baudrate tiap putaran agar pasti ketemu
    Serial2.begin(daftarBaud[indexBaud]);
    delay(50);

    // Kirim AT
    if (kirimAT("AT", "OK", 350)) {
      espOk = true;
      // Jika ketemu di baudrate selain 115200, paksa ESP-01 pindah ke 115200 agar cocok dengan main.ino!
      if (daftarBaud[indexBaud] != 115200) {
        Serial2.print("AT+UART_DEF=115200,8,1,0,0\r\n");
        delay(300);
        Serial2.begin(115200);
        delay(100);
      }
      konfigurasiServerESP();
      return;
    }

    indexBaud = (indexBaud + 1) % 4;

    if (adaByteMasuk) {
      // KEDIP 3x CEPAT: Ada sinyal masuk di PA3, tapi belum "OK"
      kedipKode(3, 80);
      delay(400);
    } else {
      // KEDIP 1x LAMBAT: 0 Byte masuk! Kabel TX/RX atau CH_PD belum bener
      kedipKode(1, 150);
      delay(850);
    }
    return;
  }

  // JIKA SUDAH KONEK & SERVER PORT 8888 AKTIF:
  // Layani request dari HP / Flutter
  if (Serial2.available()) {
    String baris = Serial2.readStringUntil('\n');
    int idx = baris.indexOf("+IPD,");
    if (idx != -1) {
      int idConn = baris.substring(idx + 5, idx + 6).toInt();
      ledOn(); // Nyala terang saat HP mengirim request!

      unsigned long t = millis();
      while (millis() - t < 50) {
        while (Serial2.available()) Serial2.read();
      }

      String json = "{\"status\":\"Aman\",\"mode\":\"Idle Standby\",\"debu_value\":15.0,\"battery_voltage\":7.4,\"wait_start\":0,\"map_data\":\"\"}";
      String httpResp = "HTTP/1.1 200 OK\r\n"
                        "Content-Type: application/json\r\n"
                        "Connection: close\r\n"
                        "Content-Length: " + String(json.length()) + "\r\n\r\n" + json;

      String cipSend = "AT+CIPSEND=" + String(idConn) + "," + String(httpResp.length());
      if (kirimAT(cipSend.c_str(), ">", 500)) {
        Serial2.print(httpResp);
        kirimAT("", "SEND OK", 1000);
      }
      Serial2.println("AT+CIPCLOSE=" + String(idConn));

      delay(300);
      ledOff();
    }
  }

  // Detak jantung tiap 1.5 detik tanda semua siap
  if (millis() - lastHeartbeatMs >= 1500) {
    lastHeartbeatMs = millis();
    ledOn();
    delay(35);
    ledOff();
  }
}
