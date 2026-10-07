#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN MOTOR DC
#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PA5
#define MOTOR_R_IN2 PA4

LiquidCrystal_I2C lcd(0x27, 16, 2);

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

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test Motor DC");
  delay(2000);
  lcd.clear();

  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);
}

void loop() {
  lcd.setCursor(0, 0);
  lcd.print("Maju Lurus     ");
  aturMotor(150, 150);
  delay(2000);

  lcd.setCursor(0, 0);
  lcd.print("Berhenti       ");
  aturMotor(0, 0);
  delay(1000);

  lcd.setCursor(0, 0);
  lcd.print("Mundur         ");
  aturMotor(-150, -150);
  delay(2000);

  lcd.setCursor(0, 0);
  lcd.print("Berhenti       ");
  aturMotor(0, 0);
  delay(1000);
}
