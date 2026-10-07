/*
 * ROBOT "PureTogether" - SCRIPT TESTING KOMPONEN
 * Gunakan Serial Monitor (baud rate 115200) untuk melihat status.
 * Script ini akan menguji komponen satu per satu secara berurutan.
 */

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// ==========================================
// 1. PENGATURAN PIN (Disamakan dengan main.ino)
// ==========================================
#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PA5
#define MOTOR_R_IN2 PA4

#define PIN_SENSOR_L PB12
#define PIN_SENSOR_C PB13
#define PIN_SENSOR_R PB14

#define DUST_LED PA1
#define DUST_AOUT PA0

#define BUZZER_PIN PB15

#define LED_BLUE PA8
#define LED_GREEN PA9
#define LED_RED PA10

// LCD Config
LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=====================================");
  Serial.println("Memulai Testing Komponen PureTogether");
  Serial.println("=====================================");

  // Inisialisasi I2C & LCD
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.print("Start Testing...");

  // Inisialisasi Pin
  pinMode(PIN_SENSOR_L, INPUT);
  pinMode(PIN_SENSOR_C, INPUT);
  pinMode(PIN_SENSOR_R, INPUT);

  pinMode(DUST_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);

  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);

  // Pastikan semua mati pada awalnya
  turunkanSemua();
  delay(2000);

  // Mulai Test Berurutan
  testLCD();
  testBuzzer();
  testLED();
  testMotor();

  Serial.println("=====================================");
  Serial.println("Testing Otomatis Selesai.");
  Serial.println("Masuk ke Loop: Test Sensor Garis & Debu");
  Serial.println("=====================================");
  lcd.clear();
  lcd.print("Test Sensor...");
}

void loop() {
  testSensorGaris();
  testSensorDebu();
  delay(500); // Update LCD tiap 500 ms
}

// ==========================================
// FUNGSI-FUNGSI TESTING
// ==========================================

void turunkanSemua() {
  digitalWrite(BUZZER_PIN, LOW);

  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);

  analogWrite(MOTOR_L_IN1, 0);
  analogWrite(MOTOR_L_IN2, 0);
  analogWrite(MOTOR_R_IN1, 0);
  analogWrite(MOTOR_R_IN2, 0);
}

void testLCD() {
  Serial.println("[TEST] Memeriksa LCD I2C...");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Test LCD I2C");
  lcd.setCursor(0, 1);
  lcd.print("Berhasil! OK.");
  delay(2000);
}

void testBuzzer() {
  Serial.println("[TEST] Memeriksa Buzzer...");
  lcd.clear();
  lcd.print("Test Buzzer");

  digitalWrite(BUZZER_PIN, HIGH);
  delay(500);
  digitalWrite(BUZZER_PIN, LOW);
  delay(500);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(500);
  digitalWrite(BUZZER_PIN, LOW);
  delay(1000);
}

void testLED() {
  Serial.println("[TEST] Memeriksa LED RGB...");
  lcd.clear();
  lcd.print("Test LED RGB");

  // LED 1
  Serial.println("  -> LED 1: Merah");
  digitalWrite(LED_RED, HIGH);
  delay(500);
  digitalWrite(LED_RED, LOW);

  Serial.println("  -> LED 1: Hijau");
  digitalWrite(LED_GREEN, HIGH);
  delay(500);
  digitalWrite(LED_GREEN, LOW);

  Serial.println("  -> LED 1: Biru");
  digitalWrite(LED_BLUE, HIGH);
  delay(500);
  digitalWrite(LED_BLUE, LOW);

  delay(1000);
}

void aturMotor(int pwmLeft, int pwmRight) {
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

void testMotor() {
  Serial.println("[TEST] Memeriksa Gerak Motor (Maju & Mundur)...");
  lcd.clear();
  lcd.print("Maju Lurus     ");

  aturMotor(150, 150);
  delay(2000);

  lcd.clear();
  lcd.print("Berhenti       ");
  aturMotor(0, 0);
  delay(1000);

  lcd.clear();
  lcd.print("Mundur         ");
  aturMotor(-150, -150);
  delay(2000);

  lcd.clear();
  lcd.print("Berhenti       ");
  aturMotor(0, 0);
  delay(1000);
}

void testSensorGaris() {
  int sL = digitalRead(PIN_SENSOR_L);
  int sC = digitalRead(PIN_SENSOR_C);
  int sR = digitalRead(PIN_SENSOR_R);

  lcd.setCursor(0, 0); // Baris 1
  lcd.print("Garis: L");
  lcd.print(sL);
  lcd.print(" C");
  lcd.print(sC);
  lcd.print(" R");
  lcd.print(sR);
  lcd.print("   "); // Spasi kosong untuk clear sisa teks
}

void testSensorDebu() {
  digitalWrite(DUST_LED, LOW);
  delayMicroseconds(280);
  int voMeasured = analogRead(DUST_AOUT);
  delayMicroseconds(40);
  digitalWrite(DUST_LED, HIGH);

  float calcVoltage = voMeasured * (3.3 / 1023.0);
  float dustDensity = 170.0 * calcVoltage - 0.1;
  if (dustDensity < 0)
    dustDensity = 0;

  lcd.setCursor(0, 1); // Baris 2
  lcd.print("Debu: ");
  lcd.print(dustDensity, 1);
  lcd.print("ug/m3   ");
}
