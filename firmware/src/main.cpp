#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include "config.h"

BearSSL::WiFiClientSecure wifiClient;
PubSubClient mqttClient(wifiClient);

String readFile(const char *path) {
  File f = LittleFS.open(path, "r");
  if (!f) {
    Serial.print("Failed to open: ");
    Serial.println(path);
    return "";
  }
  String content = f.readString();
  f.close();
  return content;
}

bool pumpRunning = false;
unsigned long pumpStartMillis = 0;
unsigned long lastVibrationMillis = 0;
String wifiSSID;
String wifiPassword;

bool loadWiFiConfig() {
  String conf = readFile(WIFI_CONFIG_PATH);
  if (conf.isEmpty()) return false;

  int newline = conf.indexOf('\n');
  if (newline < 0) return false;

  wifiSSID = conf.substring(0, newline);
  wifiPassword = conf.substring(newline + 1);
  wifiSSID.trim();
  wifiPassword.trim();
  return !wifiSSID.isEmpty();
}

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" connected");
}

void connectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to MQTT...");
    String clientId = String("pump-") + String(ESP.getChipId(), HEX);
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println(" connected");
    } else {
      Serial.print(" failed, rc=");
      Serial.println(mqttClient.state());
      delay(5000);
    }
  }
}

void publishDuration(unsigned long durationSeconds) {
  JsonDocument doc;
  doc["machine_id"] = MACHINE_ID;
  doc["vibration_duration_seconds"] = durationSeconds;

  char buffer[128];
  serializeJson(doc, buffer);

  if (mqttClient.publish(MQTT_TOPIC, buffer)) {
    Serial.print("Published: ");
    Serial.println(buffer);
  } else {
    Serial.println("Publish failed");
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(VIBRATION_PIN, INPUT);

  // Mount filesystem
  if (!LittleFS.begin()) {
    Serial.println("Failed to mount LittleFS");
    return;
  }

  // Load WiFi credentials
  if (!loadWiFiConfig()) {
    Serial.println("Missing wifi.conf. Upload filesystem first.");
    return;
  }

  // Load certificates from filesystem
  String rootCaPem = readFile(CERT_PATH_ROOT_CA);
  String deviceCertPem = readFile(CERT_PATH_DEVICE);
  String privateKeyPem = readFile(CERT_PATH_PRIVATE_KEY);

  if (rootCaPem.isEmpty() || deviceCertPem.isEmpty() || privateKeyPem.isEmpty()) {
    Serial.println("Missing certificate files. Upload filesystem first.");
    return;
  }

  BearSSL::X509List *rootCert = new BearSSL::X509List(rootCaPem.c_str());
  BearSSL::X509List *clientCert = new BearSSL::X509List(deviceCertPem.c_str());
  BearSSL::PrivateKey *clientKey = new BearSSL::PrivateKey(privateKeyPem.c_str());

  wifiClient.setTrustAnchors(rootCert);
  wifiClient.setClientRSACert(clientCert, clientKey);

  connectWiFi();

  // Sync time for TLS certificate validation
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("Syncing NTP");
  time_t now = time(nullptr);
  while (now < 8 * 3600 * 2) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println(" done");

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);

  Serial.println("Ready. Monitoring vibration sensor.");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }
  if (!mqttClient.connected()) {
    connectMQTT();
  }
  mqttClient.loop();

  int vibration = digitalRead(VIBRATION_PIN);
  unsigned long now = millis();

  if (vibration == HIGH) {
    lastVibrationMillis = now;

    if (!pumpRunning) {
      pumpRunning = true;
      pumpStartMillis = now;
      Serial.println("Pump started");
    }
  }

  if (pumpRunning && (now - lastVibrationMillis > DEBOUNCE_SECONDS * 1000)) {
    unsigned long durationSeconds = (lastVibrationMillis - pumpStartMillis) / 1000;
    Serial.print("Pump stopped. Duration: ");
    Serial.print(durationSeconds);
    Serial.println("s");

    publishDuration(durationSeconds);
    pumpRunning = false;
  }

  delay(100);
}
