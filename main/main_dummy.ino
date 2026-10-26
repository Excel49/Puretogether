/*
 * ===================================================================
 * ROBOT "PureTogether" - FIRMWARE TESTING KHUSUS LAMPU ONBOARD PC13
 * File: main/main_dummy.ino
 * Target Hardware: STM32F103C8T6 (Bluepill) + Modul WiFi ESP8266 ESP-01
 * ===================================================================
 * 
 * FUNGSI UTAMA:
 * Menguji komunikasi dua arah (Flutter <-> ESP-01 <-> STM32) TANPA PERLU SERIAL MONITOR.
 * Anda cukup melihat lampu LED Onboard (PC13) di papan Bluepill Anda!
 *
 * ===================================================================
 * TABEL KODE LAMPU LED PC13 (VISUAL FEEDBACK CODE):
 * ===================================================================
 *  1. BOOTING / WIFI SIAP:
 *     Kedip cepat 5 kali berturut-turut, lalu mati.
 *     -> Artinya: ESP-01 berhasil disetup & Hotspot 'PureTogether' sudah aktif!
 * 
 *  2. FLUTTER TERHUBUNG & POLLING SENSOR (Idle / Standby):
 *     Kedip kilat 1x (35 ms blip singkat) setiap ~1.5 detik.
 *     -> Artinya: HP terhubung dan sedang rutin menarik data sensor.
 * 
 *  3. TOMBOL D-PAD MAJU (Forward):
 *     Lampu NYALA TERUS (Solid ON tanpa mati).
 *     -> Artinya: Perintah Maju sedang aktif berjalan.
 * 
 *  4. TOMBOL D-PAD MUNDUR (Reverse):
 *     Kedip 2 kali berturut-turut.
 * 
 *  5. TOMBOL D-PAD BELOK KIRI (Left):
 *     Kedip 3 kali berturut-turut.
 * 
 *  6. TOMBOL D-PAD BELOK KANAN (Right):
 *     Kedip 4 kali berturut-turut.
 * 
 *  7. TOMBOL STOP / REM DARURAT:
 *     Lampu LANGSUNG MATI TOTAL (Padam).
 * 
 *  8. PINDAH KE "AUTO MODE":
 *     Lampu BERKEDIP SANTAI BERULANG (ritme napas 300ms ON / 300ms OFF).
 *     -> Menandakan robot sedang berjalan otomatis di jalur (Line Follower).
 * 
 *  9. PINDAH KE "MANUAL MODE":
 *     Lampu MATI (kembali ke mode standby remote).
 * 
 * 10. TOMBOL MULAI KALIBRASI (/start-map):
 *     Lampu KEDIP STROBE SANGAT CEPAT (80ms ON / 80ms OFF).
 *     -> Menandakan robot sedang bersiap/merekam peta.
 * ===================================================================
 *
 * KONEKSI KABEL:
 * - PA2 (STM32 TX)  ---> RX pada ESP-01
 * - PA3 (STM32 RX)  <--- TX pada ESP-01
 * - 3.3V & GND      ---> VCC, CH_PD (EN), GND pada ESP-01
 * - PC13            ---> LED Onboard bawaan STM32 Bluepill (sudah ada di board)
 * ===================================================================
 */

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// Serial2 ke ESP-01 (RX=PA3, TX=PA2)
HardwareSerial Serial2(PA3, PA2);

// Pin LED Onboard Bluepill (PC13, Active LOW: LOW=Nyala, HIGH=Mati)
#define PIN_LED_BUILDIN PC13
#define LED_BLUE PA8

// Pin Aktuator Virtual (Bisa diukur jika mau)
#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PB0
#define MOTOR_R_IN2 PB1

// Konfigurasi WiFi Hotspot ESP-01
#define WIFI_SSID "PureTogether"
#define WIFI_PASS "12345678"
#define WIFI_PORT "8888"

