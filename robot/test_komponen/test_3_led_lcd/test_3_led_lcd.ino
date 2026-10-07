#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN LED RGB (Hanya menggunakan 1 modul LED utama sekarang)
#define LED_B PA8
#define LED_G PA9
#define LED_R PA10

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setLED(bool state) {
  digitalWrite(LED_B, state);
  digitalWrite(LED_G, state);
  digitalWrite(LED_R, state);
}

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test LED RGB");
  delay(2000);
  lcd.clear();

  pinMode(LED_B, OUTPUT);
  pinMode(LED_G, OUTPUT);
  pinMode(LED_R, OUTPUT);
}

void loop() {
  lcd.setCursor(0, 0);
  lcd.print("LED Merah Nyala ");
  digitalWrite(LED_R, HIGH);
  delay(1000);
  digitalWrite(LED_R, LOW);

  lcd.setCursor(0, 0);
  lcd.print("LED Hijau Nyala ");
  digitalWrite(LED_G, HIGH);
  delay(1000);
  digitalWrite(LED_G, LOW);

  lcd.setCursor(0, 0);
  lcd.print("LED Biru Nyala  ");
  digitalWrite(LED_B, HIGH);
  delay(1000);
  digitalWrite(LED_B, LOW);
}
