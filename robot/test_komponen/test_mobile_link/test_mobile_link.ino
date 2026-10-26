#include <Arduino.h>

// Definisi Serial Khusus ESP-01
HardwareSerial Serial2(PA3, PA2);

void sendATCommand(String cmd, int waitTime) {
  Serial2.println(cmd);
  delay(waitTime);
  while (Serial2.available()) {
    Serial2.read();
  }
}

// Fungsi pintar: Terus mengulang kirim perintah SAMPAI ESP menjawab "OK"
void waitForOK(String cmd, int waitTime) {
  while (true) {
    Serial2.println(cmd);
    unsigned long start = millis();
    String response = "";
    bool gotOK = false;

    while (millis() - start < waitTime) {
      while (Serial2.available()) {
        char c = (char)Serial2.read();
        response += c;
      }
    }

    if (response.indexOf("OK") != -1) {
      gotOK = true;
      break; // Berhasil! Keluar dari loop!
    }

    // Kalau GAGAL (Kabel putus / kendor / ESP mati):
    // Kedip lampu dengan SANGAT LAMBAT
    digitalWrite(PC13, LOW);
    delay(1000);
    digitalWrite(PC13, HIGH);
    delay(1000);
  }
}

void setup() {
  // LED Bawaan Bluepill (Pin PC13) untuk indikator
  // Modul Bluepill umumnya menggunakan Active-Low untuk nyala
  pinMode(PC13, OUTPUT);
  digitalWrite(PC13, HIGH); // Matikan dulu

  Serial2.begin(115200);

  // Tunggu arus stabil
  delay(3000);

  // Nyalakan LED sebentar tanda mulai booting
  digitalWrite(PC13, LOW);
  delay(500);
  digitalWrite(PC13, HIGH);

  sendATCommand("AT+RST", 5000);
  delay(3000);

  // CEK JALUR KABEL: Paksa Ping sampai berhasil!
  waitForOK("AT", 1000);
  waitForOK("AT+CWMODE=2", 1000);

  // UBAH SSID KE: PureTest
  waitForOK("AT+CWSAP_DEF=\"PureTest\",\"12345678\",1,3", 3000);
  waitForOK("AT+CWSAP=\"PureTest\",\"12345678\",1,3", 1000);

  waitForOK("AT+CIPMUX=1", 1000);
  waitForOK("AT+CIPSERVER=1,8888", 2000);

  // Kedip 3 kali tanda WiFi Siap!
  for (int i = 0; i < 3; i++) {
    digitalWrite(PC13, LOW);
    delay(200);
    digitalWrite(PC13, HIGH);
    delay(200);
  }
}

void loop() {
  if (Serial2.available()) {
    if (Serial2.find("+IPD,")) {
      // INI KUNCI VISUAL: Kalau Flutter berhasil nembak, LED Internal akan
      // berkedip cepat!
      digitalWrite(PC13, LOW);

      int connectionId = Serial2.parseInt();
      String incData = Serial2.readStringUntil('\n');

      long flushTimer = millis();
      while (millis() - flushTimer < 50) {
        if (Serial2.available())
          Serial2.read();
      }

      String jsonResponse =
          "{\"status\":\"LINK_OKE\", \"mode\":\"Testing\", \"debu_value\":0, "
          "\"battery_voltage\":99.9, \"map_data\":\"\"}";

      String httpResponse = "HTTP/1.1 200 OK\r\n";
      httpResponse += "Content-Type: application/json\r\n";
      httpResponse += "Connection: close\r\n";
      httpResponse += "Access-Control-Allow-Origin: *\r\n";
      httpResponse +=
          "Content-Length: " + String(jsonResponse.length()) + "\r\n\r\n";
      httpResponse += jsonResponse;

      String sendCmd = "AT+CIPSEND=";
      sendCmd += String(connectionId);
      sendCmd += ",";
      sendCmd += String(httpResponse.length());

      sendATCommand(sendCmd, 300);
      Serial2.print(httpResponse);
      delay(400);

      // Matikan kembali LED setelah Flutter dilayani
      digitalWrite(PC13, HIGH);
    }
  }
}
