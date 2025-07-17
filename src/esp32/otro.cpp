#include <TinyGPS++.h>
#include <HardwareSerial.h>

constexpr uint8_t GPS_RX_PIN = 13;
constexpr uint8_t GPS_TX_PIN = 14;
TinyGPSPlus gps;
HardwareSerial GPSSerial(1);

unsigned long lastMsg = 0;      // para imprimir cada 2 s

void setup() {
  Serial.begin(115200);
  GPSSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  Serial.println(F("[GPS] Arrancando…"));
}

void loop() {
  while (GPSSerial.available())
    gps.encode(GPSSerial.read());

  /* → Cada 2 s reporto estado ← */
  if (millis() - lastMsg > 2000) {
    lastMsg = millis();

    if (gps.location.isValid()) {
      Serial.printf("FIX ✓  Lat: %.6f  Lon: %.6f  Satélites: %u\n",
                    gps.location.lat(), gps.location.lng(),
                    gps.satellites.value());
    } else {
      Serial.printf("Buscando…  Caracteres: %lu  Frases: %lu  Satélites: %u\n",
                    gps.charsProcessed(),
                    gps.sentencesWithFix(),
                    gps.satellites.isValid() ? gps.satellites.value() : 0);
    }
  }
}
