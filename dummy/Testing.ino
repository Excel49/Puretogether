/*
 * ROBOT "PureTogether" - DUMMY TESTING EDITION
 * Dipakai untuk tes Hardware secara lokal dengan HTML Controller
 */

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

HardwareSerial Serial2(PA3, PA2);

#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PB0 // Pengganti PB10 (pin kosong di sebelah PA7)
#define MOTOR_R_IN2 PB1 // Pengganti PB11 (pin kosong di sebelah PB0)

#define BUZZER_PIN PB15

#define LED_BLUE PA8
#define LED_GREEN PA9
#define LED_RED PA10

LiquidCrystal_I2C lcd(0x27, 16, 2);

float dummyDust = 0.0;
float batteryVoltage = 12.0;
int baseSpeed = 150;

void aturMotor(int pwmLeft, int pwmRight);
void sendATCommand(String cmd, int waitTime);

void sendATCommand(String cmd, int waitTime) {
  Serial2.println(cmd);
  delay(waitTime);
  while (Serial2.available()) {
    Serial2.read();
  }
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(115200);
  Serial2.setTimeout(50);

  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.print("Dummy Receiver");
  delay(1000);

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, HIGH);

  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);

  pinMode(PB10, INPUT); // Amankan pin rusak (PB10/PB11 & PA5/PA4)
  pinMode(PB11, INPUT);
  pinMode(PA5, INPUT);
  pinMode(PA4, INPUT);

  aturMotor(0, 0);

  // START ESP
  lcd.clear();
  lcd.print("Reset ESP...");
  sendATCommand("AT+RST", 4000);

  lcd.clear();
  lcd.print("Memulai ESP...");
  sendATCommand("AT", 1000);
  sendATCommand("AT+CWMODE=2", 1000);
  sendATCommand("AT+CWSAP=\"PureTogether\",\"12345678\",1,3", 2000);
  sendATCommand("AT+CIPMUX=1", 1000);
  sendATCommand("AT+CIPSERVER=1,8888", 2000);

  lcd.clear();
  lcd.print("Hotspot Ready!");
  delay(1000);
  updateLCD();
}

void updateLCD() {
  lcd.clear();
  lcd.setCursor(0, 0);
  if (dummyDust > 100) {
    lcd.print("AIR: POOR!");
  } else {
    lcd.print("AIR: GOOD");
  }
  lcd.setCursor(0, 1);
  lcd.print("Dust: ");
  lcd.print(dummyDust, 1);
}

void loop() {
  if (Serial2.available()) {
    if (Serial2.find("+IPD,")) {
      int connectionId = Serial2.parseInt();
      Serial2.read(); // buang koma
      int dataLen = Serial2.parseInt();
      Serial2.read(); // buang titik dua ':'

      // Baca tepat sejumlah dataLen (Ini yang mencegah nyangkut!)
      String incData = "";
      for (int i = 0; i < dataLen; i++) {
        long startT = millis();
        while (!Serial2.available()) {
          if (millis() - startT > 20)
            break; // timeout per char
        }
        if (Serial2.available()) {
          char c = Serial2.read();
          if (i < 50)
            incData += c; // Simpan max 50 char pertama buat cek "act=fwd"
        }
      }

      // PARSING DUMMY COMMANDS
      // Contoh gerak: /cmd?act=fwd
      if (incData.indexOf("act=fwd") >= 0)
        aturMotor(baseSpeed, baseSpeed);
      else if (incData.indexOf("act=rev") >= 0)
        aturMotor(-baseSpeed, -baseSpeed);
      else if (incData.indexOf("act=left") >= 0)
        aturMotor(-baseSpeed, baseSpeed); // Pivot Kiri
      else if (incData.indexOf("act=right") >= 0)
        aturMotor(baseSpeed, -baseSpeed); // Pivot Kanan
      else if (incData.indexOf("act=sleft") >= 0)
        aturMotor(0, baseSpeed); // Serong Kiri (L mati, R maju)
      else if (incData.indexOf("act=sright") >= 0)
        aturMotor(baseSpeed, 0); // Serong Kanan (L maju, R mati)
      else if (incData.indexOf("act=stop") >= 0)
        aturMotor(0, 0);

      // Contoh Buzzer: /dummy?buzz=1
      if (incData.indexOf("buzz=1") >= 0)
        digitalWrite(BUZZER_PIN, HIGH);
      else if (incData.indexOf("buzz=0") >= 0)
        digitalWrite(BUZZER_PIN, LOW);

      // Contoh LED: /dummy?led=red (Common Anode = LOW berarti Nyala)
      if (incData.indexOf("led=red") >= 0) {
        digitalWrite(LED_RED, LOW);
        digitalWrite(LED_GREEN, HIGH);
        digitalWrite(LED_BLUE, HIGH);
      } else if (incData.indexOf("led=green") >= 0) {
        digitalWrite(LED_RED, HIGH);
        digitalWrite(LED_GREEN, LOW);
        digitalWrite(LED_BLUE, HIGH);
      } else if (incData.indexOf("led=blue") >= 0) {
        digitalWrite(LED_RED, HIGH);
        digitalWrite(LED_GREEN, HIGH);
        digitalWrite(LED_BLUE, LOW);
      } else if (incData.indexOf("led=off") >= 0) {
        digitalWrite(LED_RED, HIGH);
        digitalWrite(LED_GREEN, HIGH);
        digitalWrite(LED_BLUE, HIGH);
      }

      // Contoh Sensor: /dummy?dust=145
      int dustIdx = incData.indexOf("dust=");
      if (dustIdx >= 0) {
        String dustStr = incData.substring(dustIdx + 5);
        int spaceIdx = dustStr.indexOf(' ');
        if (spaceIdx >= 0) {
          dustStr = dustStr.substring(0, spaceIdx);
        }
        dummyDust = dustStr.toFloat();
        updateLCD(); // Langsung perbarui LCD saat digeser
      }

      // JALUR KILAT (ZERO DELAY HACK):
      // Kita TIDAK PERLU membalas dengan header HTTP "200 OK" lalu menunggu
      // 150ms! Karena kita hanya butuh agar motor bergerak, kita akan langsung
      // MENCEKIK/MENUTUP Soket secara paksa. Modul transmisi turun gila-gilaan
      // dari 250 milidetik menjadi CUMA 5 milidetik!!!

      String closeCmd = "AT+CIPCLOSE=" + String(connectionId);
      Serial2.println(closeCmd);
      delay(5); // Cukup 5ms untuk bernafas
    }
  }
}

void aturMotor(int pwmLeft, int pwmRight) {
  // TES DIAGNOSA KERAS (HARDWARE TEST):
  // Kita abaikan sinyal kecepatan (PWM). Kita paksa buka arus sakelar 100%
  // menggunakan Digital! Jika dengan kodingan ini masih ada ban yang mati,
  // berarti KABEL jumper Anda ada yang putus di dalam!

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
}
