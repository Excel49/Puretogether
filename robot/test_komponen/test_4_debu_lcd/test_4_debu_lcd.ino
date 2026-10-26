#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN SENSOR DEBU SHARP GP2Y1010AU0F
#define DUST_LED_PIN PA1
#define DUST_OUT_PIN PA0

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Serial.begin(115200); // Opsional: pantau via Serial Monitor
  Wire.begin();

  // Wajib untuk STM32: set resolusi ADC ke 12-bit (0..4095)
  analogReadResolution(12);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test Sensor Debu");
  lcd.setCursor(0, 1);
  lcd.print("Init 12-Bit ADC ");
  delay(1500);
  lcd.clear();

  pinMode(DUST_LED_PIN, OUTPUT);
  pinMode(DUST_OUT_PIN, INPUT);
  digitalWrite(DUST_LED_PIN, HIGH); // LED IR aktif LOW -> matikan dulu saat standby
}

void loop() {
  // Ambil rata-rata 10 sampel agar pembacaan stabil dan bebas lonjakan noise
  float totalVoltage = 0.0;
  for (int i = 0; i < 10; i++) {
    digitalWrite(DUST_LED_PIN, LOW); // Nyalakan LED IR sensor
    delayMicroseconds(280);

    int voMeasured = analogRead(DUST_OUT_PIN); // Membaca skala penuh 12-bit (0..4095)

    delayMicroseconds(40);
    digitalWrite(DUST_LED_PIN, HIGH); // Matikan LED IR sensor
    delayMicroseconds(9680);

    totalVoltage += voMeasured * (3.3 / 4095.0);
  }
  float calcVoltage = totalVoltage / 10.0;

  // Rumus standar GP2Y1010AU0F: mg/m3 = 0.17 * V - 0.1 -> dikali 1000 jadi ug/m3
  float dustDensity = (0.17 * calcVoltage - 0.1) * 1000.0;
  if (dustDensity < 0) {
    dustDensity = 0.0;
  }

  // Tampilkan ke LCD 1602
  lcd.setCursor(0, 0);
  lcd.print("Debu: ");
  lcd.print(dustDensity, 1);
  lcd.print(" ug/m3   ");

  lcd.setCursor(0, 1);
  if (dustDensity > 100.0) {
    lcd.print("Udara: BAHAYA!  ");
  } else {
    lcd.print("Udara: AMAN     ");
  }

  // Debug ke Serial Monitor
  Serial.print("Tegangan: ");
  Serial.print(calcVoltage, 2);
  Serial.print(" V | Debu: ");
  Serial.print(dustDensity, 1);
  Serial.println(" ug/m3");

  delay(500);
}