// Objek LCD (Auto-detect alamat 0x27 atau 0x3F, aman dilewati jika tidak ada)
LiquidCrystal_I2C lcd(0x27, 16, 2);
bool lcdTerpasang = false;

// ==========================================
// MESIN STATUS LAMPU LED PC13 & PA8
// ==========================================
enum LedMode {
  LED_MODE_DISCONNECTED, // Belum terhubung Flutter: kedip santai (300ms on, 300ms off) PC13 & PA8
  LED_MODE_MANUAL_IDLE,  // Terhubung: Mati, hanya blip singkat 35ms saat polling masuk
  LED_MODE_FORWARD,      // Nyala solid terus saat tombol Maju di-hold
  LED_MODE_BLINK_BURST,  // Kedip sejumlah N kali
  LED_MODE_AUTO,         // Napas santai berulang (300ms on, 300ms off)
  LED_MODE_CALIBRATION   // Strobe kilat berulang (80ms on, 80ms off)
};

LedMode ledMode = LED_MODE_DISCONNECTED;
int ledBlinkTarget = 0;
int ledBlinkCount = 0;
bool ledState = false;
unsigned long ledNextToggleMs = 0;

// Status Koneksi Flutter (Mobile App)
bool isFlutterConnected = false;
unsigned long lastFlutterReqMs = 0;
const unsigned long FLUTTER_TIMEOUT_MS = 4000;

void setLedPhysical(bool nyala) {
  // PC13 Active LOW: LOW = Nyala, HIGH = Mati
  digitalWrite(PIN_LED_BUILDIN, nyala ? LOW : HIGH);
  if (ledMode == LED_MODE_DISCONNECTED) {
    digitalWrite(LED_BLUE, nyala ? HIGH : LOW);
  } else {
    digitalWrite(LED_BLUE, LOW);
  }
}

void triggerLedBurst(int jumlahKedip) {
  ledMode = LED_MODE_BLINK_BURST;
  ledBlinkTarget = jumlahKedip * 2; // 1 kedip = nyala + mati
  ledBlinkCount = 0;
  ledState = true;
  setLedPhysical(true);
  ledNextToggleMs = millis() + 100;
}

void triggerLedBlip() {
  if (ledMode == LED_MODE_MANUAL_IDLE) {
    setLedPhysical(true);
    ledNextToggleMs = millis() + 35; // Nyala 35ms lalu mati
  }
}

void updateLedHandler(unsigned long now) {
  switch (ledMode) {
    case LED_MODE_DISCONNECTED:
      if (now >= ledNextToggleMs) {
        ledState = !ledState;
        setLedPhysical(ledState);
        ledNextToggleMs = now + 300; // Ritme kedip santai 300ms tanda mencari koneksi
      }
      break;

    case LED_MODE_MANUAL_IDLE:
      if (ledNextToggleMs > 0 && now >= ledNextToggleMs) {
        setLedPhysical(false);
        ledNextToggleMs = 0;
      }
      break;

    case LED_MODE_FORWARD:
      setLedPhysical(true); // Tetap menyala penuh
      break;

    case LED_MODE_BLINK_BURST:
      if (now >= ledNextToggleMs) {
        ledBlinkCount++;
        if (ledBlinkCount >= ledBlinkTarget) {
          // Selesai kedip sejumlah target, kembali ke state sebelumnya
          if (ledMode == LED_MODE_AUTO) {
            setLedPhysical(true);
          } else {
            ledMode = LED_MODE_MANUAL_IDLE;
            setLedPhysical(false);
          }
        } else {
          ledState = !ledState;
          setLedPhysical(ledState);
          ledNextToggleMs = now + 100; // Kecepatan kedip 100ms
        }
      }
      break;

    case LED_MODE_AUTO:
      if (now >= ledNextToggleMs) {
        ledState = !ledState;
        setLedPhysical(ledState);
        ledNextToggleMs = now + 300; // Ritme santai 300ms
      }
      break;

    case LED_MODE_CALIBRATION:
      if (now >= ledNextToggleMs) {
        ledState = !ledState;
        setLedPhysical(ledState);
        ledNextToggleMs = now + 80; // Ritme cepat 80ms
      }
      break;
  }
}

