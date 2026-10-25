/*
 * Controladora de aquário marinho - ESP32
 *
 * 10 tomadas (relés), temperatura (DS18B20), pH e salinidade (via ADS1115),
 * reposição automática (ATO) com 2 boias, e uma API HTTP simples na rede local.
 * O app Aqua Light conversa com esta API.
 *
 * Bibliotecas (Gerenciador de Bibliotecas do Arduino IDE):
 *   - OneWire (Paul Stoffregen)
 *   - DallasTemperature (Miles Burton)
 *   - Adafruit ADS1X15
 * Placa: "ESP32 Dev Module" (pacote "esp32" da Espressif).
 *
 * SEGURANÇA: leia o LEIAME.md antes de ligar qualquer coisa na rede elétrica.
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <time.h>

// ======== AJUSTE AQUI ========
const char* WIFI_SSID = "SUA_REDE";
const char* WIFI_PASS = "SUA_SENHA";
const bool RELAY_ACTIVE_LOW = true;       // a maioria dos módulos de relé liga com nível baixo
const char* TIMEZONE = "<-03>3";          // Brasília
// =============================

enum Mode : uint8_t { M_OFF = 0, M_ON = 1, M_SCHEDULE = 2, M_AUTO = 3, M_DOSE = 4 };
enum OutletId { O_CIRC, O_SKIMMER, O_ATO, O_RECALQUE, O_HEATER, O_CHILLER, O_LIGHT, O_TPA_DRAIN, O_TPA_FILL, O_DOSER, NUM_OUTLETS };

const char* OUTLET_NAME[NUM_OUTLETS] = {
  "Bomba de circulação", "Skimmer", "Reposição (ATO)", "Recalque", "Aquecedor",
  "Resfriamento", "Luminária", "TPA: retirar água do sump", "TPA: repor água pronta", "Dosadora"
};
// GPIOs seguros do ESP32 (evitam os pinos de boot). 21/22 ficam para o I2C do ADS1115.
const int OUTLET_PIN[NUM_OUTLETS] = {16, 17, 18, 19, 23, 25, 26, 32, 33, 13};
// Modo de partida de cada tomada (só vale na primeira vez; depois vale o que o app salvar).
const Mode OUTLET_DEFAULT[NUM_OUTLETS] = {M_ON, M_ON, M_AUTO, M_ON, M_AUTO, M_AUTO, M_ON, M_AUTO, M_AUTO, M_OFF};

const int PIN_DS18B20 = 4;
const int PIN_FLOAT_SUMP = 27;       // boia do sump: fechada ao GND = nível baixo (precisa repor)
const int PIN_FLOAT_RESERVOIR = 14;  // boia do galão: fechada ao GND = galão vazio
const int PIN_FLOAT_SUMP_MIN = 15;   // boia de nível MÍNIMO do sump: fechada ao GND = não retirar mais água
const int PIN_SDA = 21, PIN_SCL = 22;

struct OutletCfg { uint8_t mode; uint16_t onMin; uint16_t offMin; uint16_t doseSec; };
OutletCfg cfg[NUM_OUTLETS];
bool outletOn[NUM_OUTLETS];

// Termostato e alarmes
float heaterOn = 25.0, heaterOff = 25.4, chillerOn = 26.5, chillerOff = 26.0;
float alarmLo = 23.0, alarmHi = 28.0;
// Reposição
uint16_t atoMaxSec = 120;
uint16_t atoCooldownSec = 600;
bool atoFault = false;
unsigned long atoStart = 0, atoLastStop = 0;
bool atoRunning = false;
// TPA (troca parcial de água): retira do sump e repõe água pronta
enum TpaState : uint8_t { T_IDLE = 0, T_DRAIN = 1, T_PAUSE = 2, T_FILL = 3 };
TpaState tpaState = T_IDLE;
float tpaLiters = 10, tpaDrainLpm = 5, tpaFillLpm = 5;   // litros e vazão das bombas (L/min)
unsigned long tpaStart = 0;
float tpaDrainedL = 0, tpaDrainTotalSec = 0, tpaFillTotalSec = 0;
String tpaMsg = "";
const unsigned long TPA_MAX_SEC = 1800;                  // nenhuma etapa passa de 30 min
// Calibrações
float phV7 = 0, phV4 = 0; bool phCal = false;
float ecK = 0; bool ecCal = false;

float temperature = NAN, ph = NAN, ec25 = NAN, salinity = NAN;
float phVolts = NAN, ecVolts = NAN;
bool adsOk = false;

WebServer server(80);
Preferences prefs;
OneWire oneWire(PIN_DS18B20);
DallasTemperature ds(&oneWire);
Adafruit_ADS1115 ads;

bool heaterState = false, chillerState = false;
unsigned long tempRequested = 0, lastSensors = 0, lastLogic = 0;
int lastDoseDay = -1;
unsigned long doseStart = 0;
bool dosing = false;

// ---------- utilidades ----------
void writeRelay(int i, bool on) {
  outletOn[i] = on;
  digitalWrite(OUTLET_PIN[i], (on ^ RELAY_ACTIVE_LOW) ? HIGH : LOW);
}

String jf(float v, int d = 2) { return isnan(v) ? String("null") : String(v, d); }

bool nowMinute(int &minuteOfDay, int &yday) {
  struct tm t;
  if (!getLocalTime(&t, 0)) return false;
  minuteOfDay = t.tm_hour * 60 + t.tm_min;
  yday = t.tm_yday;
  return true;
}

// ---------- preferências ----------
void loadConfig() {
  prefs.begin("aquario", false);
  for (int i = 0; i < NUM_OUTLETS; i++) {
    cfg[i].mode = prefs.getUChar(("m" + String(i)).c_str(), OUTLET_DEFAULT[i]);
    cfg[i].onMin = prefs.getUShort(("a" + String(i)).c_str(), 8 * 60);
    cfg[i].offMin = prefs.getUShort(("b" + String(i)).c_str(), 20 * 60);
    cfg[i].doseSec = prefs.getUShort(("s" + String(i)).c_str(), 10);
  }
  heaterOn = prefs.getFloat("hon", heaterOn);
  heaterOff = prefs.getFloat("hoff", heaterOff);
  chillerOn = prefs.getFloat("con", chillerOn);
  chillerOff = prefs.getFloat("coff", chillerOff);
  alarmLo = prefs.getFloat("alo", alarmLo);
  alarmHi = prefs.getFloat("ahi", alarmHi);
  tpaLiters = prefs.getFloat("tpaL", tpaLiters);
  tpaDrainLpm = prefs.getFloat("tpaD", tpaDrainLpm);
  tpaFillLpm = prefs.getFloat("tpaF", tpaFillLpm);
  phCal = prefs.getBool("phcal", false);
  phV7 = prefs.getFloat("phv7", 0);
  phV4 = prefs.getFloat("phv4", 0);
  ecCal = prefs.getBool("eccal", false);
  ecK = prefs.getFloat("eck", 0);
}

void saveOutlet(int i) {
  prefs.putUChar(("m" + String(i)).c_str(), cfg[i].mode);
  prefs.putUShort(("a" + String(i)).c_str(), cfg[i].onMin);
  prefs.putUShort(("b" + String(i)).c_str(), cfg[i].offMin);
  prefs.putUShort(("s" + String(i)).c_str(), cfg[i].doseSec);
}

// ---------- sensores ----------
float avgVolts(int ch) {
  float sum = 0;
  for (int k = 0; k < 10; k++) { sum += ads.computeVolts(ads.readADC_SingleEnded(ch)); delay(5); }
  return sum / 10.0;
}

void readSensors() {
  // Temperatura (sem travar o programa: pede, e lê na volta seguinte)
  if (millis() - tempRequested >= 1000) {
    float t = ds.getTempCByIndex(0);
    // -127 = sensor desconectado; 85 = valor de ligação, ainda sem leitura
    temperature = (t == DEVICE_DISCONNECTED_C || t == 85.0 || t < -20 || t > 60) ? NAN : t;
    ds.requestTemperatures();
    tempRequested = millis();
  }
  if (adsOk && millis() - lastSensors >= 3000) {
    lastSensors = millis();
    phVolts = avgVolts(0);
    ecVolts = avgVolts(1);
    if (phCal && phV7 != phV4) {
      float slope = (phV7 - phV4) / 3.0;   // volts por unidade de pH
      ph = 7.0 + (phV7 - phVolts) / slope;
      if (ph < 0 || ph > 14) ph = NAN;
    } else ph = NAN;
    if (ecCal && !isnan(temperature)) {
      float ec = ecK * ecVolts;                              // mS/cm na temperatura atual
      ec25 = ec / (1.0 + 0.02 * (temperature - 25.0));       // compensado para 25 °C
      salinity = ec25 / 53.0 * 35.0;                         // aproximação: 53 mS/cm ≈ 35 ppt
    } else { ec25 = NAN; salinity = NAN; }
  }
}

bool sumpLow() { return digitalRead(PIN_FLOAT_SUMP) == LOW; }
bool reservoirEmpty() { return digitalRead(PIN_FLOAT_RESERVOIR) == LOW; }
bool sumpMin() { return digitalRead(PIN_FLOAT_SUMP_MIN) == LOW; }
bool tpaActive() { return tpaState != T_IDLE; }

void tpaStop(const char* why) { tpaState = T_IDLE; tpaMsg = why; }

bool tpaBegin() {
  if (tpaActive()) return false;
  if (sumpMin()) { tpaMsg = "O sump já está no nível mínimo"; return false; }
  if (tpaLiters <= 0 || tpaDrainLpm <= 0 || tpaFillLpm <= 0) { tpaMsg = "Configure litros e vazões"; return false; }
  tpaDrainTotalSec = min((float)TPA_MAX_SEC, tpaLiters / tpaDrainLpm * 60.0f);
  tpaDrainedL = 0;
  atoRunning = false;
  tpaState = T_DRAIN; tpaStart = millis(); tpaMsg = "";
  return true;
}

void tpaGoPause(float drainedL, const char* why) {
  tpaDrainedL = drainedL; tpaState = T_PAUSE; tpaStart = millis();
  if (why) tpaMsg = why;
}

void tpaTick() {
  unsigned long el = (millis() - tpaStart) / 1000;
  switch (tpaState) {
    case T_DRAIN:
      if (sumpMin()) tpaGoPause(el * tpaDrainLpm / 60.0f, "Nível mínimo do sump atingido: repondo só o que saiu");
      else if (el >= tpaDrainTotalSec) tpaGoPause(el * tpaDrainLpm / 60.0f, nullptr);
      break;
    case T_PAUSE:
      if (el >= 3) {
        tpaFillTotalSec = min((float)TPA_MAX_SEC, tpaDrainedL / tpaFillLpm * 60.0f);
        if (tpaFillTotalSec < 1) tpaStop("Nada foi retirado");
        else { tpaState = T_FILL; tpaStart = millis(); }
      }
      break;
    case T_FILL:
      if (el >= tpaFillTotalSec) tpaStop("TPA concluída");
      break;
    default: break;
  }
}

// ---------- lógica das tomadas ----------
bool atoWanted() {
  unsigned long now = millis();
  if (atoFault || tpaActive()) { atoRunning = false; return false; }
  if (atoRunning) {
    if (!sumpLow() || reservoirEmpty()) { atoRunning = false; atoLastStop = now; return false; }
    if (now - atoStart > (unsigned long)atoMaxSec * 1000UL) {
      atoFault = true; atoRunning = false; atoLastStop = now;   // bomba rodou demais: trava
      return false;
    }
    return true;
  }
  if (sumpLow() && !reservoirEmpty() &&
      (atoLastStop == 0 || now - atoLastStop > (unsigned long)atoCooldownSec * 1000UL)) {
    atoRunning = true; atoStart = now; return true;
  }
  return false;
}

bool scheduleWanted(int i) {
  int m, d;
  if (!nowMinute(m, d)) return false;
  uint16_t a = cfg[i].onMin, b = cfg[i].offMin;
  if (a == b) return false;
  return a < b ? (m >= a && m < b) : (m >= a || m < b);
}

bool doseWanted(int i) {
  int m, d;
  if (dosing) {
    if (millis() - doseStart >= (unsigned long)cfg[i].doseSec * 1000UL) dosing = false;
    return dosing;
  }
  if (nowMinute(m, d) && m == cfg[i].onMin && d != lastDoseDay) {
    lastDoseDay = d; dosing = true; doseStart = millis(); return true;
  }
  return false;
}

void runLogic() {
  tpaTick();
  // Termostato com histerese
  if (!isnan(temperature)) {
    if (temperature < heaterOn) heaterState = true;
    else if (temperature >= heaterOff) heaterState = false;
    if (temperature > chillerOn) chillerState = true;
    else if (temperature <= chillerOff) chillerState = false;
  } else { heaterState = false; chillerState = false; }

  for (int i = 0; i < NUM_OUTLETS; i++) {
    bool want = false;
    if (i == O_TPA_DRAIN || i == O_TPA_FILL) {
      // Só a rotina da TPA liga estas duas bombas.
      want = (i == O_TPA_DRAIN) ? (tpaState == T_DRAIN) : (tpaState == T_FILL);
      if (want != outletOn[i]) writeRelay(i, want);
      continue;
    }
    switch (cfg[i].mode) {
      case M_ON: want = true; break;
      case M_OFF: want = false; break;
      case M_SCHEDULE: want = scheduleWanted(i); break;
      case M_DOSE: want = doseWanted(i); break;
      case M_AUTO:
        if (i == O_HEATER) want = heaterState;
        else if (i == O_CHILLER) want = chillerState;
        else if (i == O_ATO) want = atoWanted();
        else want = true;
        break;
    }
    // Proteções que valem mesmo no modo manual:
    if (i == O_HEATER && (isnan(temperature) || temperature >= alarmHi)) want = false;
    if (i == O_HEATER && (tpaState == T_DRAIN || tpaState == T_PAUSE)) want = false;  // sump baixo
    if (i == O_SKIMMER && tpaActive()) want = false;
    if (i == O_ATO && (atoFault || reservoirEmpty())) want = false;
    if (i == O_ATO && cfg[i].mode != M_AUTO && want) {
      // ATO ligada à mão também respeita o tempo máximo
      if (!atoRunning) { atoRunning = true; atoStart = millis(); }
      if (millis() - atoStart > (unsigned long)atoMaxSec * 1000UL) { atoFault = true; want = false; }
    }
    if (i == O_ATO && !want && cfg[i].mode != M_AUTO) atoRunning = false;
    if (want != outletOn[i]) writeRelay(i, want);
  }
}

// ---------- API ----------
String alarmsJson() {
  String s = "[";
  bool first = true;
  auto add = [&](const char* t) { if (!first) s += ","; s += "\""; s += t; s += "\""; first = false; };
  if (isnan(temperature)) add("Sensor de temperatura sem leitura");
  else if (temperature > alarmHi) add("Temperatura acima do limite");
  else if (temperature < alarmLo) add("Temperatura abaixo do limite");
  if (atoFault) add("Reposição travada: bomba rodou tempo demais");
  if (reservoirEmpty()) add("Galão de reposição vazio");
  s += "]";
  return s;
}

void sendStatus() {
  int m, d;
  bool timeOk = nowMinute(m, d);
  String j = "{";
  j += "\"temp\":" + jf(temperature) + ",\"ph\":" + jf(ph) + ",\"ec\":" + jf(ec25) +
       ",\"salinity\":" + jf(salinity, 1) + ",\"phVolts\":" + jf(phVolts, 3) + ",\"ecVolts\":" + jf(ecVolts, 3) +
       ",\"adsOk\":" + String(adsOk ? "true" : "false") + ",\"timeOk\":" + String(timeOk ? "true" : "false") +
       ",\"alarms\":" + alarmsJson() + ",\"outlets\":[";
  for (int i = 0; i < NUM_OUTLETS; i++) {
    if (i) j += ",";
    j += "{\"id\":" + String(i) + ",\"name\":\"" + OUTLET_NAME[i] + "\",\"on\":" + String(outletOn[i] ? "true" : "false") +
         ",\"mode\":" + String(cfg[i].mode) + ",\"onMin\":" + String(cfg[i].onMin) + ",\"offMin\":" + String(cfg[i].offMin) +
         ",\"doseSec\":" + String(cfg[i].doseSec) + "}";
  }
  j += "],\"ato\":{\"sumpLow\":" + String(sumpLow() ? "true" : "false") + ",\"reservoirEmpty\":" + String(reservoirEmpty() ? "true" : "false") +
       ",\"fault\":" + String(atoFault ? "true" : "false") + ",\"maxSec\":" + String(atoMaxSec) + "}";
  j += ",\"tpa\":{\"state\":" + String((int)tpaState) + ",\"elapsed\":" + String(tpaActive() ? (millis() - tpaStart) / 1000 : 0) +
       ",\"total\":" + String(tpaState == T_DRAIN ? tpaDrainTotalSec : (tpaState == T_FILL ? tpaFillTotalSec : 0), 0) +
       ",\"liters\":" + jf(tpaLiters, 1) + ",\"drainLpm\":" + jf(tpaDrainLpm, 1) + ",\"fillLpm\":" + jf(tpaFillLpm, 1) +
       ",\"minLevel\":" + String(sumpMin() ? "true" : "false") + ",\"msg\":\"" + tpaMsg + "\"}";
  j += ",\"thermo\":{\"heaterOn\":" + jf(heaterOn) + ",\"heaterOff\":" + jf(heaterOff) + ",\"chillerOn\":" + jf(chillerOn) +
       ",\"chillerOff\":" + jf(chillerOff) + ",\"alarmLo\":" + jf(alarmLo) + ",\"alarmHi\":" + jf(alarmHi) + "}";
  j += ",\"cal\":{\"ph\":" + String(phCal ? "true" : "false") + ",\"ec\":" + String(ecCal ? "true" : "false") + "}}";
  server.send(200, "application/json", j);
}

void handleSet() {
  if (!server.hasArg("id")) { server.send(400, "text/plain", "id?"); return; }
  int i = server.arg("id").toInt();
  if (i < 0 || i >= NUM_OUTLETS) { server.send(400, "text/plain", "id invalido"); return; }
  if (server.hasArg("mode")) { int m = server.arg("mode").toInt(); if (m >= 0 && m <= 4) cfg[i].mode = m; }
  if (server.hasArg("on")) cfg[i].onMin = constrain(server.arg("on").toInt(), 0, 1439);
  if (server.hasArg("off")) cfg[i].offMin = constrain(server.arg("off").toInt(), 0, 1439);
  if (server.hasArg("sec")) cfg[i].doseSec = constrain(server.arg("sec").toInt(), 1, 600);
  saveOutlet(i);
  if (i == O_DOSER) { lastDoseDay = -1; dosing = false; }
  runLogic();
  sendStatus();
}

void handleThermo() {
  auto get = [&](const char* k, float &v, const char* key) {
    if (server.hasArg(k)) { v = server.arg(k).toFloat(); prefs.putFloat(key, v); }
  };
  get("hon", heaterOn, "hon"); get("hoff", heaterOff, "hoff");
  get("con", chillerOn, "con"); get("coff", chillerOff, "coff");
  get("alo", alarmLo, "alo"); get("ahi", alarmHi, "ahi");
  sendStatus();
}

// /api/cal?type=ph&point=7|4   (com a sonda mergulhada na solução tampão)
// /api/cal?type=ec&ref=53.0    (com a sonda na solução de referência, em mS/cm)
void handleCal() {
  String type = server.arg("type");
  if (!adsOk) { server.send(400, "text/plain", "ADS1115 nao encontrado"); return; }
  if (type == "ph") {
    float v = avgVolts(0);
    if (server.arg("point") == "7") { phV7 = v; prefs.putFloat("phv7", v); }
    else { phV4 = v; prefs.putFloat("phv4", v); }
    phCal = phV7 > 0 && phV4 > 0 && phV7 != phV4;
    prefs.putBool("phcal", phCal);
  } else if (type == "ec" && !isnan(temperature)) {
    float ref = server.arg("ref").toFloat();
    float v = avgVolts(1);
    if (ref > 0 && v > 0.01) {
      ecK = ref * (1.0 + 0.02 * (temperature - 25.0)) / v;
      ecCal = true; prefs.putFloat("eck", ecK); prefs.putBool("eccal", true);
    }
  }
  sendStatus();
}

void handleTpaStart() { if (!tpaBegin() && tpaMsg == "") tpaMsg = "TPA já em andamento"; runLogic(); sendStatus(); }
void handleTpaStop() { if (tpaActive()) tpaStop("TPA interrompida"); runLogic(); sendStatus(); }
void handleTpaConfig() {
  if (!tpaActive()) {
    if (server.hasArg("liters")) { tpaLiters = constrain(server.arg("liters").toFloat(), 0.5f, 200.0f); prefs.putFloat("tpaL", tpaLiters); }
    if (server.hasArg("drainLpm")) { tpaDrainLpm = constrain(server.arg("drainLpm").toFloat(), 0.1f, 100.0f); prefs.putFloat("tpaD", tpaDrainLpm); }
    if (server.hasArg("fillLpm")) { tpaFillLpm = constrain(server.arg("fillLpm").toFloat(), 0.1f, 100.0f); prefs.putFloat("tpaF", tpaFillLpm); }
  }
  sendStatus();
}

void handleAtoReset() { atoFault = false; atoLastStop = millis(); sendStatus(); }

// ---------- setup / loop ----------
void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.setHostname("aquario");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  unsigned long t = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t < 20000) delay(250);
}

void setup() {
  // Primeiro de tudo: todas as tomadas desligadas.
  for (int i = 0; i < NUM_OUTLETS; i++) { pinMode(OUTLET_PIN[i], OUTPUT); writeRelay(i, false); }
  pinMode(PIN_FLOAT_SUMP, INPUT_PULLUP);
  pinMode(PIN_FLOAT_RESERVOIR, INPUT_PULLUP);
  pinMode(PIN_FLOAT_SUMP_MIN, INPUT_PULLUP);
  Serial.begin(115200);
  loadConfig();

  ds.begin();
  ds.setWaitForConversion(false);
  ds.requestTemperatures();
  tempRequested = millis();

  Wire.begin(PIN_SDA, PIN_SCL);
  adsOk = ads.begin();
  if (adsOk) ads.setGain(GAIN_ONE);

  connectWifi();
  configTzTime(TIMEZONE, "pool.ntp.org", "time.google.com");
  MDNS.begin("aquario");

  server.on("/api/status", sendStatus);
  server.on("/api/set", handleSet);
  server.on("/api/thermo", handleThermo);
  server.on("/api/cal", handleCal);
  server.on("/api/atoreset", handleAtoReset);
  server.on("/api/tpa/start", handleTpaStart);
  server.on("/api/tpa/stop", handleTpaStop);
  server.on("/api/tpa/config", handleTpaConfig);
  server.begin();
  Serial.print("Pronto. IP: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  server.handleClient();
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastTry = 0;
    if (millis() - lastTry > 15000) { lastTry = millis(); WiFi.reconnect(); }
  }
  readSensors();
  if (millis() - lastLogic >= 500) { lastLogic = millis(); runLogic(); }
}
