// Copie este arquivo para "segredos.h" (na mesma pasta) e preencha com os seus dados.
// O segredos.h fica só no seu computador: ele não é enviado para o GitHub.

// Wi-Fi de casa
const char* WIFI_SSID = "SUA_REDE";
const char* WIFI_PASS = "SUA_SENHA";

// ---- Acesso pela internet (opcional) ----
// Deixe MQTT_HOST vazio ("") para usar só em casa, pelo Wi-Fi.
// Os mesmos dados (servidor, usuário, senha e DEVICE_ID) vão no app, em Conexão.
const char* MQTT_HOST = "";               // ex.: "abc123def.s1.eu.hivemq.cloud"
const int   MQTT_PORT = 8883;             // HiveMQ Cloud: 8883 (com TLS)
const char* MQTT_USER = "";
const char* MQTT_PASS = "";
const char* DEVICE_ID = "aquario-troque-isto";   // um nome só seu, sem espaços

// ---- Alertas no celular pelo app ntfy (opcional) ----
// Use um nome difícil de adivinhar: quem souber o nome vê os alertas.
const char* NTFY_TOPIC = "";              // ex.: "aquario-k7p3x9w2"