// ==========================================
// DATA DUMMY DINAMIS
// ==========================================
float dummyDust = 25.0;
float dummyVoltage = 7.4;
float dustThreshold = 100.0;
float dummyDustOverride = -1.0; // -1: dinamis, >=0: override dari aplikasi
bool isAirPoor = false;

enum State { STATE_IDLE, STATE_MANUAL };
State currentState = STATE_MANUAL; // Default MANUAL

String trackMap = "";
String lastActionReceived = "STANDBY";

unsigned long prevSensorMs = 0;
const unsigned long intervalSensor = 1200;

// ==========================================
// MESIN STATUS KOMUNIKASI NON-BLOCKING
// ==========================================
enum RxMode { RX_SCAN, RX_HEADER, RX_PAYLOAD };
enum TxState { TX_IDLE, TX_WAIT_PROMPT, TX_SENDING, TX_WAIT_SENDOK, TX_WAIT_CLOSE };

RxMode rxMode = RX_SCAN;
TxState txState = TX_IDLE;

char rxLine[48];
uint8_t rxLineLen = 0;
char rxHeader[24];
uint8_t rxHeaderLen = 0;
char reqLine[200];
uint8_t reqLen = 0;
bool reqLineDone = false;
int rxConnId = -1;
int rxRemaining = 0;
unsigned long rxLastByteMs = 0;

const uint8_t ANTRIAN_MAX = 5;
int antrianId[ANTRIAN_MAX];
bool antrianFastAck[ANTRIAN_MAX];
uint8_t antrianJumlah = 0;

int txConnId = -1;
String txBuf;
unsigned int txPos = 0;
unsigned long txMulaiMs = 0;

// Deklarasi Fungsi
void sendATCommand(String cmd, int waitTime);
void layaniESP();
void prosesByteESP(char c);
void prosesBarisESP(const char *baris);
void selesaiTerimaRequest();
void antrikanBalasan(int id, bool isFastAck = false);
void layaniTX();
void susunBalasanHTTP();
void mulaiKirimPayload();
void kirimClose();
void prosesPerintah(const char *path);
void updateDummyData();
void updateTampilanLCD();
bool cekI2CAddress(uint8_t addr);

// ==========================================
// SETUP
// ==========================================
void setup() {
  // Inisialisasi LED PC13 & PA8 (Biru)
  pinMode(PIN_LED_BUILDIN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_BLUE, LOW);
  setLedPhysical(false); // Pastikan mati di awal

  // Inisialisasi Serial2 ke ESP-01
  Serial2.begin(115200);
  Serial2.setTimeout(50);

  // Pin Motor Virtual
  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);

  // Deteksi LCD (Aman jika tidak ada)
  Wire.begin();
  if (cekI2CAddress(0x27)) {
    lcd = LiquidCrystal_I2C(0x27, 16, 2);
    lcdTerpasang = true;
  } else if (cekI2CAddress(0x3F)) {
    lcd = LiquidCrystal_I2C(0x3F, 16, 2);
    lcdTerpasang = true;
  }

  if (lcdTerpasang) {
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.print("PureTogether");
    lcd.setCursor(0, 1);
    lcd.print("Reset ESP...");
  }

  // Nyalakan LED selama proses booting ESP
  setLedPhysical(true);

  // Inisialisasi Hotspot ESP-01
  sendATCommand("AT+RST", 4000);
  sendATCommand("ATE0", 500);
  sendATCommand("AT", 1000);
  sendATCommand("AT+CWMODE=2", 1000);
  sendATCommand("AT+CWSAP=\"" WIFI_SSID "\",\"" WIFI_PASS "\",1,3", 2000);
  sendATCommand("AT+CIPMUX=1", 1000);
  sendATCommand("AT+CIPSERVER=1," WIFI_PORT, 2000);
  sendATCommand("AT+CIPSTO=5", 500);

  if (lcdTerpasang) {
    lcd.clear();
    lcd.print("Hotspot Ready!");
    lcd.setCursor(0, 1);
    lcd.print("Port: " WIFI_PORT);
  }

  // =========================================================
  // KODE LAMPU 1: BOOT SUKSES & WIFI SIAP
  // LED berkedip cepat 5 kali berturut-turut!
  // =========================================================
  for (int i = 0; i < 5; i++) {
    setLedPhysical(false);
    delay(80);
    setLedPhysical(true);
    delay(80);
  }
  setLedPhysical(false);

  // Mode Default: Menunggu koneksi dari aplikasi Flutter (kedip LED biru/PC13)
  ledMode = LED_MODE_DISCONNECTED;
}

