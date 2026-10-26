/*
 * ROBOT "PureTogether" - PATROLI PENDETEKSI KUALITAS UDARA + MAPPING
 * Microcontroller: STM32F103C8T6 (Bluepill)
 * Komponen:
 * - Motor Driver MX1508 (Kiri: PA7/PA6, Kanan: PB0/PB1)
 * - 3x Sensor Garis TCRT5000 (PB12, PB13, PB14)
 * - Sensor Debu GP2Y1010AU0F (LED: PA1, AOUT: PA0)
 * - LCD 1602 I2C & INA226 (SDA: PB7, SCL: PB6)
 * - Buzzer (PB15), LED RGB 1 & 2
 * - Komunikasi Serial2 ke ESP-01 (TX: PA2, RX: PA3) - Mode Hotspot
 *
 * ===================================================================
 * INTEGRASI v2 - KOMUNIKASI NON-BLOCKING (ANTI TABRAKAN DATA)
 * ===================================================================
 * Masalah versi lama:
 *  - Request HTTP dibaca dengan readStringUntil('\n') -> sisa header HTTP
 *    tertinggal di buffer dan merusak "+IPD" berikutnya.
 *  - Balasan dikirim dengan delay() tetap (300ms + 400ms). Selama STM32
 *    "tertidur", request baru dari HP ditolak ESP ("busy p...") -> port macet.
 *
 * Solusi versi ini (mengadopsi pola dummy/Testing.ino yang terbukti lancar):
 *  1. "+IPD,<id>,<len>:" dibaca PERSIS sebanyak <len> byte (buffer selalu bersih).
 *  2. Perintah (motor/mode) DIEKSEKUSI SEKETIKA begitu baris request terbaca,
 *     sebelum balasan dikirim -> respons motor secepat versi dummy.
 *  3. Balasan dikirim lewat mesin status non-blocking: tunggu '>' dari ESP,
 *     kirim data, tunggu "SEND OK", lalu AT+CIPCLOSE. TIDAK ADA delay() tetap,
 *     sehingga PID line follower tetap berjalan selama komunikasi.
 *  4. "Nebeng data" (piggyback): SETIAP balasan berisi JSON telemetri terbaru.
 *     HP tidak perlu request terpisah untuk sensor saat sedang mengendalikan.
 *  5. Antrian balasan: jika request datang saat balasan lain sedang dikirim,
 *     perintahnya tetap langsung dieksekusi & balasannya diantrikan.
 *  6. Failsafe: di mode MANUAL, motor berhenti otomatis jika HP tidak
 *     mengirim request apa pun selama FAILSAFE_MS (mis. Wi-Fi HP putus).
 *
 * Endpoint (port 8888):
 *  /  atau /status        -> hanya minta telemetri
 *  /mode?val=manual|auto  -> ganti mode
 *  /cmd?act=fwd|rev|left|right|sleft|sright|stop
 *                          (stop selalu dihormati & memindah robot ke MANUAL)
 *  /start-map, /stop-map  -> mulai/batalkan kalibrasi peta
 *  /save-map?data=...     -> simpan peta hasil rekaman manual dari aplikasi
 *  /emote?type=happy|angry
 *
 * Format balasan JSON:
 *  {"status":"Aman","mode":"Garis","debu_value":45.2,"battery_voltage":12.0,
 *   "wait_start":0,"map_data":"L4500,K,L2000,Ki,"}
 *
 * CATATAN: file build_opt.h di folder ini memperbesar buffer Serial menjadi
 * 512 byte (default core STM32 hanya 64 byte, terlalu kecil untuk request HTTP).
 */

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

HardwareSerial Serial2(PA3, PA2); // Mendeklarasikan objek Serial2 khusus
                                  // (RX=PA3, TX=PA2) untuk core STM32 resmi

// ==========================================
// 1. PENGATURAN PIN
// ==========================================
#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PB0 // Pengganti PB10 (pin kosong tepat di sebelah PA7)
#define MOTOR_R_IN2 PB1 // Pengganti PB11 (pin kosong tepat di sebelah PB0)

#define PIN_SENSOR_L PB12
#define PIN_SENSOR_C PB13
#define PIN_SENSOR_R PB14

#define DUST_LED PA1
#define DUST_AOUT PA0

#define BUZZER_PIN PB15

#define LED_BLUE PA8
#define LED_GREEN PA9
#define LED_RED PA10

// Polaritas LED RGB. Mengikuti dummy/Testing.ino (sudah terbukti di hardware):
// Common Anode -> LOW = Nyala. Jika LED Anda Common Cathode, ubah menjadi 0.
#define LED_COMMON_ANODE 1
#if LED_COMMON_ANODE
#define LED_NYALA LOW
#define LED_MATI HIGH
#else
#define LED_NYALA HIGH
#define LED_MATI LOW
#endif

// ==========================================
// 2. KONFIGURASI WIFI / ESP-01
// ==========================================
#define WIFI_SSID "PureTogether"
#define WIFI_PASS "12345678"
#define WIFI_PORT "8888"

