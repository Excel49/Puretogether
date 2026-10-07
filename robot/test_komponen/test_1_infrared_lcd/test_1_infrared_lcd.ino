#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN SENSOR GARIS TCRT5000
#define PIN_SENSOR_L PB12
#define PIN_SENSOR_C PB13
#define PIN_SENSOR_R PB14

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test Infrared");
  delay(2000);
  lcd.clear();

  pinMode(PIN_SENSOR_L, INPUT);
  pinMode(PIN_SENSOR_C, INPUT);
  pinMode(PIN_SENSOR_R, INPUT);
}

void loop() {
  int sL = digitalRead(PIN_SENSOR_L);
  int sC = digitalRead(PIN_SENSOR_C);
  int sR = digitalRead(PIN_SENSOR_R);

  lcd.setCursor(0, 0);
  lcd.print("L:");
  lcd.print(sL);
  lcd.print(" C:");
  lcd.print(sC);
  lcd.print(" R:");
  lcd.print(sR);
  lcd.print("   ");

  lcd.setCursor(0, 1);
  if (sC == 1) {
    lcd.print("Garis Tengah!   ");
  } else {
    lcd.print("Mencari Garis...");
  }

  delay(100);
}
