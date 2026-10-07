#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN BUZZER
#define PIN_BUZZER PB15

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test Buzzer");
  delay(2000);
  lcd.clear();

  pinMode(PIN_BUZZER, OUTPUT);
}

void loop() {
  lcd.setCursor(0, 0);
  lcd.print("Buzzer ON       ");
  digitalWrite(PIN_BUZZER, HIGH);
  delay(1000);

  lcd.setCursor(0, 0);
  lcd.print("Buzzer OFF      ");
  digitalWrite(PIN_BUZZER, LOW);
  delay(1000);
}