const unsigned long FAILSAFE_MS = 15000;      // Manual: rem pengaman jika sinyal putus > 15 dtk
const unsigned long RX_PAYLOAD_TIMEOUT = 50;  // Batas tunggu sisa byte request
const unsigned long TX_PROMPT_TIMEOUT = 400;  // Batas tunggu '>' setelah CIPSEND
const unsigned long TX_SENDOK_TIMEOUT = 600;  // Batas tunggu "SEND OK"
const unsigned long TX_CLOSE_TIMEOUT = 150;   // Batas tunggu balasan CIPCLOSE

// ==========================================
// 3. VARIABEL SISTEM KUALITAS UDARA
// ==========================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

float dustDensity = 0.0;
float dustThreshold = 100.0; // Sesuaikan batas debu
float batteryVoltage = 7.4;
float dummyDustOverride = -1.0; // -1: baca sensor GP2Y10 fisik, >=0: bypass nilai uji

unsigned long previousMillisSensors = 0;
const unsigned long intervalSensors = 1000;
bool isAirPoor = false;

// Status Koneksi Flutter (Mobile App)
bool isFlutterConnected = false;
unsigned long lastFlutterReqMs = 0;
const unsigned long FLUTTER_TIMEOUT_MS = 4000; // >4 dtk tanpa request = terputus/mencari

// ==========================================
// 4. VARIABEL STATE MACHINE & PID MAPPING
// ==========================================
float Kp = 15.0;
float Kd = 5.0;
int baseSpeed = 120;   // Kecepatan line follower (halus dan stabil)
int manualSpeed = 160; // Kecepatan Maju / Mundur remote (sebelumnya 255 - sekarang tenang & aman)
int turnSpeed = 125;   // Kecepatan Belok Kiri / Kanan (presisi, tidak gampang kebablasan)
int lastError = 0;

int sL = 0, sC = 0, sR = 0;
bool isAllBlackProcessed = false;

// Sesi Mode Robot & Peta Manual
enum State { STATE_IDLE, STATE_MANUAL, STATE_WAIT_START, STATE_COUNTDOWN };
State currentState = STATE_MANUAL; // Default MANUAL agar diam saat menyala
String trackMap = "";

// Hitung mundur auto mode di garis start
unsigned long countdownMulai = 0;
int countdownDetik = 3;
unsigned long buzzerBeepSampai = 0;

// Jeda non-blocking (pengganti delay() di logika garis)
bool jedaAktif = false;
unsigned long jedaSampai = 0;

// Failsafe manual
unsigned long lastCmdMs = 0;
bool manualBergerak = false;

// ==========================================
// 5. EFEK LED & BUZZER (NON-BLOCKING)
// ==========================================
enum Efek { EFEK_NONE, EFEK_BLINK_BIRU, EFEK_HAPPY, EFEK_ANGRY, EFEK_MAP_DONE, EFEK_BIRTHDAY };
Efek efekAktif = EFEK_NONE;
unsigned long efekMulai = 0;
unsigned long efekDurasi = 0;

// ==========================================
// 6. LCD (HANYA MENULIS BARIS YANG BERUBAH)
// ==========================================
char lcdIsi[2][17];
bool lcdKotor[2] = {false, false};
unsigned long lcdPesanSampai = 0;

// ==========================================
// 7. MESIN STATUS KOMUNIKASI ESP-01
// ==========================================
enum RxMode { RX_SCAN, RX_HEADER, RX_PAYLOAD };
enum TxState { TX_IDLE, TX_WAIT_PROMPT, TX_SENDING, TX_WAIT_SENDOK, TX_WAIT_CLOSE };

RxMode rxMode = RX_SCAN;
TxState txState = TX_IDLE;

char rxLine[48];          // Baris status dari ESP ("SEND OK", "0,CLOSED", ...)
uint8_t rxLineLen = 0;
char rxHeader[24];        // "<id>,<len>" dari +IPD
uint8_t rxHeaderLen = 0;
char reqLine[200];        // Baris pertama request: "GET /cmd?act=fwd HTTP/1.1"
uint8_t reqLen = 0;
bool reqLineDone = false;
int rxConnId = -1;
int rxRemaining = 0;
unsigned long rxLastByteMs = 0;

const uint8_t ANTRIAN_MAX = 5; // ESP-01 maksimal 5 koneksi (id 0..4)
int antrianId[ANTRIAN_MAX];
bool antrianFastAck[ANTRIAN_MAX];
uint8_t antrianJumlah = 0;

int txConnId = -1;
String txBuf;
unsigned int txPos = 0;
unsigned long txMulaiMs = 0;

// ==========================================
// DEKLARASI FUNGSI
// ==========================================
void bacaSensorGaris();
void kalkulasiPID();
void aturMotor(int pwmLeft, int pwmRight);
void bacaKualitasUdara();
void updateStatus();
void sendATCommand(String cmd, int waitTime);

