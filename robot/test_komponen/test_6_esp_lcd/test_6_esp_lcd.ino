#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

HardwareSerial Serial2(PA3, PA2); // Mendeklarasikan objek Serial2 khusus
                                  // (RX=PA3, TX=PA2) untuk core STM32 resmi
// PIN ESP-01
// STM32 Bluepill Serial2 menggunakan PA2(TX) dan PA3(RX)
// Pastikan crossover pin: Serial2 TX(PA2) ke ESP RX, Serial2 RX(PA3) ke ESP TX

LiquidCrystal_I2C lcd(0x27, 16, 2);

void setup() {
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Test ESP-01 WiFi");
  delay(2000);
  lcd.clear();

  // Inisialisasi Serial untuk PC Debug
  Serial.begin(115200);

  // Inisialisasi Serial2 untuk ESP-01
  Serial2.begin(115200);
}

void loop() {
  lcd.setCursor(0, 0);
  lcd.print("Ping ESP (AT)...");

  // Kirim perintah AT
  Serial2.println("AT");

  unsigned long startWait = millis();
  String response = "";

  // Tunggu balasan dari ESP maksimal 2 detik
  while (millis() - startWait < 2000) {
    while (Serial2.available()) {
      char c = Serial2.read();
      response += c;
    }
    // Jika balasan sudah komplit (ada tulisan OK)
    if (response.indexOf("OK") != -1) {
      break;
    }
  }

  lcd.setCursor(0, 1);
  if (response.indexOf("OK") != -1) {
    lcd.print("ESP RESPON: OK! ");
  } else {
    lcd.print("ESP NO RESPON   ");
  }

  delay(3000);
}
