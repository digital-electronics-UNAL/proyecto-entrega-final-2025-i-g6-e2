#include <TinyGPS++.h>
#include <SoftwareSerial.h>

TinyGPSPlus  gps;
SoftwareSerial ss(4, 3);   // RX, TX

unsigned long lastMsg = 0;         // para temporizar los mensajes

void setup() {
  Serial.begin(9600);
  ss.begin(9600);
  Serial.println(F("GPS Start (Arduino Uno)"));
}

void loop() {
  while (ss.available())
    gps.encode(ss.read());

  /* ── Muestra algo cada 2 s ─────────────────────────────────────── */
  if (millis() - lastMsg > 2000) {
    lastMsg = millis();

    if (gps.location.isValid() && gps.location.age() < 2000) {
      Serial.print(F("FIX ✓  Lat: ")); Serial.println(gps.location.lat(), 6);
      Serial.print(F("      Lon: "));  Serial.println(gps.location.lng(), 6);
      Serial.print(F("      Satélites: "));
      Serial.println(gps.satellites.isValid() ? gps.satellites.value() : 0);
    } else {
      Serial.print(F("Buscando…  Caracteres: "));
      Serial.print(gps.charsProcessed());
      Serial.print(F("  Satélites: "));
      Serial.println(gps.satellites.isValid() ? gps.satellites.value() : 0);
    }
    Serial.println();
  }
}