// ==========================================
// MAIN LOOP
// ==========================================
void loop() {
  unsigned long now = millis();

  // 1. Cek timeout koneksi Flutter (jika >4 detik tidak ada request masuk)
  if (isFlutterConnected && (now - lastFlutterReqMs > FLUTTER_TIMEOUT_MS)) {
    isFlutterConnected = false;
    if (currentState == STATE_MANUAL) {
      ledMode = LED_MODE_DISCONNECTED;
    }
  }

  // 2. Jalankan pengendali lampu LED PC13 non-blocking
  updateLedHandler(now);

  // 3. Layani komunikasi data dari/ke ESP-01
  layaniESP();

  // 4. Perbarui data dummy secara periodik
  if (now - prevSensorMs >= intervalSensor) {
    prevSensorMs = now;
    updateDummyData();
    updateTampilanLCD();
  }
}

// ==========================================
// SIMULASI DATA SENSOR
// ==========================================
void updateDummyData() {
  if (dummyDustOverride >= 0) {
    dummyDust = dummyDustOverride;
    isAirPoor = (dummyDust > dustThreshold);
    return;
  }

  static float step = 0.0;
  step += 0.15;
  if (step > 6.28) step = 0.0;

  // Nilai debu bernapas antara 20 - 45 ug/m3
  dummyDust = 30.0 + (sin(step) * 12.0) + ((millis() % 7) * 0.3);
  if (dummyDust < 5.0) dummyDust = 5.0;

  // Baterai dinamis 7.3 - 7.5 V (2S Li-ion)
  dummyVoltage = 7.4 + (cos(step) * 0.1);
  isAirPoor = (dummyDust > dustThreshold);
}

void updateTampilanLCD() {
  if (!lcdTerpasang) return;
  if (rxMode != RX_SCAN || txState == TX_SENDING) return;

  lcd.setCursor(0, 0);
  String baris1 = "ACT:" + lastActionReceived;
  while (baris1.length() < 16) baris1 += " ";
  lcd.print(baris1.substring(0, 16));

  lcd.setCursor(0, 1);
  String baris2 = "D:" + String(dummyDust, 1) + " B:" + String(dummyVoltage, 1) + "V";
  while (baris2.length() < 16) baris2 += " ";
  lcd.print(baris2.substring(0, 16));
}

bool cekI2CAddress(uint8_t addr) {
  Wire.beginTransmission(addr);
  return (Wire.endTransmission() == 0);
}

void simpanPetaDariURL(const char *s) {
  String bersih;
  while (*s && *s != '&' && *s != ' ' && bersih.length() < 180) {
    char c;
    if (*s == '%' && isxdigit(s[1]) && isxdigit(s[2])) {
      char hx[3] = {s[1], s[2], 0};
      c = (char)strtol(hx, NULL, 16);
      s += 3;
    } else {
      c = *s;
      s++;
    }
    if (isalnum(c) || c == ',') {
      bersih += c;
    }
  }
  trackMap = bersih;
}