void mulaiJeda(unsigned long durasi);
void setLED(bool r, bool g, bool b);
void terapkanLedStatus();
void mulaiEfek(Efek e, unsigned long durasi);
void updateEfek(unsigned long now);

void lcdSet(uint8_t baris, const String &teks);
void lcdPesan(const String &teks, unsigned long durasi);
void updateLCD();
const char *namaModeJSON();
const char *namaModeLCD();

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
void prosesGerak(const char *act);
void simpanPetaDariURL(const char *s);

// ==========================================
// FUNGSI BANTUAN ESP-01 AT COMMAND (HANYA DIPAKAI SAAT SETUP)
// ==========================================
void sendATCommand(String cmd, int waitTime) {
  Serial2.println(cmd);
  delay(waitTime);
  while (Serial2.available()) {
    Serial2.read();
  }
}

// ==========================================
// 8. SETUP
// ==========================================
void setup() {
  // Serial.begin() sengaja TIDAK dipakai: pada Bluepill, Serial (USART1)
  // berada di PA9/PA10 yang bentrok dengan LED Hijau & Merah.
  Serial2.begin(115200); // TX=PA2, RX=PA3
  analogReadResolution(12); // ADC STM32 12-bit (0..4095)

  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.print("PureTogether Bot");

  pinMode(PIN_SENSOR_L, INPUT);
  pinMode(PIN_SENSOR_C, INPUT);
  pinMode(PIN_SENSOR_R, INPUT);

  pinMode(DUST_LED, OUTPUT);
  digitalWrite(DUST_LED, HIGH); // LED IR sensor debu aktif LOW -> matikan dulu

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  setLED(false, false, false);

  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);
  pinMode(PB10, INPUT); // Amankan pin motor lama (PB10/PB11 & PA5/PA4)
  pinMode(PB11, INPUT);
  pinMode(PA5, INPUT);
  pinMode(PA4, INPUT);
  aturMotor(0, 0);

  // KONFIGURASI ESP8266 WIFI HOTSPOT (AP MODE) - urutan sama dengan dummy
  lcd.setCursor(0, 1);
  lcd.print("Reset ESP...    ");
  sendATCommand("AT+RST", 4000);

  lcd.setCursor(0, 1);
  lcd.print("Memulai ESP...  ");
  sendATCommand("ATE0", 500); // Matikan echo: kurangi lalu lintas UART
  sendATCommand("AT", 1000);
  sendATCommand("AT+CWMODE=2", 1000);
  sendATCommand("AT+CWSAP=\"" WIFI_SSID "\",\"" WIFI_PASS "\",1,3", 2000);
  sendATCommand("AT+CIPMUX=1", 1000);
  sendATCommand("AT+CIPSERVER=1," WIFI_PORT, 2000);
  sendATCommand("AT+CIPSTO=5", 500); // Koneksi menggantung ditutup ESP stlh 5 dtk

  lcd.clear();
  lcd.print("Hotspot Ready!");
  delay(800);
  lcd.clear();
  memset(lcdIsi, 0, sizeof(lcdIsi));

  bacaKualitasUdara();
  updateStatus();
  lastCmdMs = millis();
}

