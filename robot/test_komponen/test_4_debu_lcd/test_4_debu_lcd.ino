#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN SENSOR DEBU SHARP
#define DUST_LED_PIN PA1
#define DUST_OUT_PIN PA0

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test Sensor Debu");
  delay(2000);
  lcd.clear();

  pinMode(DUST_LED_PIN, OUTPUT);
  pinMode(DUST_OUT_PIN, INPUT);
}

void loop() {
  // Logic pembacaan Sharp GP2Y1010AU0F
  digitalWrite(DUST_LED_PIN, LOW); // Nyalakan LED IR sensor
  delayMicroseconds(280);

  int voMeasured = analogRead(DUST_OUT_PIN);

  delayMicroseconds(40);
  digitalWrite(DUST_LED_PIN, HIGH); // Matikan LED IR sensor
  delayMicroseconds(9680);

  // Kalkulasi ke voltage lalu ke densitas debu
  float calcVoltage =
      voMeasured * (3.3 / 4095.0); // Asumsi resolusi ADC 12-bit (STM32)
  float dustDensity = (0.17 * calcVoltage - 0.1) * 1000;

  if (dustDensity < 0) {
    dustDensity = 0.0;
  }

  lcd.setCursor(0, 0);
  lcd.print("Debu: ");
  lcd.print(dustDensity, 1);
  lcd.print(" ug/m3 ");

  lcd.setCursor(0, 1);
  if (dustDensity > 100.0) {
    lcd.print("Udara: BAHAYA!  ");
  } else {
    lcd.print("Udara: AMAN     ");
  }

  delay(1000);
}
