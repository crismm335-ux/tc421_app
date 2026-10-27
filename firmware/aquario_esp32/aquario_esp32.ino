/*
 * Controladora de aquário marinho - ESP32
 *
 * 9 tomadas (relés), temperatura (DS18B20), pH e salinidade (via ADS1115),
 * reposição automática (ATO) com 2 boias, TPA automática, dosadora de 4 canais
 * e uma API HTTP simples na rede local.
 * O app Aqua Light conversa com esta API.
 *
 * Bibliotecas (Gerenciador de Bibliotecas do Arduino IDE):
 *   - OneWire (Paul Stoffregen)
 *   - DallasTemperature (Miles Burton)
 *   - Adafruit ADS1X15
 *   - PubSubClient (Nick O'Leary)  -> acesso pela internet
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
#include <WiFiClientSecure.h>
#include <WiFiUdp.h>
#include <HTTPClient.h>
#include <PubSubClient.h>
#include <map>

// ======== AJUSTE AQUI ========
// Senhas (Wi-Fi, servidor da internet, alertas) ficam no arquivo segredos.h,
// na mesma pasta. Copie segredos_exemplo.h para segredos.h e preencha.
// O segredos.h não vai para o GitHub (está no .gitignore), então o repositório
// pode ser público sem expor suas senhas.
#if __has_include("segredos.h")
#include "segredos.h"
#else
#include "segredos_exemplo.h"
#endif

const bool RELAY_ACTIVE_LOW = true;       // a maioria dos módulos de relé liga com nível baixo
const char* TIMEZONE = "<-03>3";          // Brasília
const bool DOSER_ACTIVE_HIGH = true;      // módulo MOSFET das bombas dosadoras liga com nível alto
// =============================

enum Mode : uint8_t { M_OFF = 0, M_ON = 1, M_SCHEDULE = 2, M_AUTO = 3, M_DOSE = 4 };
enum OutletId { O_CIRC, O_SKIMMER, O_ATO, O_RECALQUE, O_HEATER, O_CHILLER, O_LIGHT, O_TPA_DRAIN, O_TPA_FILL, NUM_OUTLETS };

const char* OUTLET_NAME[NUM_OUTLETS] = {
  "Bomba de circulação", "Skimmer", "Reposição (ATO)", "Bomba de recalque", "Aquecedor",
  "Resfriamento", "Luminária", "TPA: retirar água do sump", "TPA: repor água nova"
};
// GPIOs seguros do ESP32 (evitam os pinos de boot). 21/22 ficam para o I2C do ADS1115.
const int OUTLET_PIN[NUM_OUTLETS] = {16, 17, 18, 19, 23, 25, 26, 32, 33};
// Modo de partida de cada tomada (só vale na primeira vez; depois vale o que o app salvar).
const Mode OUTLET_DEFAULT[NUM_OUTLETS] = {M_ON, M_ON, M_AUTO, M_ON, M_AUTO, M_AUTO, M_ON, M_AUTO, M_AUTO};

// Dosadora: 4 bombas peristálticas (12 V) ligadas por um módulo MOSFET de 4 canais.
const int DOSE_CH = 4;
const int DOSE_PIN[DOSE_CH] = {13, 15, 2, 5};
const char* DOSE_DEFAULT_NAME[DOSE_CH] = {"Alcalinidade (KH)", "Cálcio", "Magnésio", "Elementos traço"};
const unsigned long DOSE_MAX_MS = 300000UL;              // nenhuma dose passa de 5 minutos
const unsigned long DOSE_CALIB_MS = 60000UL;             // calibração: 1 minuto ligada

const int PIN_DS18B20 = 4;
const int PIN_FLOAT_SUMP = 27;       // boia do sump: fechada ao GND = nível baixo (precisa repor)
const int PIN_FLOAT_RESERVOIR = 14;  // boia do galão: fechada ao GND = galão vazio
const int PIN_FLOAT_SUMP_MIN = 34;   // boia de nível MÍNIMO do sump: fechada ao GND = não retirar mais água
                                     // (o pino 34 não tem resistor interno: use 10 kΩ entre o 34 e o 3,3 V)
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

// ---------- dosadora ----------
struct DoseCfg {
  String name;
  bool en;
  float mlDay;        // ml por dia
  uint8_t doses;      // doses por dia (1 a 24)
  uint16_t startMin;  // primeira dose (minuto do dia)
  uint16_t endMin;    // última dose; igual ao início = espalhar no dia todo
  float rate;         // ml por minuto (calibração)
  float capMl;        // tamanho do recipiente
  float leftMl;       // quanto ainda tem no recipiente
};
DoseCfg dose[DOSE_CH];
float doseToday[DOSE_CH];        // ml dosados hoje
float dosePending[DOSE_CH];      // ml esperando na fila
uint32_t doseDoneMask[DOSE_CH];  // doses do dia já feitas (1 bit por dose)
bool doseEmpty[DOSE_CH];         // dose pulada por falta de líquido
int doseDay = -1;
int doseRunning = -1;            // canal ligado agora (-1 = nenhum)
bool doseCalib = false;          // a dose atual é calibração (não conta no recipiente)
unsigned long doseStartMs = 0, doseRunMs = 0;
float doseRunMl = 0;
String doseMsg = "";

// ---------- pedidos (vindos do Wi-Fi de casa ou da internet) ----------
bool viaMqtt = false;                    // o pedido atual veio pela internet?
std::map<String, String> mqttArgs;      // argumentos do pedido que veio pela internet
bool reqHas(const char* k) { return viaMqtt ? mqttArgs.count(String(k)) > 0 : server.hasArg(k); }
String reqArg(const char* k) {
  if (!viaMqtt) return server.arg(k);
  auto it = mqttArgs.find(String(k));
  return it == mqttArgs.end() ? String("") : it->second;
}
void replyError(const char* msg) { if (!viaMqtt) server.send(400, "text/plain", msg); }

// ---------- utilidades ----------
void writeRelay(int i, bool on) {
  outletOn[i] = on;
  digitalWrite(OUTLET_PIN[i], (on ^ RELAY_ACTIVE_LOW) ? HIGH : LOW);
}

void writeDoser(int c, bool on) {
  digitalWrite(DOSE_PIN[c], (on == DOSER_ACTIVE_HIGH) ? HIGH : LOW);
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
  for (int c = 0; c < DOSE_CH; c++) {
    String k = "d" + String(c);
    dose[c].name = prefs.getString((k + "n").c_str(), DOSE_DEFAULT_NAME[c]);
    dose[c].en = prefs.getBool((k + "e").c_str(), false);
    dose[c].mlDay = prefs.getFloat((k + "m").c_str(), 10);
    dose[c].doses = prefs.getUChar((k + "k").c_str(), 4);
    dose[c].startMin = prefs.getUShort((k + "s").c_str(), 8 * 60);
    dose[c].endMin = prefs.getUShort((k + "f").c_str(), 20 * 60);
    dose[c].rate = prefs.getFloat((k + "r").c_str(), 60);
    dose[c].capMl = prefs.getFloat((k + "c").c_str(), 1000);
    dose[c].leftMl = prefs.getFloat((k + "l").c_str(), dose[c].capMl);
    doseToday[c] = 0; dosePending[c] = 0; doseDoneMask[c] = 0; doseEmpty[c] = false;
  }
}

void saveDose(int c) {
  String k = "d" + String(c);
  prefs.putString((k + "n").c_str(), dose[c].name);
  prefs.putBool((k + "e").c_str(), dose[c].en);
  prefs.putFloat((k + "m").c_str(), dose[c].mlDay);
  prefs.putUChar((k + "k").c_str(), dose[c].doses);
  prefs.putUShort((k + "s").c_str(), dose[c].startMin);
  prefs.putUShort((k + "f").c_str(), dose[c].endMin);
  prefs.putFloat((k + "r").c_str(), dose[c].rate);
  prefs.putFloat((k + "c").c_str(), dose[c].capMl);
  prefs.putFloat((k + "l").c_str(), dose[c].leftMl);
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

// ---------- dosadora: agenda e fila ----------
// Minuto do dia da dose k (0..doses-1) do canal c.
int doseSlot(int c, int k) {
  int n = max(1, (int)dose[c].doses);
  int a = dose[c].startMin, b = dose[c].endMin;
  if (a == b) return (a + k * 1440 / n) % 1440;           // espalha nas 24 h
  int span = (b - a + 1440) % 1440;
  if (n == 1) return a;
  return (a + (int)((long)k * span / (n - 1))) % 1440;     // da primeira à última
}

// Próxima dose de hoje que ainda não aconteceu (-1 = nenhuma).
int doseNext(int c, int m) {
  if (!dose[c].en) return -1;
  int best = -1;
  for (int k = 0; k < dose[c].doses; k++) {
    if (doseDoneMask[c] & (1UL << k)) continue;
    int t = doseSlot(c, k);
    if (t >= m && (best < 0 || t < best)) best = t;
  }
  return best;
}

void doseStop(bool count) {
  if (doseRunning < 0) return;
  int c = doseRunning;
  writeDoser(c, false);
  if (!doseCalib && count) {
    unsigned long el = millis() - doseStartMs;
    float done = el >= doseRunMs ? doseRunMl : doseRunMl * el / (float)doseRunMs;
    doseToday[c] += done;
    dose[c].leftMl = max(0.0f, dose[c].leftMl - done);
    prefs.putFloat(("d" + String(c) + "l").c_str(), dose[c].leftMl);
  }
  doseRunning = -1; doseCalib = false;
}

void doseTick() {
  int m, d;
  if (nowMinute(m, d)) {
    if (d != doseDay) {                          // virou o dia
      doseDay = d;
      for (int c = 0; c < DOSE_CH; c++) { doseToday[c] = 0; doseDoneMask[c] = 0; }
    }
    for (int c = 0; c < DOSE_CH; c++) {
      if (!dose[c].en || dose[c].mlDay <= 0) continue;
      for (int k = 0; k < dose[c].doses; k++) {
        if (doseDoneMask[c] & (1UL << k)) continue;
        int t = doseSlot(c, k);
        if (m < t) continue;                     // ainda não chegou a hora
        doseDoneMask[c] |= (1UL << k);
        // Só doseia se estiver na hora (5 min de tolerância). Se passou disso
        // (ex.: ESP32 ligado mais tarde), a dose é pulada para não dobrar.
        if (m - t < 5) dosePending[c] += dose[c].mlDay / dose[c].doses;
      }
    }
  }
  // Uma bomba por vez, e nunca durante a TPA.
  if (doseRunning >= 0) {
    if (millis() - doseStartMs >= doseRunMs) doseStop(true);
    return;
  }
  if (tpaActive()) return;
  for (int c = 0; c < DOSE_CH; c++) {
    if (dosePending[c] < 0.05f) continue;
    float ml = dosePending[c];
    dosePending[c] = 0;
    if (dose[c].rate <= 0) { doseMsg = "Calibre o canal " + String(c + 1); continue; }
    if (dose[c].leftMl < ml) { doseEmpty[c] = true; doseMsg = "Recipiente de " + dose[c].name + " vazio: dose pulada"; continue; }
    doseEmpty[c] = false;
    doseRunMl = ml;
    doseRunMs = min(DOSE_MAX_MS, (unsigned long)(ml / dose[c].rate * 60000.0f));
    doseRunning = c; doseCalib = false; doseStartMs = millis();
    writeDoser(c, true);
    return;
  }
}

void runLogic() {
  tpaTick();
  doseTick();
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
      case M_DOSE: want = false; break;   // modo antigo: a dosadora agora tem a própria aba
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
  for (int c = 0; c < DOSE_CH; c++) {
    if (!dose[c].en) continue;
    String t = "";
    if (doseEmpty[c]) t = "Dosadora: recipiente de " + dose[c].name + " vazio";
    else if (dose[c].mlDay > 0 && dose[c].leftMl < dose[c].mlDay * 3) t = "Dosadora: " + dose[c].name + " acaba em menos de 3 dias";
    if (t.length()) add(t.c_str());
  }
  s += "]";
  return s;
}

String statusJson() {
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
  j += ",\"cal\":{\"ph\":" + String(phCal ? "true" : "false") + ",\"ec\":" + String(ecCal ? "true" : "false") + "}";
  j += ",\"doser\":" + doserJson(m, timeOk);
  j += ",\"remote\":" + String(mqttOk() ? "true" : "false") + "}";
  return j;
}

void sendStatus() {
  if (viaMqtt) { mqttPublishStatus(true); return; }
  server.send(200, "application/json", statusJson());
}

String jsonText(String t) { t.replace("\\", "/"); t.replace("\"", "'"); return "\"" + t + "\""; }

String doserJson(int m, bool timeOk) {
  String j = "{\"running\":" + String(doseRunning) + ",\"calib\":" + String(doseCalib ? "true" : "false") +
             ",\"elapsed\":" + String(doseRunning >= 0 ? (millis() - doseStartMs) / 1000 : 0) +
             ",\"total\":" + String(doseRunning >= 0 ? doseRunMs / 1000 : 0) +
             ",\"msg\":" + jsonText(doseMsg) + ",\"ch\":[";
  for (int c = 0; c < DOSE_CH; c++) {
    if (c) j += ",";
    j += "{\"name\":" + jsonText(dose[c].name) + ",\"en\":" + String(dose[c].en ? "true" : "false") +
         ",\"mlDay\":" + jf(dose[c].mlDay, 1) + ",\"doses\":" + String(dose[c].doses) +
         ",\"start\":" + String(dose[c].startMin) + ",\"end\":" + String(dose[c].endMin) +
         ",\"rate\":" + jf(dose[c].rate, 1) + ",\"cap\":" + jf(dose[c].capMl, 0) + ",\"left\":" + jf(dose[c].leftMl, 1) +
         ",\"today\":" + jf(doseToday[c], 1) + ",\"pending\":" + jf(dosePending[c], 1) +
         ",\"next\":" + String(timeOk ? doseNext(c, m) : -1) + ",\"empty\":" + String(doseEmpty[c] ? "true" : "false") + "}";
  }
  return j + "]}";
}

void handleSet() {
  if (!reqHas("id")) { replyError("id?"); return; }
  int i = reqArg("id").toInt();
  if (i < 0 || i >= NUM_OUTLETS) { replyError("id invalido"); return; }
  if (reqHas("mode")) { int m = reqArg("mode").toInt(); if (m >= 0 && m <= 3) cfg[i].mode = m; }
  if (reqHas("on")) cfg[i].onMin = constrain(reqArg("on").toInt(), 0, 1439);
  if (reqHas("off")) cfg[i].offMin = constrain(reqArg("off").toInt(), 0, 1439);
  if (reqHas("sec")) cfg[i].doseSec = constrain(reqArg("sec").toInt(), 1, 600);
  saveOutlet(i);
  runLogic();
  sendStatus();
}

void handleThermo() {
  auto get = [&](const char* k, float &v, const char* key) {
    if (reqHas(k)) { v = reqArg(k).toFloat(); prefs.putFloat(key, v); }
  };
  get("hon", heaterOn, "hon"); get("hoff", heaterOff, "hoff");
  get("con", chillerOn, "con"); get("coff", chillerOff, "coff");
  get("alo", alarmLo, "alo"); get("ahi", alarmHi, "ahi");
  sendStatus();
}

// /api/cal?type=ph&point=7|4   (com a sonda mergulhada na solução tampão)
// /api/cal?type=ec&ref=53.0    (com a sonda na solução de referência, em mS/cm)
void handleCal() {
  String type = reqArg("type");
  if (!adsOk) { replyError("ADS1115 nao encontrado"); return; }
  if (type == "ph") {
    float v = avgVolts(0);
    if (reqArg("point") == "7") { phV7 = v; prefs.putFloat("phv7", v); }
    else { phV4 = v; prefs.putFloat("phv4", v); }
    phCal = phV7 > 0 && phV4 > 0 && phV7 != phV4;
    prefs.putBool("phcal", phCal);
  } else if (type == "ec" && !isnan(temperature)) {
    float ref = reqArg("ref").toFloat();
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
    if (reqHas("liters")) { tpaLiters = constrain(reqArg("liters").toFloat(), 0.5f, 200.0f); prefs.putFloat("tpaL", tpaLiters); }
    if (reqHas("drainLpm")) { tpaDrainLpm = constrain(reqArg("drainLpm").toFloat(), 0.1f, 100.0f); prefs.putFloat("tpaD", tpaDrainLpm); }
    if (reqHas("fillLpm")) { tpaFillLpm = constrain(reqArg("fillLpm").toFloat(), 0.1f, 100.0f); prefs.putFloat("tpaF", tpaFillLpm); }
  }
  sendStatus();
}

void handleAtoReset() { atoFault = false; atoLastStop = millis(); sendStatus(); }

// ---------- API da dosadora ----------
int doseArgCh() {
  int c = reqHas("ch") ? reqArg("ch").toInt() : -1;
  return (c >= 0 && c < DOSE_CH) ? c : -1;
}

// /api/doser/set?ch=0&name=Cálcio&en=1&ml=10&n=4&start=480&end=1200&rate=60&cap=1000
void handleDoserSet() {
  int c = doseArgCh();
  if (c < 0) { replyError("ch invalido"); return; }
  if (reqHas("name")) { String n = reqArg("name"); n.trim(); if (n.length() > 0) dose[c].name = n.substring(0, 24); }
  if (reqHas("en")) dose[c].en = reqArg("en") == "1";
  if (reqHas("ml")) dose[c].mlDay = constrain(reqArg("ml").toFloat(), 0.0f, 500.0f);
  if (reqHas("n")) dose[c].doses = constrain(reqArg("n").toInt(), 1, 24);
  if (reqHas("start")) dose[c].startMin = constrain(reqArg("start").toInt(), 0, 1439);
  if (reqHas("end")) dose[c].endMin = constrain(reqArg("end").toInt(), 0, 1439);
  if (reqHas("rate")) dose[c].rate = constrain(reqArg("rate").toFloat(), 1.0f, 1000.0f);
  if (reqHas("cap")) {
    dose[c].capMl = constrain(reqArg("cap").toFloat(), 10.0f, 20000.0f);
    if (dose[c].leftMl > dose[c].capMl) dose[c].leftMl = dose[c].capMl;
  }
  // Doses de hoje que já passaram não são repetidas com a agenda nova.
  int m, d;
  doseDoneMask[c] = 0;
  if (nowMinute(m, d)) for (int k = 0; k < dose[c].doses; k++) if (doseSlot(c, k) < m) doseDoneMask[c] |= (1UL << k);
  doseEmpty[c] = false;
  saveDose(c);
  sendStatus();
}

// Recipiente cheio de novo
void handleDoserRefill() {
  int c = doseArgCh();
  if (c >= 0) { dose[c].leftMl = dose[c].capMl; doseEmpty[c] = false; saveDose(c); }
  sendStatus();
}

// Dose avulsa: /api/doser/dose?ch=1&ml=2.5
void handleDoserDose() {
  int c = doseArgCh();
  float ml = reqArg("ml").toFloat();
  if (c >= 0 && ml > 0 && ml <= 100) { dosePending[c] += ml; doseMsg = ""; }
  sendStatus();
}

// Calibração: liga a bomba por 1 minuto; o app pede quanto saiu no copo e envia rate=ml.
void handleDoserCalib() {
  int c = doseArgCh();
  if (c >= 0 && doseRunning < 0 && !tpaActive()) {
    doseRunning = c; doseCalib = true; doseRunMs = DOSE_CALIB_MS; doseRunMl = 0; doseStartMs = millis();
    writeDoser(c, true);
  }
  sendStatus();
}

void handleDoserStop() {
  doseStop(true);
  for (int c = 0; c < DOSE_CH; c++) dosePending[c] = 0;
  doseMsg = "Dosagem interrompida";
  sendStatus();
}

// ---------- acesso pela internet (MQTT) ----------
// Tópicos: aqualight/<DEVICE_ID>/status  (estado, retido)
//          aqualight/<DEVICE_ID>/online  (1 = ligado, 0 = caiu; retido)
//          aqualight/<DEVICE_ID>/cmd     (comando: "/api/set?id=3&mode=1")
//          aqualight/<DEVICE_ID>/tc/req  (pacote para a luminária TC421)
//          aqualight/<DEVICE_ID>/tc/rep  (resposta da luminária)
WiFiClientSecure mqttNet;
PubSubClient mqtt(mqttNet);
WiFiUDP tcUdp;
unsigned long mqttLastTry = 0, mqttLastStatus = 0;
String mqttLastPayload = "";
String tcPendingId = "";
unsigned long tcDeadline = 0;

bool mqttEnabled() { return strlen(MQTT_HOST) > 0; }
bool mqttOk() { return mqttEnabled() && mqtt.connected(); }
String topic(const char* t) { return String("aqualight/") + DEVICE_ID + "/" + t; }

// Publica o estado. force = mesmo que nada tenha mudado.
void mqttPublishStatus(bool force) {
  if (!mqttOk()) return;
  String j = statusJson();
  if (!force && j == mqttLastPayload && millis() - mqttLastStatus < 60000) return;
  mqttLastPayload = j; mqttLastStatus = millis();
  mqtt.publish(topic("status").c_str(), j.c_str(), true);
}

String urlDecode(const String& in) {
  String out; out.reserve(in.length());
  for (unsigned i = 0; i < in.length(); i++) {
    char c = in[i];
    if (c == '+') out += ' ';
    else if (c == '%' && i + 2 < in.length()) { out += (char)strtol(in.substring(i + 1, i + 3).c_str(), nullptr, 16); i += 2; }
    else out += c;
  }
  return out;
}

// "a=1&b=x" -> mqttArgs
void parseQuery(const String& q) {
  mqttArgs.clear();
  int start = 0;
  while (start < (int)q.length()) {
    int amp = q.indexOf('&', start); if (amp < 0) amp = q.length();
    String part = q.substring(start, amp);
    int eq = part.indexOf('=');
    if (eq > 0) mqttArgs[urlDecode(part.substring(0, eq))] = urlDecode(part.substring(eq + 1));
    start = amp + 1;
  }
}

typedef void (*Handler)();
struct Route { const char* path; Handler fn; };
void handleStatusMqtt() { sendStatus(); }
const Route ROUTES[] = {
  {"/api/status", handleStatusMqtt}, {"/api/set", handleSet}, {"/api/thermo", handleThermo}, {"/api/cal", handleCal},
  {"/api/atoreset", handleAtoReset}, {"/api/tpa/start", handleTpaStart}, {"/api/tpa/stop", handleTpaStop},
  {"/api/tpa/config", handleTpaConfig}, {"/api/doser/set", handleDoserSet}, {"/api/doser/refill", handleDoserRefill},
  {"/api/doser/dose", handleDoserDose}, {"/api/doser/calib", handleDoserCalib}, {"/api/doser/stop", handleDoserStop},
};

int hexVal(char c) { return c >= '0' && c <= '9' ? c - '0' : (c >= 'a' && c <= 'f' ? c - 'a' + 10 : (c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1)); }

void mqttMessage(char* t, byte* payload, unsigned int len) {
  String msg; msg.reserve(len);
  for (unsigned i = 0; i < len; i++) msg += (char)payload[i];
  String tp(t);
  if (tp == topic("cmd")) {
    int qm = msg.indexOf('?');
    String path = qm < 0 ? msg : msg.substring(0, qm);
    parseQuery(qm < 0 ? String("") : msg.substring(qm + 1));
    for (const Route& r : ROUTES) {
      if (path == r.path) { viaMqtt = true; r.fn(); viaMqtt = false; break; }
    }
    mqttArgs.clear();
  } else if (tp == topic("tc/req")) {
    // Pacote para a TC421: "n=<id>&w=<ms de espera>&ip=<opcional>&hex=<bytes>"
    parseQuery(msg);
    String hex = mqttArgs["hex"];
    uint8_t buf[64]; int n = 0;
    for (unsigned i = 0; i + 1 < hex.length() && n < 64; i += 2) {
      int a = hexVal(hex[i]), b = hexVal(hex[i + 1]);
      if (a < 0 || b < 0) break;
      buf[n++] = (uint8_t)(a * 16 + b);
    }
    IPAddress dest(255, 255, 255, 255);
    if (mqttArgs["ip"].length()) dest.fromString(mqttArgs["ip"]);
    while (tcUdp.parsePacket() > 0) tcUdp.flush();      // descarta respostas velhas
    tcUdp.beginPacket(dest, 5000); tcUdp.write(buf, n); tcUdp.endPacket();
    int wait = mqttArgs["w"].toInt();
    if (wait > 0) { tcPendingId = mqttArgs["n"]; tcDeadline = millis() + min(wait, 3000); }
    mqttArgs.clear();
  }
}

// Repassa a resposta da TC421 para o app (só a primeira que vier da controladora).
void tcTick() {
  if (tcPendingId.length() == 0) return;
  int size = tcUdp.parsePacket();
  if (size > 0) {
    uint8_t buf[64]; int n = tcUdp.read(buf, sizeof(buf));
    if (n > 4 && buf[0] == 0x88 && buf[1] == 0) {
      String hex; const char* digits = "0123456789abcdef";
      for (int i = 0; i < n; i++) { hex += digits[buf[i] >> 4]; hex += digits[buf[i] & 15]; }
      mqtt.publish(topic("tc/rep").c_str(), ("n=" + tcPendingId + "&hex=" + hex).c_str());
      tcPendingId = "";
      return;
    }
  }
  if ((long)(millis() - tcDeadline) > 0) {
    mqtt.publish(topic("tc/rep").c_str(), ("n=" + tcPendingId + "&hex=").c_str());
    tcPendingId = "";
  }
}

void mqttTick() {
  if (!mqttEnabled() || WiFi.status() != WL_CONNECTED) return;
  if (!mqtt.connected()) {
    if (millis() - mqttLastTry < 15000 && mqttLastTry != 0) return;
    // A conexão pode travar o programa por alguns segundos: nunca com uma bomba dosando ou na TPA.
    if (doseRunning >= 0 || tpaActive()) return;
    mqttLastTry = millis();
    String id = String(DEVICE_ID) + "-esp32";
    if (mqtt.connect(id.c_str(), MQTT_USER, MQTT_PASS, topic("online").c_str(), 1, true, "0")) {
      mqtt.publish(topic("online").c_str(), "1", true);
      mqtt.subscribe(topic("cmd").c_str());
      mqtt.subscribe(topic("tc/req").c_str());
      mqttPublishStatus(true);
    }
    return;
  }
  mqtt.loop();
  tcTick();
  if (millis() - mqttLastStatus >= 5000) mqttPublishStatus(false);
}

// ---------- alertas no celular (ntfy) ----------
String alertsSent = "";            // alertas já avisados (para não repetir)
unsigned long alertsLastCheck = 0;

void ntfySend(const String& text) {
  WiFiClientSecure c; c.setInsecure();
  HTTPClient http;
  if (!http.begin(c, String("https://ntfy.sh/") + NTFY_TOPIC)) return;
  http.addHeader("Title", "Aquario");
  http.addHeader("Priority", "high");
  http.addHeader("Tags", "warning");
  http.setTimeout(5000);
  http.POST(text);
  http.end();
}

void alertsTick() {
  if (strlen(NTFY_TOPIC) == 0 || WiFi.status() != WL_CONNECTED) return;
  if (millis() - alertsLastCheck < 30000) return;
  if (doseRunning >= 0) return;                  // o envio leva ~1 s: espera a dose terminar
  alertsLastCheck = millis();
  String now = alarmsJson();                     // ["a","b"]
  // Avisa cada alerta novo uma vez; quando some, pode avisar de novo depois.
  String body = now.substring(1, now.length() - 1);
  String kept = "";
  int start = 0;
  while (start < (int)body.length()) {
    int a = body.indexOf('"', start); if (a < 0) break;
    int b = body.indexOf('"', a + 1); if (b < 0) break;
    String item = body.substring(a + 1, b);
    kept += "|" + item + "|";
    if (alertsSent.indexOf("|" + item + "|") < 0) ntfySend(item);
    start = b + 1;
  }
  alertsSent = kept;
}

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
  for (int c = 0; c < DOSE_CH; c++) { pinMode(DOSE_PIN[c], OUTPUT); writeDoser(c, false); }
  for (int i = 0; i < NUM_OUTLETS; i++) { pinMode(OUTLET_PIN[i], OUTPUT); writeRelay(i, false); }
  pinMode(PIN_FLOAT_SUMP, INPUT_PULLUP);
  pinMode(PIN_FLOAT_RESERVOIR, INPUT_PULLUP);
  pinMode(PIN_FLOAT_SUMP_MIN, INPUT);   // pino 34: resistor de 10 kΩ externo para o 3,3 V
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
  server.on("/api/doser/set", handleDoserSet);
  server.on("/api/doser/refill", handleDoserRefill);
  server.on("/api/doser/dose", handleDoserDose);
  server.on("/api/doser/calib", handleDoserCalib);
  server.on("/api/doser/stop", handleDoserStop);
  server.begin();
  tcUdp.begin(5000);
  if (mqttEnabled()) {
    mqttNet.setInsecure();          // conexão criptografada; o certificado do servidor não é conferido
    mqtt.setServer(MQTT_HOST, MQTT_PORT);
    mqtt.setBufferSize(4096);
    mqtt.setKeepAlive(30);
    mqtt.setCallback(mqttMessage);
  }
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
  mqttTick();
  alertsTick();
}