// ==========================================
// 9. MAIN LOOP (TANPA delay())
// ==========================================
void loop() {
  // ----- KOMUNIKASI HP <-> ESP-01 (selalu dilayani paling awal) -----
  layaniESP();

  unsigned long now = millis();
  updateEfek(now);

  // ----- STATUS KONEKSI FLUTTER & INDIKATOR LED -----
  if (isFlutterConnected && (long)(now - lastFlutterReqMs) > (long)FLUTTER_TIMEOUT_MS) {
    isFlutterConnected = false;
  }
  if (efekAktif == EFEK_NONE) {
    terapkanLedStatus(); // Menjamin LED Biru berkedip saat mencari koneksi
  }

  // ----- PEMBACAAN KUALITAS UDARA (Tiap 1 Detik) -----
  if (now - previousMillisSensors >= intervalSensors) {
    previousMillisSensors = now;
    bacaKualitasUdara();
    updateStatus();
  }
  updateLCD();

  // ----- FAILSAFE: HP tidak terdengar saat robot dikendalikan manual -----
  if (currentState == STATE_MANUAL && manualBergerak &&
      (long)(now - lastCmdMs) > (long)FAILSAFE_MS) {
    aturMotor(0, 0);
    manualBergerak = false;
    lcdPesan("FAILSAFE: STOP", 2000);
  }

  // ----- KONDISI BAHAYA: BERHENTI -----
  if (isAirPoor) {
    aturMotor(0, 0);
    manualBergerak = false;
    bool beepState = (now / 300) % 2;
    digitalWrite(BUZZER_PIN, beepState ? HIGH : LOW);
    return;
  }

  if (efekAktif == EFEK_NONE && !isAirPoor && (long)(now - buzzerBeepSampai) >= 0) {
    digitalWrite(BUZZER_PIN, LOW); // Matikan buzzer jika udara bersih & pulsa beep selesai
  }

  // ----- JEDA NON-BLOCKING (pengganti delay di logika garis) -----
  if (jedaAktif) {
    if ((long)(now - jedaSampai) < 0) {
      aturMotor(0, 0);
      return;
    }
    jedaAktif = false;
  }

  // Mode manual: motor murni dikendalikan aplikasi lewat HTTP
  if (currentState == STATE_MANUAL) {
    return;
  }

  // ----- MODE AUTO: TUNGGU GARIS START & HITUNG MUNDUR 3 DETIK -----
  if (currentState == STATE_WAIT_START) {
    aturMotor(0, 0);
    bacaSensorGaris();
    // Tunggu garis start (semua sensor TCRT5000 mendeteksi garis bersamaan)
    if ((sL == 0 && sC == 0 && sR == 0) || (sL == 1 && sC == 1 && sR == 1)) {
      currentState = STATE_COUNTDOWN;
      countdownMulai = now;
      countdownDetik = 3;
      digitalWrite(BUZZER_PIN, HIGH);
      buzzerBeepSampai = now + 180; // Beep detik ke-3
      lcdPesan("START DALAM: 3", 1000);
    }
    return;
  }

  if (currentState == STATE_COUNTDOWN) {
    aturMotor(0, 0);
    unsigned long elapsed = now - countdownMulai;

    if (elapsed < 1000) {
      // Detik ke-3 sedang berjalan
    } else if (elapsed < 2000) {
      if (countdownDetik == 3) {
        countdownDetik = 2;
        digitalWrite(BUZZER_PIN, HIGH);
        buzzerBeepSampai = now + 180; // Beep detik ke-2
        lcdPesan("START DALAM: 2", 1000);
      }
    } else if (elapsed < 3000) {
      if (countdownDetik == 2) {
        countdownDetik = 1;
        digitalWrite(BUZZER_PIN, HIGH);
        buzzerBeepSampai = now + 180; // Beep detik ke-1
        lcdPesan("START DALAM: 1", 1000);
      }
    } else {
      // 3 detik selesai: Beep panjang lalu mulai jalan
      digitalWrite(BUZZER_PIN, HIGH);
      buzzerBeepSampai = now + 500;
      currentState = STATE_IDLE; // Mulai patroli garis otomatis!
      isAllBlackProcessed = true; // Tandai agar garis awal tidak memicu start baru
      lcdPesan("PATROLI MULAI!", 1500);
    }
    return;
  }

  // ----- KONDISI NORMAL: LINE FOLLOWER AUTO PATROL -----
  bacaSensorGaris();

  // Jika melewati garis melintang (Start/Finish), tetap melaju lurus stabil
  if (sL == 0 && sC == 0 && sR == 0) {
    if (!isAllBlackProcessed) {
      isAllBlackProcessed = true;
      lcdPesan("CROSSING LINE", 800);
    }
    aturMotor(baseSpeed, baseSpeed);
  } else {
    isAllBlackProcessed = false;
    kalkulasiPID();
  }
}

// ==========================================
// 10. KOMUNIKASI ESP-01 (NON-BLOCKING)
// ==========================================
void layaniESP() {
  // 1) Baca semua byte yang sudah tiba, tanpa menunggu
  while (Serial2.available()) {
    char c = (char)Serial2.read();
    rxLastByteMs = millis();
    prosesByteESP(c);
  }

  // 2) Jika sebagian byte request hilang (buffer penuh), jangan menggantung:
  //    proses apa adanya setelah RX_PAYLOAD_TIMEOUT tanpa byte baru.
  if (rxMode != RX_SCAN && (millis() - rxLastByteMs > RX_PAYLOAD_TIMEOUT)) {
    if (rxMode == RX_PAYLOAD) {
      selesaiTerimaRequest();
    } else {
      rxMode = RX_SCAN; // Header +IPD rusak
    }
  }

  // 3) Jalankan mesin pengirim balasan
  layaniTX();
}

