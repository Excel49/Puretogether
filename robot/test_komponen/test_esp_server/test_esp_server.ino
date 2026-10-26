    #include <Arduino.h>
    #include <LiquidCrystal_I2C.h>
    #include <Wire.h>

    // Definisi Serial2 untuk komunikasi STM32 ke ESP-01
    HardwareSerial Serial2(PA3, PA2);

    // Konfigurasi LCD
    LiquidCrystal_I2C lcd(0x27, 16, 2);

    void runCommandAndShow(String title, String cmd, int waitTime) {
    // Tampilkan perintah apa yang sedang dikirim
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(title);

    // Kirim perintah
    Serial2.println(cmd);

    // Baca respon selama waktu tunggu
    unsigned long start = millis();
    String response = "";
    while (millis() - start < waitTime) {
        while (Serial2.available()) {
        response += (char)Serial2.read();
        }
    }

    // Tampilkan hasil balasan dari ESP8266 ke baris ke-2 LCD
    lcd.setCursor(0, 1);
    if (response.indexOf("OK") != -1) {
        lcd.print("-> OKE");
    } else if (response.indexOf("ERROR") != -1) {
        lcd.print("-> ERROR");
    } else if (response.indexOf("no change") != -1) {
        lcd.print("-> NO CHANGE");
    } else {
        // Kalau dibales tulisan aneh/kosong
        if (response.length() > 0) {
        lcd.print("-> " + response.substring(0, 10)); // print sedikit awal teks
        } else {
        lcd.print("-> NO RESPON");
        }
    }

    // Jeda agar bisa dibaca manusia
    delay(1500);
    }

    void setup() {
    Wire.begin();
    lcd.init();
    lcd.backlight();

    // baud rate bawaan ESP-01
    Serial2.begin(115200);

    lcd.clear();
    lcd.print("Diagnosa ESP-01");
    delay(1500);

    // Jalankan rangkaian perintah untuk dicari tahu di mana biang keroknya!
    runCommandAndShow("1. Reset (RST)", "AT+RST", 4000);
    runCommandAndShow("2. Ping (AT)", "AT", 1000);
    runCommandAndShow("3. Mode (CWMODE)", "AT+CWMODE=2", 1500);
    runCommandAndShow("4. AP (CWSAP)", "AT+CWSAP=\"TEST\",\"1234\",1,4", 3000);
    runCommandAndShow("5. Multi (MUX)", "AT+CIPMUX=1", 1000);
    runCommandAndShow("6. Buka Port 80", "AT+CIPSERVER=1,80", 1500);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Diagnosa Selesai");
    }

    void loop() {
    // Tidak ada yang diulang
    }
