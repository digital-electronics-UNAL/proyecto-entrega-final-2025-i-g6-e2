#include <LoRa.h>
#include "LoRaBoards.h"
#include <TinyGPS++.h>

// Pines GPS
#define GPS_RX_PIN 25  
#define GPS_TX_PIN -1

// Parámetros LoRa
#ifndef CONFIG_RADIO_FREQ
  #define CONFIG_RADIO_FREQ 433.0
#endif
#ifndef CONFIG_RADIO_OUTPUT_POWER
  #define CONFIG_RADIO_OUTPUT_POWER 17
#endif
#ifndef CONFIG_RADIO_BW
  #define CONFIG_RADIO_BW 125.0
#endif

TinyGPSPlus gps;
unsigned long lastNoDataPrint = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial);

  Serial.println();
  Serial.println(F("=== GPS + LoRa (no delay) ==="));

  // Inicializa LoRa y pantalla primero
  setupBoards();
  delay(1500);
#ifdef RADIO_TCXO_ENABLE
  pinMode(RADIO_TCXO_ENABLE, OUTPUT);
  digitalWrite(RADIO_TCXO_ENABLE, HIGH);
#endif
#ifdef RADIO_CTRL
  digitalWrite(RADIO_CTRL, LOW);
#endif

  LoRa.setPins(RADIO_CS_PIN, RADIO_RST_PIN, RADIO_DIO0_PIN);
  if (!LoRa.begin(CONFIG_RADIO_FREQ * 1e6)) {
    Serial.println(F("Error LoRa!")); while(1);
  }
  LoRa.setTxPower(CONFIG_RADIO_OUTPUT_POWER);
  LoRa.setSignalBandwidth(CONFIG_RADIO_BW * 1000);
  LoRa.setSpreadingFactor(10);
  LoRa.setPreambleLength(16);
  LoRa.setSyncWord(0xAB);
  LoRa.disableCrc();
  LoRa.disableInvertIQ();
  LoRa.setCodingRate4(7);

  Serial.println(F("LoRa listo"));

  // Re-inicia UART2 para GPS **al final** de setup
  Serial2.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  Serial.println(F("GPS OK en Serial2 @9600"));
}

void loop() {
  bool got = false;

  // 1) Captura todos los bytes del GPS sin bloquear
  while (Serial2.available()) {
    char c = Serial2.read();
    got = true;
    Serial.write(c);    // eco NMEA
    gps.encode(c);      // parser
  }

  // 2) Mensaje si no llega NMEA en 2 segundos
  if (!got && millis() - lastNoDataPrint > 2000) {
    Serial.println(F("[Sin datos GPS]"));
    lastNoDataPrint = millis();
  }

  // 3) Cuando hay fix nuevo, imprimo y envío por LoRa
  if (gps.location.isUpdated()) {
    double lat = gps.location.lat();
    double lng = gps.location.lng();

    Serial.println();
    Serial.print(F("Latitud : "));  Serial.println(lat, 6);
    Serial.print(F("Longitud: "));  Serial.println(lng, 6);
    Serial.println(F("----------------"));

    // Formateo lat,lon a 2 decimales
    char payload[32], buf[16];
    dtostrf(lat, 0, 2, buf); strcpy(payload, buf);
    strcat(payload, ",");
    dtostrf(lng, 0, 2, buf); strcat(payload, buf);

    Serial.print(F("LoRa→ ")); Serial.println(payload);

    LoRa.beginPacket();
      LoRa.print(payload);
    LoRa.endPacket();
  }

  // **sin delay**: quedamos libres para leer más NMEA
}