void prosesByteESP(char c) {
  if (rxMode == RX_HEADER) {
    if (c == ':') {
      rxHeader[rxHeaderLen] = 0;
      // Format: "<id>,<len>" (atau "<id>,<len>,<ip>,<port>" jika CIPDINFO=1)
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
      rxMode = RX_SCAN; // Header terlalu panjang = rusak
    }
    return;
  }

  if (rxMode == RX_PAYLOAD) {
    // Simpan HANYA baris pertama; sisa header HTTP dibuang tapi tetap DIHITUNG
    // agar buffer bersih untuk +IPD berikutnya (kunci kelancaran versi dummy).
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

  // ----- RX_SCAN: membaca pesan status dari ESP -----
  if (txState == TX_WAIT_PROMPT && c == '>') {
    rxLineLen = 0;
    mulaiKirimPayload(); // ESP siap menerima data balasan
    return;
  }
  if (c == '\r') {
    return;
  }
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
    rxLineLen = 0; // Baris terlalu panjang, buang
  }
  // Deteksi awal paket data masuk: "+IPD,"
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
      txState = TX_IDLE; // Klien sudah pergi, batalkan balasan
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
    if (strcmp(baris, "OK") == 0 || strstr(baris, "ERROR") ||
        strstr(baris, "UNLINK")) {
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

  // Hanya layani request HTTP GET yang valid
  if (strncmp(reqLine, "GET ", 4) != 0) {
    return;
  }
  char *path = reqLine + 4;
  char *spasi = strchr(path, ' ');
  if (spasi != NULL) {
    *spasi = 0;
  }

  isFlutterConnected = true;
  lastFlutterReqMs = millis();
  lastCmdMs = millis(); // Setiap request = tanda HP masih terhubung (failsafe)
  prosesPerintah(path); // Eksekusi SEKARANG, jangan tunggu balasan terkirim

  // Jika request adalah perintah motor (/cmd?act=...), gunakan Fast-ACK 19 byte
  // TETAPI jika terdeteksi asap (isAirPoor), kirim JSON telemetri lengkap agar Flutter langsung menerima alert
  bool isMotorCmd = (strstr(path, "/cmd?act=") != NULL && !isAirPoor);
  antrikanBalasan(rxConnId, isMotorCmd);
}

void antrikanBalasan(int id, bool isFastAck) {
  if (id < 0 || id > 4) {
    return;
  }
  for (uint8_t i = 0; i < antrianJumlah; i++) {
    if (antrianId[i] == id) {
      return; // Sudah diantrikan
    }
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
        // MURNI 1 ARAH (Flutter -> STM32):
        // Untuk perintah gerak manual, STM32 TIDAK MENGIRIM DATA BALASAN APA PUN ke Flutter!
        // Cukup langsung tutup soket (AT+CIPCLOSE) agar 0 byte dikirim balik dan bebas delay 100%.
        kirimClose();
      } else {
        susunBalasanHTTP(); // JSON telemetri sensor lengkap (hanya saat mode Idle / Auto)
        Serial2.print("AT+CIPSEND=");
        Serial2.print(txConnId);
        Serial2.print(",");
        Serial2.print(txBuf.length());
        Serial2.print("\r\n");
        txState = TX_WAIT_PROMPT;
        txMulaiMs = millis();
      }
    }
    break;

  case TX_WAIT_PROMPT:
    if (millis() - txMulaiMs > TX_PROMPT_TIMEOUT) {
      txState = TX_IDLE;
    }
    break;

  case TX_SENDING:
    // Tulis sebanyak ruang buffer TX yang tersedia, sisanya di putaran berikut
    while (txPos < txBuf.length() && Serial2.availableForWrite() > 0) {
      Serial2.write(txBuf[txPos++]);
    }
    if (txPos >= txBuf.length()) {
      txState = TX_WAIT_SENDOK;
      txMulaiMs = millis();
    }
    break;

  case TX_WAIT_SENDOK:
    if (millis() - txMulaiMs > TX_SENDOK_TIMEOUT) {
      txState = TX_IDLE;
    }
    break;

  case TX_WAIT_CLOSE:
    if (millis() - txMulaiMs > TX_CLOSE_TIMEOUT) {
      txState = TX_IDLE;
    }
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
  String json;
  json.reserve(160 + trackMap.length());
  json = "{\"status\":\"";
  json += (dustDensity > dustThreshold) ? "Bahaya" : "Aman";
  json += "\",\"mode\":\"";
  json += namaModeJSON();
  json += "\",\"debu_value\":";
  json += String(dustDensity, 1);
  json += ",\"battery_voltage\":";
  json += String(batteryVoltage, 1);
  json += ",\"wait_start\":";
  json += (currentState == STATE_WAIT_START || currentState == STATE_COUNTDOWN) ? "1" : "0";
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

// ==========================================
// 11. PENERJEMAH PERINTAH DARI APLIKASI
// ==========================================
void prosesPerintah(const char *path) {
  if (strstr(path, "/mode?val=manual")) {
    currentState = STATE_MANUAL;
    aturMotor(0, 0);
    manualBergerak = false;
    jedaAktif = false;
    buzzerBeepSampai = 0;
    digitalWrite(BUZZER_PIN, LOW);
    lcdPesan("MODE: MANUAL", 1500);
  } else if (strstr(path, "/mode?val=idle")) {
    currentState = STATE_MANUAL;
    aturMotor(0, 0);
    manualBergerak = false;
    jedaAktif = false;
    buzzerBeepSampai = 0;
    digitalWrite(BUZZER_PIN, LOW);
    lcdPesan("MODE: IDLE", 1500);
  } else if (strstr(path, "/mode?val=auto")) {
    // Masuk ke mode auto: robot diam menunggu garis start sebelum melaju
    currentState = STATE_WAIT_START;
    aturMotor(0, 0);
    manualBergerak = false;
    jedaAktif = false;
    buzzerBeepSampai = 0;
    digitalWrite(BUZZER_PIN, LOW);
    lcdPesan("TUNGGU START...", 2000);
  } else if (strstr(path, "/cmd?act=")) {
    prosesGerak(strstr(path, "act=") + 4);
  } else if (strstr(path, "/emote?type=happy")) {
    mulaiEfek(EFEK_HAPPY, 2000);
  } else if (strstr(path, "/emote?type=angry")) {
    mulaiEfek(EFEK_ANGRY, 2000);
  } else if (strstr(path, "/emote?type=birthday")) {
    mulaiEfek(EFEK_BIRTHDAY, 11000); // Lagu Happy Birthday + LED Pesta Disco
    lcdPesan("HAPPY BIRTHDAY!", 11000);
  } else if (strstr(path, "/save-map?data=")) {
    simpanPetaDariURL(strstr(path, "data=") + 5);
    mulaiEfek(EFEK_MAP_DONE, 1500);
    lcdPesan("PETA DISIMPAN", 1500);
  } else if (strstr(path, "/dummy?dust=")) {
    float val = atof(strstr(path, "dust=") + 5);
    dummyDustOverride = val;
    if (dummyDustOverride >= 0) {
      dustDensity = dummyDustOverride;
      updateStatus();
    }
  }
  // Path lain ("/" atau "/status") = hanya meminta telemetri
}

void prosesGerak(const char *act) {
  // STOP selalu dihormati di mode apa pun (rem darurat / tombol Pause)
  if (strncmp(act, "stop", 4) == 0) {
    aturMotor(0, 0);
    manualBergerak = false;
    buzzerBeepSampai = 0;
    digitalWrite(BUZZER_PIN, LOW);
    if (currentState != STATE_MANUAL) {
      currentState = STATE_MANUAL;
      lcdPesan("STOP DARURAT", 1500);
    }
    return;
  }

  // Setiap perintah gerak dari D-Pad otomatis memastikan robot masuk ke STATE_MANUAL
  currentState = STATE_MANUAL;
  jedaAktif = false;

  int l = 0, r = 0;
  if (strncmp(act, "fwd", 3) == 0) {
    l = manualSpeed;
    r = manualSpeed;
  } else if (strncmp(act, "rev", 3) == 0) {
    l = -manualSpeed;
    r = -manualSpeed;
  } else if (strncmp(act, "sleft", 5) == 0 || strncmp(act, "left", 4) == 0) {
    l = 0;           // Belok kiri: roda kiri diam, roda kanan maju
    r = manualSpeed;
  } else if (strncmp(act, "sright", 6) == 0 || strncmp(act, "right", 5) == 0) {
    l = manualSpeed; // Belok kanan: roda kanan diam, roda kiri maju
    r = 0;
  } else {
    return;
  }

  if (isAirPoor) {
    return; // Udara bahaya: motor dikunci berhenti oleh loop()
  }
  aturMotor(l, r);
  manualBergerak = (l != 0 || r != 0);
}

void simpanPetaDariURL(const char *s) {
  // Decode URL (%2C -> ',') lalu simpan hanya karakter peta yang aman
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
// 12. FUNGSI LOGIKA PID LINE FOLLOWER
// ==========================================
void bacaSensorGaris() {
  sL = digitalRead(PIN_SENSOR_L);
  sC = digitalRead(PIN_SENSOR_C);
  sR = digitalRead(PIN_SENSOR_R);
}

void kalkulasiPID() {
  int error = 0;

  if (sL == 1 && sC == 1 && sR == 1)
    error = lastError;
  else if (sL == 0 && sC == 1 && sR == 1)
    error = -2; // Kiri
  else if (sL == 0 && sC == 0 && sR == 1)
    error = -1; // Agak Kiri
  else if (sL == 1 && sC == 0 && sR == 1)
    error = 0; // Tengah Sempurna
  else if (sL == 1 && sC == 0 && sR == 0)
    error = 1; // Agak Kanan
  else if (sL == 1 && sC == 1 && sR == 0)
    error = 2; // Kanan
  else
    error = lastError;

  float P = error;
  float D = error - lastError;
  float correction = (Kp * P) + (Kd * D);

  lastError = error;

  aturMotor(baseSpeed + correction, baseSpeed - correction);
}

void mulaiJeda(unsigned long durasi) {
  jedaAktif = true;
  jedaSampai = millis() + durasi;
}

// ==========================================
// 13. FUNGSI SENSOR KUALITAS UDARA
// ==========================================
void bacaKualitasUdara() {
  // Jika sedang dibypass via endpoint /dummy?dust= dari aplikasi mobile
  if (dummyDustOverride >= 0) {
    dustDensity = dummyDustOverride;
    return;
  }

  digitalWrite(DUST_LED, LOW);
  delayMicroseconds(280);
  int voMeasured = analogRead(DUST_AOUT);
  delayMicroseconds(40);
  digitalWrite(DUST_LED, HIGH);

  // Rumus datasheet GP2Y1010AU0F: mg/m3 = 0.17*V - 0.1  ->  x1000 = ug/m3
  // (sama dengan robot/test_komponen/test_4_debu_lcd)
  float calcVoltage = voMeasured * (3.3 / 4095.0);
  dustDensity = (0.17 * calcVoltage - 0.1) * 1000.0;
  if (dustDensity < 0)
    dustDensity = 0;

  // Untuk pembacaan Voltmeter eksternal diletakkan di sini nantinya
}

void updateStatus() {
  isAirPoor = (dustDensity > dustThreshold);

  if (efekAktif == EFEK_NONE) {
    terapkanLedStatus();
  }

  // Baris 1: status udara + mode (kecuali sedang menampilkan pesan event)
  if ((long)(millis() - lcdPesanSampai) >= 0) {
    if (isAirPoor) {
      lcdSet(0, "AIR: POOR!");
    } else {
      String s = "AIR:GOOD ";
      s += namaModeLCD();
      lcdSet(0, s);
    }
  }

  // Baris 2: debu + baterai
  String b = "D:";
  b += String(dustDensity, 1);
  b += " B:";
  b += String(batteryVoltage, 1);
  b += "V";
  lcdSet(1, b);
}

const char *namaModeJSON() {
  if (isAirPoor)
    return "Bahaya Asap";
  if (currentState == STATE_MANUAL)
    return manualBergerak ? "Remote Manual" : "Idle Standby";
  if (currentState == STATE_WAIT_START || currentState == STATE_COUNTDOWN)
    return "Menunggu Start";
  return "Garis";
}

const char *namaModeLCD() {
  if (!isFlutterConnected)
    return "SEARCH"; // Sedang mencari / menunggu koneksi aplikasi
  if (isAirPoor)
    return "BAHAYA";
  if (currentState == STATE_MANUAL)
    return manualBergerak ? "MANUAL" : "IDLE";
  if (currentState == STATE_WAIT_START)
    return "TUNGGU";
  if (currentState == STATE_COUNTDOWN)
    return "COUNTDN";
  return "AUTO";
}

// ==========================================
// 14. LED, BUZZER & LCD
// ==========================================
void setLED(bool r, bool g, bool b) {
  digitalWrite(LED_RED, r ? LED_NYALA : LED_MATI);
  digitalWrite(LED_GREEN, g ? LED_NYALA : LED_MATI);
  digitalWrite(LED_BLUE, b ? LED_NYALA : LED_MATI);
}

void terapkanLedStatus() {
  // Jika aplikasi Flutter belum terhubung, kedipkan LED Biru (mencari koneksi)
  if (!isFlutterConnected) {
    bool biruKedip = ((millis() / 300) % 2) == 0;
    setLED(false, false, biruKedip);
    return;
  }

  if (isAirPoor) {
    setLED(true, false, false); // Merah: udara buruk
  } else if (currentState == STATE_WAIT_START) {
    setLED(false, false, true); // Biru solid: menunggu garis start
  } else if (currentState == STATE_COUNTDOWN) {
    bool kuningKedip = ((millis() / 150) % 2) == 0;
    setLED(kuningKedip, kuningKedip, false); // Kuning berkedip cepat: hitung mundur
  } else {
    setLED(false, true, false); // Hijau: udara baik & Flutter terkoneksi
  }
}

void mulaiEfek(Efek e, unsigned long durasi) {
  efekAktif = e;
  efekMulai = millis();
  efekDurasi = durasi;
}

void updateEfek(unsigned long now) {
  if (efekAktif == EFEK_NONE || (long)(now - efekMulai) < 0) {
    return;
  }
  unsigned long t = now - efekMulai;
  if (t >= efekDurasi) {
    efekAktif = EFEK_NONE;
    digitalWrite(BUZZER_PIN, LOW);
    terapkanLedStatus();
    return;
  }

  switch (efekAktif) {
  case EFEK_BLINK_BIRU: {
    bool on = ((t / 100) % 2) == 0;
    setLED(false, false, on);
    break;
  }
  case EFEK_HAPPY: { // Gradasi hijau -> cyan -> biru + beep ritmik ringan
    uint8_t fase = (t / 200) % 3;
    setLED(false, fase != 2, fase != 0);
    digitalWrite(BUZZER_PIN, (t % 400) < 40 ? HIGH : LOW);
    break;
  }
  case EFEK_ANGRY: { // Merah kedip cepat + sirene kasar
    bool on = ((t / 80) % 2) == 0;
    setLED(on, false, false);
    digitalWrite(BUZZER_PIN, ((t / 150) % 2) == 0 ? HIGH : LOW);
    break;
  }
  case EFEK_MAP_DONE: { // Semua LED kedip + beep tiap detik
    bool on = ((t / 250) % 2) == 0;
    setLED(on, on, on);
    digitalWrite(BUZZER_PIN, (t % 1000) < 120 ? HIGH : LOW);
    break;
  }
  case EFEK_BIRTHDAY: {
    // 1. LED Pesta Warna-Warni Disco (Berganti tiap 180ms)
    uint8_t colorPhase = (t / 180) % 7;
    switch (colorPhase) {
      case 0: setLED(true, false, false); break; // Merah
      case 1: setLED(false, true, false); break; // Hijau
      case 2: setLED(false, false, true); break; // Biru
      case 3: setLED(true, true, false); break;  // Kuning
      case 4: setLED(false, true, true); break;  // Cyan
      case 5: setLED(true, false, true); break;  // Magenta
      case 6: setLED(true, true, true); break;   // Putih
    }

    // 2. Melodi Ritmik Happy Birthday (Non-blocking buzzer sequencer)
    bool bunyi = false;
    unsigned long modT = t % 11000;
    if (modT < 2600) {
      // Bait 1: Hap-py Birth-day to you
      bunyi = (modT < 220) ||
              (modT >= 280 && modT < 500) ||
              (modT >= 560 && modT < 1000) ||
              (modT >= 1080 && modT < 1520) ||
              (modT >= 1600 && modT < 2040) ||
              (modT >= 2120 && modT < 2550);
    } else if (modT < 5300) {
      // Bait 2: Hap-py Birth-day to you
      unsigned long subT = modT - 2600;
      bunyi = (subT >= 220 && subT < 440) ||
              (subT >= 500 && subT < 720) ||
              (subT >= 780 && subT < 1220) ||
              (subT >= 1300 && subT < 1740) ||
              (subT >= 1820 && subT < 2100) ||
              (subT >= 2180 && subT < 2650);
    } else if (modT < 8200) {
      // Bait 3: Hap-py Birth-day dear PureTogether
      unsigned long subT = modT - 5300;
      bunyi = (subT >= 200 && subT < 420) ||
              (subT >= 480 && subT < 700) ||
              (subT >= 760 && subT < 1200) ||
              (subT >= 1280 && subT < 1720) ||
              (subT >= 1800 && subT < 2200) ||
              (subT >= 2260 && subT < 2850);
    } else {
      // Bait 4: Hap-py Birth-day to you!
      unsigned long subT = modT - 8200;
      bunyi = (subT >= 200 && subT < 420) ||
              (subT >= 480 && subT < 700) ||
              (subT >= 760 && subT < 1200) ||
              (subT >= 1280 && subT < 1720) ||
              (subT >= 1800 && subT < 2150) ||
              (subT >= 2220 && subT < 2750);
    }
    digitalWrite(BUZZER_PIN, bunyi ? HIGH : LOW);
    break;
  }
  default:
    break;
  }
}

void lcdSet(uint8_t baris, const String &teks) {
  char buf[17];
  unsigned int n = teks.length();
  if (n > 16)
    n = 16;
  for (uint8_t i = 0; i < 16; i++) {
    buf[i] = (i < n) ? teks[i] : ' ';
  }
  buf[16] = 0;
  if (strcmp(buf, lcdIsi[baris]) != 0) {
    memcpy(lcdIsi[baris], buf, 17);
    lcdKotor[baris] = true;
  }
}

void lcdPesan(const String &teks, unsigned long durasi) {
  lcdSet(0, teks);
  lcdPesanSampai = millis() + durasi;
}

void updateLCD() {
  // I2C LCD lambat (~1ms/karakter). Jangan menulis saat sedang menerima
  // request atau mengirim balasan, dan tulis maksimal 1 baris per putaran.
  if (rxMode != RX_SCAN || txState == TX_SENDING) {
    return;
  }
  for (uint8_t i = 0; i < 2; i++) {
    if (lcdKotor[i]) {
      lcd.setCursor(0, i);
      lcd.print(lcdIsi[i]);
      lcdKotor[i] = false;
      return;
    }
  }
}

// ==========================================
// 15. KENDALI MOTOR DC
// ==========================================
void aturMotor(int pwmLeft, int pwmRight) {
  // 1. Nyalakan Motor Kanan (PB0 / PB1) lebih dahulu
  if (pwmRight > 0) {
    digitalWrite(MOTOR_R_IN2, LOW);
    digitalWrite(MOTOR_R_IN1, HIGH);
  } else if (pwmRight < 0) {
    digitalWrite(MOTOR_R_IN1, LOW);
    digitalWrite(MOTOR_R_IN2, HIGH);
  } else {
    digitalWrite(MOTOR_R_IN1, LOW);
    digitalWrite(MOTOR_R_IN2, LOW);
  }

  // 2. Nyalakan Motor Kiri (PA7 / PA6)
  if (pwmLeft > 0) {
    digitalWrite(MOTOR_L_IN2, LOW);
    digitalWrite(MOTOR_L_IN1, HIGH);
  } else if (pwmLeft < 0) {
    digitalWrite(MOTOR_L_IN1, LOW);
    digitalWrite(MOTOR_L_IN2, HIGH);
  } else {
    digitalWrite(MOTOR_L_IN1, LOW);
    digitalWrite(MOTOR_L_IN2, LOW);
  }
}
