#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

// PIN MOTOR DC (Sinkron dengan main.ino: Kiri PA7/PA6, Kanan PB0/PB1)
#define MOTOR_L_IN1 PA7
#define MOTOR_L_IN2 PA6
#define MOTOR_R_IN1 PB0
#define MOTOR_R_IN2 PB1

LiquidCrystal_I2C lcd(0x27, 16, 2);

void aturMotor(int pwmLeft, int pwmRight) {
  // Pada STM32F103C8T6, pin PB10 & PB11 bukan pin PWM default tanpa remap TIM2,
  // sehingga harus menggunakan digitalWrite(HIGH/LOW) agar motor menyala!
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
