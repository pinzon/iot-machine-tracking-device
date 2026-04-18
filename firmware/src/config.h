#ifndef CONFIG_H
#define CONFIG_H

// WiFi credentials file path on LittleFS
const char *WIFI_CONFIG_PATH = "/wifi.conf";

// AWS IoT Core
const char *MQTT_HOST = "a35vmto8mnt83o-ats.iot.us-east-1.amazonaws.com";
const int MQTT_PORT = 8883;
const char *MQTT_TOPIC = "iot/machine/status";
const char *MACHINE_ID = "water-pump-01";

// Pin configuration
const int VIBRATION_PIN = D2;

// Debounce: seconds of no vibration before considering the pump stopped
const unsigned long DEBOUNCE_SECONDS = 10;

// Certificate file paths on LittleFS
const char *CERT_PATH_ROOT_CA = "/root-ca.pem";
const char *CERT_PATH_DEVICE = "/device.pem.crt";
const char *CERT_PATH_PRIVATE_KEY = "/private.pem.key";

#endif