// ==========================================
// PENERJEMAH PERINTAH FLUTTER DENGAN KODE LAMPU
// ==========================================
void prosesPerintah(const char *path) {

  // 1. PERINTAH GERAK D-PAD
  if (strstr(path, "/cmd?act=fwd")) {
    lastActionReceived = "MAJU (FWD)";
    // KODE LAMPU: NYALA TERUS saat maju
    ledMode = LED_MODE_FORWARD;
  }
  else if (strstr(path, "/cmd?act=rev")) {
    lastActionReceived = "MUNDUR (REV)";
    // KODE LAMPU: KEDIP 2 KALI
    triggerLedBurst(2);
  }
  else if (strstr(path, "/cmd?act=left") || strstr(path, "/cmd?act=sleft")) {
    lastActionReceived = "BELOK KIRI";
    // KODE LAMPU: KEDIP 3 KALI
    triggerLedBurst(3);
  }
  else if (strstr(path, "/cmd?act=right") || strstr(path, "/cmd?act=sright")) {
    lastActionReceived = "BELOK KANAN";
    // KODE LAMPU: KEDIP 4 KALI
    triggerLedBurst(4);
  }
  else if (strstr(path, "/cmd?act=stop")) {
    lastActionReceived = "BERHENTI";
    // KODE LAMPU: MATI TOTAL (PADAM)
    ledMode = LED_MODE_MANUAL_IDLE;
    setLedPhysical(false);
  }

  // 2. PERINTAH UBAH MODE
  else if (strstr(path, "/mode?val=manual") || strstr(path, "/mode?val=idle")) {
    currentState = STATE_MANUAL;
    lastActionReceived = "MODE: MANUAL";
    // KODE LAMPU: PADAM (kembali standby remote)
    ledMode = LED_MODE_MANUAL_IDLE;
    setLedPhysical(false);
  }
  else if (strstr(path, "/mode?val=auto")) {
    currentState = STATE_IDLE;
    lastActionReceived = "MODE: AUTO";
    // KODE LAMPU: BERKEDIP SANTAI BERULANG (Ritme napas line follower)
    ledMode = LED_MODE_AUTO;
  }

  // 3. PERINTAH SIMPAN PETA MANUAL (/save-map?data=...)
  else if (strstr(path, "/save-map?data=")) {
    simpanPetaDariURL(strstr(path, "data=") + 5);
    lastActionReceived = "PETA DISIMPAN";
    triggerLedBurst(6);
  }

  // 4. PERINTAH EMOTE / INTERAKSI
  else if (strstr(path, "/emote?type=happy")) {
    lastActionReceived = "EMOTE: HAPPY";
    triggerLedBurst(5); // Kedip ceria 5 kali
  }
  else if (strstr(path, "/emote?type=angry")) {
    lastActionReceived = "EMOTE: ANGRY";
    triggerLedBurst(1); // 1 kedip panjang
  }
  else if (strstr(path, "/emote?type=birthday")) {
    lastActionReceived = "EMOTE: BIRTHDAY";
    triggerLedBurst(10); // 10 kedip pesta perayaan ulang tahun!
  }

  // 5. SIMULASI OVERRIDE NILAI DEBU
  else if (strstr(path, "/dummy?dust=")) {
    float val = atof(strstr(path, "dust=") + 5);
    dummyDustOverride = val;
    if (dummyDustOverride >= 0) {
      dummyDust = dummyDustOverride;
      isAirPoor = (dummyDust > dustThreshold);
    }
    lastActionReceived = "DUST: " + String((int)dummyDust);
    triggerLedBurst(2);
  }

  // 6. POLLING TELEMETRI BIASA DARI FLUTTER ("/" atau "/status")
  else {
    lastActionReceived = "POLL TELEMETRI";
    // KODE LAMPU: BLIP KILAT 1X (35ms) tanda heartbeat data masuk!
    triggerLedBlip();
  }

  updateTampilanLCD();
}

