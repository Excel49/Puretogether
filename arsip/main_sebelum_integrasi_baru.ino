/*
 * ROBOT "PureTogether" - PATROLI PENDETEKSI KUALITAS UDARA + MAPPING
 * Microcontroller: STM32F103C8T6 (Bluepill)
 * Komponen:
 * - Motor Driver MX1508 (PA8, PA9, PA10, PA11 -> Update PA4-7)
 * - 3x Sensor Garis TCRT5000 (PB12, PB13, PB14)
 * - Sensor Debu GP2Y1010AU0F (LED: PA1, AOUT: PA0)
 * - LCD 1602 I2C & INA226 (SDA: PB7, SCL: PB6)
 * - Buzzer (PB15), LED RGB 1 & 2
 * - Komunikasi Serial2 ke ESP-01 (TX: PA2, RX: PA3) - Mode Hotspot
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
#define MOTOR_R_IN1 PB10
#define MOTOR_R_IN2 PB11

#define PIN_SENSOR_L PB12
#define PIN_SENSOR_C PB13
#define PIN_SENSOR_R PB14

#define DUST_LED PA1
#define DUST_AOUT PA0

#define BUZZER_PIN PB15

#define LED_BLUE PA8
#define LED_GREEN PA9
#define LED_RED PA10

// ==========================================
// 2. VARIABEL SISTEM KUALITAS UDARA
// ==========================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

float dustDensity = 0.0;
float dustThreshold = 100.0; // Sesuaikan batas debu
float batteryVoltage = 12.0;

unsigned long previousMillisSensors = 0;
const long intervalSensors = 1000;
bool isAirPoor = false;

// ==========================================
// 3. VARIABEL STATE MACHINE & PID MAPPING
// ==========================================
float Kp = 15.0;
float Kd = 5.0;
int baseSpeed = 150; // Kecepatan ditingkatkan berdasarkan pengujian komponen
int lastError = 0;

int sL = 0, sC = 0, sR = 0;
bool isAllBlackProcessed = false;

// Sesi Mapping Track & Manual
enum State { STATE_IDLE, STATE_CALIBRATION, STATE_MANUAL };
State currentState =
    STATE_MANUAL; // UPDATE: Ubah default ke MANUAL agar diam saat menyala
unsigned long startStraightTime = 0;
String trackMap = "";
bool isStraight = true;
bool isCalibrationRequested = false; // Flag request dari aplikasi mobile

// Deklarasi Fungsi
void bacaSensorGaris();
void kalkulasiPID(bool isCalibration);
void logikaMapping(int error);
void aturMotor(int pwmLeft, int pwmRight);
void bacaKualitasUdara();
void updateStatus();
void sendATCommand(String cmd, int waitTime);

// ==========================================
// FUNGSI BANTUAN ESP-01 AT COMMAND
// ==========================================
void sendATCommand(String cmd, int waitTime) {
  Serial2.println(cmd);
  delay(waitTime);
  while (Serial2.available()) {
    Serial2
        .read(); // BUG FIX: Diubah ke Serial2.read() agar tidak Infinite Loop
  }
}

// ==========================================
// 4. SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  Serial2.begin(115200); // TX=PA2, RX=PA3
  Serial2.setTimeout(
      300); // SUPER PENTING: Jangan buang waktu nunggu string kepotong!

  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.print("PureTogether Bot");
  delay(1000);

  pinMode(PIN_SENSOR_L, INPUT);
  pinMode(PIN_SENSOR_C, INPUT);
  pinMode(PIN_SENSOR_R, INPUT);

  pinMode(DUST_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);

  // Matikan semua LED di awal (Asumsi LED Common Cathode: LOW = Mati. Jika
  // Common Anode, ganti jadi HIGH)
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);

  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);

  aturMotor(0, 0);

  // KONFIGURASI ESP8266 WIFI HOTSPOT (AP MODE)
  lcd.clear();
  lcd.print("Memulai ESP...");

  // RAHASIA UTAMA: Beri waktu 4 DETIK agar ESP-01 bangun penuh HANYA JIKA
  // Dinyalakan lewat Saklar Baterai
  delay(4000);

  // PING
  sendATCommand("AT", 1000);

  // MODE AP
  sendATCommand("AT+CWMODE=2", 1000);

  // BIKIN HOTSPOT (urutan asli)
  sendATCommand("AT+CWSAP=\"PureTogether\",\"12345678\",1,3", 2500);

  // MUX & BUKA PORT 8888 (Anti Hijack)
  sendATCommand("AT+CIPMUX=1", 1000);
  sendATCommand("AT+CIPSERVER=1,8888", 1500);

  lcd.clear();
  lcd.print("Hotspot Ready!");
  delay(1000);
}

// ==========================================
// 5. MAIN LOOP
// ==========================================
void loop() {
  unsigned long currentMillis = millis();

  // ----- PEMBACAAN KUALITAS UDARA (Tiap 1 Detik) -----
  if (currentMillis - previousMillisSensors >= intervalSensors) {
    previousMillisSensors = currentMillis;
    bacaKualitasUdara();
    updateStatus();
    // kirimDataKeESP() DIHAPUS karena sekarang kita menggunakan AT Web Server
    // (Pull API)
  }

  // ----- BACA KONEKSI DARI FLUTTER VIA HOTSPOT -----
  if (Serial2.available()) {
    if (Serial2.find("+IPD,")) {
      int connectionId = Serial2.parseInt();
      String incData = Serial2.readStringUntil('\n');

      // BUG FIX: Bersihkan sisa HTTP Headers di buffer (spaghetti request)
      // agar tidak merusak pembacaan paket/loop selanjutnya.
      long flushTimer = millis();
      while (millis() - flushTimer < 30) {
        while (Serial2.available()) {
          Serial2.read();
        }
      }

      // Deteksi aksi trigger start-map dari mobile
      if (incData.indexOf("/start-map") >= 0) {
        isCalibrationRequested = true;
        lcd.clear();
        lcd.print("Map Req Diterima");

        // Blink Biru
        for (int i = 0; i < 3; i++) {
          digitalWrite(LED_BLUE, HIGH);
          delay(100);
          digitalWrite(LED_BLUE, LOW);
          delay(100);
        }
      }
      // Deteksi aksi ubah mode (Auto / Manual)
      else if (incData.indexOf("/mode?val=manual") >= 0) {
        currentState = STATE_MANUAL;
        aturMotor(0, 0);
        lcd.clear();
        lcd.print("MANUAL MODE ON");
      } else if (incData.indexOf("/mode?val=auto") >= 0) {
        currentState = STATE_IDLE;
        lcd.clear();
        lcd.print("AUTO MODE ON");
      }

      // Jika mode Manual Aktif, izinkan input arah Remote Control
      if (currentState == STATE_MANUAL) {
        if (incData.indexOf("/cmd?act=fwd") >= 0)
          aturMotor(baseSpeed, baseSpeed);
        else if (incData.indexOf("/cmd?act=rev") >= 0)
          aturMotor(-baseSpeed, -baseSpeed);
        else if (incData.indexOf("/cmd?act=left") >= 0)
          aturMotor(-baseSpeed, baseSpeed);
        else if (incData.indexOf("/cmd?act=right") >= 0)
          aturMotor(baseSpeed, -baseSpeed);
        else if (incData.indexOf("/cmd?act=stop") >= 0)
          aturMotor(0, 0);
      }

      // Setiap ada request GET, Robot membalas dengan JSON
      String statusUdara = (dustDensity > 100.0) ? "Bahaya" : "Aman";

      // Tentukan string nama state saat ini
      String modeSekarang = "Garis";
      if (currentState == STATE_MANUAL)
        modeSekarang = "Remote Manual";
      else if (currentState == STATE_CALIBRATION)
        modeSekarang = "Mapping Track";

      String jsonResponse =
          "{\"status\":\"" + statusUdara + "\", \"mode\":\"" + modeSekarang +
          "\", \"debu_value\":" + String(dustDensity) +
          ", \"battery_voltage\":" + String(batteryVoltage, 1) +
          ", \"map_data\":\"" + trackMap + "\"}";

      String httpResponse = "HTTP/1.1 200 OK\r\n";
      httpResponse += "Content-Type: application/json\r\n";
      httpResponse += "Connection: close\r\n";
      httpResponse += "Access-Control-Allow-Origin: *\r\n";
      httpResponse +=
          "Content-Length: " + String(jsonResponse.length()) + "\r\n\r\n";
      httpResponse += jsonResponse;

      // Kirim panjang string packet ke ESP
      String sendCmd = "AT+CIPSEND=";
      sendCmd += String(connectionId);
      sendCmd += ",";
      sendCmd += String(httpResponse.length());

      sendATCommand(sendCmd, 300);
      Serial2.print(httpResponse);
      delay(400); // Waktu transit Wifi (Membiarkan OS Android menutup soketnya
                  // sendiri)
    }
  }

  // ----- KONDISI BAHAYA: BERHENTI -----
  if (isAirPoor) {
    aturMotor(0, 0);
    bool beepState = (currentMillis / 300) % 2;
    digitalWrite(BUZZER_PIN, beepState ? HIGH : LOW);
    return;
  }

  digitalWrite(BUZZER_PIN, LOW); // Matikan buzzer jika udara kembali bersih

  // ----- KONDISI NORMAL: LINE FOLLOWER & MAPPING -----
  bacaSensorGaris();

  // Cek Start/Finish Line (Semua sensor bertemu garis Hitam), HANYA JIKA BUKAN
  // MANUAL MODE
  if (sL == 0 && sC == 0 && sR == 0 && currentState != STATE_MANUAL) {
    if (!isAllBlackProcessed) {
      isAllBlackProcessed = true;
      aturMotor(0, 0);

      if (isCalibrationRequested) {
        // Hanya mulai kalibrasi JIKA SUDAH melewati garis 1, 1, 1
        currentState = STATE_CALIBRATION;
        isCalibrationRequested = false; // Reset flag
        trackMap = "";
        isStraight = true;
        startStraightTime = millis();
        lcd.clear();
        lcd.print("STATE: CALIBRATE");
        delay(1000);
      } else if (currentState == STATE_CALIBRATION) {
        // Jika sudah 1 putaran ketemu 1, 1, 1 lagi, berarti kalibrasi selesai
        if (isStraight) {
          unsigned long duration = millis() - startStraightTime;
          trackMap += "L" + String(duration) + ",";
        }
        // Kalibrasi usai, beralih ke navigasi normal aman (tanpa ngebut)
        currentState = STATE_IDLE;

        lcd.clear();
        lcd.print("MAPPING DONE");
        // Serial.println("Map Data: " + trackMap);
        delay(1500);
      } else {
        // STATE_IDLE (Line Follower Biasa), ketemu 1,1,1 biarkan lewat saja
        lcd.clear();
        lcd.print("CROSSING LINE");
        delay(300);
      }
    }
    // Jika masih nongkrong di garis finish, jalan pelan ke depan
    aturMotor(baseSpeed, baseSpeed);
  } else {
    isAllBlackProcessed = false;

    switch (currentState) {
    case STATE_IDLE:
      kalkulasiPID(false); // Berjalan normal dengan kecepatan aman
      break;
    case STATE_CALIBRATION:
      kalkulasiPID(true); // Sama seperti normal namun sembari merekam track
      break;
    case STATE_MANUAL:
      // Modul motor murni diambil alih oleh aplikasi flutter via HTTP, abaikan
      // sensor
      break;
    }
  }
}

// ==========================================
// 6. FUNGSI LOGIKA PID & MAPPING
// ==========================================
void bacaSensorGaris() {
  sL = digitalRead(PIN_SENSOR_L);
  sC = digitalRead(PIN_SENSOR_C);
  sR = digitalRead(PIN_SENSOR_R);
}

void kalkulasiPID(bool isCalibration) {
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

  // Catat durasi Mapping
  if (isCalibration)
    logikaMapping(error);

  float P = error;
  float D = error - lastError;
  float correction = (Kp * P) + (Kd * D);

  lastError = error;

  aturMotor(baseSpeed + correction, baseSpeed - correction);
}

void logikaMapping(int error) {
  if (error == 0 && !isStraight) {
    isStraight = true;
    startStraightTime = millis();
  } else if ((error >= 2 || error <= -2) && isStraight) {
    unsigned long duration = millis() - startStraightTime;
    trackMap += "L" + String(duration) + ",";

    if (error >= 2)
      trackMap += "K,";
    else if (error <= -2)
      trackMap += "Ki,";

    isStraight = false;
  }
}

// ==========================================
// 7. FUNGSI SENSOR KUALITAS UDARA
// ==========================================
void bacaKualitasUdara() {
  digitalWrite(DUST_LED, LOW);
  delayMicroseconds(280);
  int voMeasured = analogRead(DUST_AOUT);
  delayMicroseconds(40);
  digitalWrite(DUST_LED, HIGH);

  float calcVoltage = voMeasured * (3.3 / 1023.0);
  dustDensity = 170.0 * calcVoltage - 0.1;
  if (dustDensity < 0)
    dustDensity = 0;

  // Untuk pembacaan Voltmeter eksternal diletakkan di sini nantinya
}

void updateStatus() {
  lcd.clear();
  if (dustDensity > dustThreshold) {
    isAirPoor = true;
    digitalWrite(LED_RED, HIGH);
    digitalWrite(LED_GREEN, LOW);

    lcd.setCursor(0, 0);
    lcd.print("AIR: POOR!");
    lcd.setCursor(0, 1);
    lcd.print("Dust: ");
    lcd.print(dustDensity, 1);
  } else {
    isAirPoor = false;
    digitalWrite(LED_RED, LOW);
    digitalWrite(LED_GREEN, HIGH);

    lcd.setCursor(0, 0);
    lcd.print("AIR: GOOD");
    lcd.setCursor(0, 1);
    lcd.print("Bat: ");
    lcd.print(batteryVoltage, 1);
    lcd.print("V");
  }
}

// ==========================================
// 8. KENDALI MOTOR DC
// ==========================================
void aturMotor(int pwmLeft, int pwmRight) {
  pwmLeft = constrain(pwmLeft, -255, 255);
  pwmRight = constrain(pwmRight, -255, 255);

  if (pwmLeft >= 0) {
    analogWrite(MOTOR_L_IN1, pwmLeft);
    analogWrite(MOTOR_L_IN2, 0);
  } else {
    analogWrite(MOTOR_L_IN1, 0);
    analogWrite(MOTOR_L_IN2, -pwmLeft);
  }

  if (pwmRight >= 0) {
    analogWrite(MOTOR_R_IN1, pwmRight);
    analogWrite(MOTOR_R_IN2, 0);
  } else {
    analogWrite(MOTOR_R_IN1, 0);
    analogWrite(MOTOR_R_IN2, -pwmRight);
  }
}