// ==========================================
// PENANGANAN KOMUNIKASI BUFFER ESP-01
// ==========================================
void layaniESP() {
  while (Serial2.available()) {
    char c = (char)Serial2.read();
    rxLastByteMs = millis();
    prosesByteESP(c);
  }

  if (rxMode != RX_SCAN && (millis() - rxLastByteMs > 50)) {
    if (rxMode == RX_PAYLOAD) {
      selesaiTerimaRequest();
    } else {
      rxMode = RX_SCAN;
    }
  }

  layaniTX();
}

void prosesByteESP(char c) {
  if (rxMode == RX_HEADER) {
    if (c == ':') {
      rxHeader[rxHeaderLen] = 0;
      char *koma = strchr(rxHeader, ',');
      if (koma == NULL) {
        rxMode = RX_SCAN;
        return;
      }
      rxConnId = atoi(rxHeader);
      rxRemaining = atoi(koma + 1);
      reqLen = 0;
      reqLineDone = false;
      rxMode = (rxRemaining > 0) ? RX_PAYLOAD : RX_SCAN;
    } else if (rxHeaderLen < sizeof(rxHeader) - 1) {
      rxHeader[rxHeaderLen++] = c;
    } else {
      rxMode = RX_SCAN;
    }
    return;
  }

  if (rxMode == RX_PAYLOAD) {
    if (!reqLineDone) {
      if (c == '\r' || c == '\n') {
        reqLineDone = true;
      } else if (reqLen < sizeof(reqLine) - 1) {
        reqLine[reqLen++] = c;
      }
    }
    rxRemaining--;
    if (rxRemaining <= 0) {
      selesaiTerimaRequest();
    }
    return;
  }

  if (txState == TX_WAIT_PROMPT && c == '>') {
    rxLineLen = 0;
    mulaiKirimPayload();
    return;
  }
  if (c == '\r') return;
  if (c == '\n') {
    rxLine[rxLineLen] = 0;
    if (rxLineLen > 0) {
      prosesBarisESP(rxLine);
    }
    rxLineLen = 0;
    return;
  }
  if (rxLineLen < sizeof(rxLine) - 1) {
    rxLine[rxLineLen++] = c;
  } else {
    rxLineLen = 0;
  }

  if (rxLineLen >= 5 && memcmp(rxLine + rxLineLen - 5, "+IPD,", 5) == 0) {
    rxMode = RX_HEADER;
    rxHeaderLen = 0;
    rxLineLen = 0;
  }
}

void prosesBarisESP(const char *baris) {
  switch (txState) {
    case TX_WAIT_PROMPT:
      if (strstr(baris, "ERROR") || strstr(baris, "link is not valid") ||
          (strstr(baris, ",CLOSED") && atoi(baris) == txConnId)) {
        txState = TX_IDLE;
      }
      break;
    case TX_WAIT_SENDOK:
      if (strstr(baris, "SEND OK")) {
        kirimClose();
      } else if (strstr(baris, "SEND FAIL") || strstr(baris, "ERROR")) {
        txState = TX_IDLE;
      }
      break;
    case TX_WAIT_CLOSE:
      if (strcmp(baris, "OK") == 0 || strstr(baris, "ERROR") || strstr(baris, "UNLINK")) {
        txState = TX_IDLE;
      }
      break;
    default:
      break;
  }
}

void selesaiTerimaRequest() {
  rxMode = RX_SCAN;
  reqLine[reqLen] = 0;

  if (strncmp(reqLine, "GET ", 4) != 0) return;

  char *path = reqLine + 4;
  char *spasi = strchr(path, ' ');
  if (spasi != NULL) *spasi = 0;

  isFlutterConnected = true;
  lastFlutterReqMs = millis();
  if (ledMode == LED_MODE_DISCONNECTED) {
    ledMode = LED_MODE_MANUAL_IDLE;
    setLedPhysical(false);
  }

  prosesPerintah(path);
  bool isMotorCmd = (strstr(path, "/cmd?act=") != NULL && !isAirPoor);
  antrikanBalasan(rxConnId, isMotorCmd);
}

void antrikanBalasan(int id, bool isFastAck) {
  if (id < 0 || id > 4) return;
  for (uint8_t i = 0; i < antrianJumlah; i++) {
    if (antrianId[i] == id) return;
  }
  if (antrianJumlah < ANTRIAN_MAX) {
    antrianId[antrianJumlah] = id;
    antrianFastAck[antrianJumlah] = isFastAck;
    antrianJumlah++;
  }
}

void layaniTX() {
  switch (txState) {
    case TX_IDLE:
      if (antrianJumlah > 0) {
        txConnId = antrianId[0];
        bool fastAck = antrianFastAck[0];
        for (uint8_t i = 1; i < antrianJumlah; i++) {
          antrianId[i - 1] = antrianId[i];
          antrianFastAck[i - 1] = antrianFastAck[i];
        }
        antrianJumlah--;

        if (fastAck) {
          txBuf = "HTTP/1.1 200 OK\r\n\r\n";
        } else {
          susunBalasanHTTP();
        }

        Serial2.print("AT+CIPSEND=");
        Serial2.print(txConnId);
        Serial2.print(",");
        Serial2.print(txBuf.length());
        Serial2.print("\r\n");
        txState = TX_WAIT_PROMPT;
        txMulaiMs = millis();
      }
      break;

    case TX_WAIT_PROMPT:
      if (millis() - txMulaiMs > 1000) txState = TX_IDLE;
      break;

    case TX_SENDING:
      while (txPos < txBuf.length() && Serial2.availableForWrite() > 0) {
        Serial2.write(txBuf[txPos++]);
      }
      if (txPos >= txBuf.length()) {
        txState = TX_WAIT_SENDOK;
        txMulaiMs = millis();
      }
      break;

    case TX_WAIT_SENDOK:
      if (millis() - txMulaiMs > 2000) txState = TX_IDLE;
      break;

    case TX_WAIT_CLOSE:
      if (millis() - txMulaiMs > 300) txState = TX_IDLE;
      break;
  }
}

void mulaiKirimPayload() {
  txPos = 0;
  txState = TX_SENDING;
}

void kirimClose() {
  Serial2.print("AT+CIPCLOSE=");
  Serial2.print(txConnId);
  Serial2.print("\r\n");
  txState = TX_WAIT_CLOSE;
  txMulaiMs = millis();
}

void susunBalasanHTTP() {
  String modeStr = "Remote Manual";
  if (currentState == STATE_IDLE) modeStr = "Garis";

  String json = "{\"status\":\"";
  json += isAirPoor ? "Bahaya" : "Aman";
  json += "\",\"mode\":\"";
  json += modeStr;
  json += "\",\"debu_value\":";
  json += String(dummyDust, 1);
  json += ",\"battery_voltage\":";
  json += String(dummyVoltage, 1);
  json += ",\"wait_start\":0";
  json += ",\"map_data\":\"";
  json += trackMap;
  json += "\"}";

  txBuf = "HTTP/1.1 200 OK\r\n"
          "Content-Type: application/json\r\n"
          "Access-Control-Allow-Origin: *\r\n"
          "Connection: close\r\n"
          "Content-Length: ";
  txBuf += json.length();
  txBuf += "\r\n\r\n";
  txBuf += json;
}

void sendATCommand(String cmd, int waitTime) {
  Serial2.println(cmd);
  delay(waitTime);
  while (Serial2.available()) {
    Serial2.read();
  }
}
