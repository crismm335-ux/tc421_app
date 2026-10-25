# Controladora de aquário (ESP32)

Programa para o ESP32 que controla 10 tomadas, temperatura, pH, salinidade e a reposição de água (ATO). O app Aqua Light conversa com ele pela rede Wi-Fi.

## Lista de peças

- ESP32 (placa de desenvolvimento, "ESP32 DevKit" de 30 ou 38 pinos)
- Módulo de relés de 8 canais **e** mais 2 relés (ou um módulo de 16 canais), com optoacoplador, para as 10 tomadas
- Para a TPA: uma bomba que retira água do sump (bomba de esgoto) e outra que repõe a água pronta do reservatório
- Sensor de temperatura DS18B20 à prova d'água + resistor de 4,7 kΩ
- ADS1115 (conversor analógico, I2C) para pH e salinidade
- Sonda de pH com placa de interface (por exemplo DFRobot Gravity pH) e sonda de condutividade/salinidade com placa de interface (por exemplo DFRobot Gravity EC). Compre as duas do tipo analógico, com saída de 0 a 3,3 V.
- Três boias de nível (contato seco): uma no sump (nível baixo, para a reposição), uma no galão de reposição e uma de **nível mínimo do sump** (para a TPA)
- Fonte USB de 5 V para o ESP32
- Caixa de acrílico, régua de tomadas com aterramento, fusível ou mini-disjuntor, borne/terminal para os sensores

## Ligações

| Função | Pino do ESP32 |
|---|---|
| Relés 1 a 10 (na ordem abaixo) | 16, 17, 18, 19, 23, 25, 26, 32, 33, 13 |
| Sensor DS18B20 (dado) | 4 (com 4,7 kΩ entre dado e 3,3 V) |
| ADS1115 SDA / SCL | 21 / 22 |
| Boia do sump | 27 e GND |
| Boia do galão | 14 e GND |
| Boia de nível mínimo do sump | 15 e GND |

Ordem das tomadas: 1 Bomba de circulação, 2 Skimmer, 3 Reposição (ATO), 4 Recalque, 5 Aquecedor, 6 Resfriamento, 7 Luminária, 8 TPA: retirar água do sump, 9 TPA: repor água pronta, 10 Dosadora.

ADS1115: canal A0 recebe a saída do pH, canal A1 recebe a saída da salinidade. Alimente o ADS1115 e as placas das sondas com 3,3 V do ESP32.

Boias: o programa considera "nível baixo no sump" quando a boia do sump fecha contato com o GND, e "galão vazio" quando a boia do galão fecha contato com o GND. Se a sua boia funciona ao contrário, inverta o sentido dela fisicamente.

## Segurança elétrica (leia antes de ligar)

- Quem faz a parte de 110/220 V precisa saber o que está fazendo. Se não tiver experiência, peça a um eletricista para revisar.
- Mantenha o lado da rede elétrica separado do lado de baixa tensão (ESP32, sondas, fios finos), com divisória na caixa.
- Use disjuntor DR na entrada, fusível ou mini-disjuntor antes da régua, e mantenha o fio terra ligado em todas as tomadas.
- Faça curva para baixo nos cabos antes de entrarem na caixa (gotejador) e deixe a caixa longe de respingos.
- **Quanto ao que cada equipamento faz se o ESP32 travar ou ficar sem energia:**
  - Aquecedor, resfriamento, reposição, skimmer e dosadora: ligue no contato **NA** (normalmente aberto) do relé. Sem energia, ficam desligados.
  - Bomba de circulação e recalque: se você preferir que continuem ligadas sem o ESP32, use o contato **NF** (normalmente fechado). Nesse caso, o app "desligar" é o que liga o relé.
  - Decida item por item e teste cada um antes de confiar.
- Mantenha um termostato próprio no aquecedor. O app e o ESP32 são uma segunda proteção, não a única.
- A dosadora liga por tempo. Teste a dose com um copo de medida antes de usá-la no aquário.
- A reposição desliga sozinha após 120 segundos de funcionamento e trava, avisando no app. Isso evita encher o sump se a boia falhar.

## Troca parcial de água (TPA)

No app, a aba Aquário tem o painel **Troca parcial de água**: você informa quantos litros trocar e toca em **Iniciar TPA**. O ESP32 faz tudo sozinho:

1. Liga a bomba de esgoto e retira a quantidade pedida do sump.
2. Espera 3 segundos.
3. Liga a bomba da água pronta e repõe a mesma quantidade, a partir do reservatório que você preparou antes.

Como funciona e o que ele protege:
- A quantidade é medida por **tempo**, usando a vazão (litros por minuto) de cada bomba, que você informa no app. Meça a vazão real de cada bomba com um balde e um cronômetro, senão a quantidade sai errada.
- Se a boia de **nível mínimo do sump** fechar durante a retirada, a retirada para e o app repõe só o que saiu. Instale essa boia acima da entrada da bomba de recalque, para ela nunca trabalhar a seco.
- Durante a TPA, a reposição automática (ATO) fica bloqueada e o skimmer fica desligado. O aquecedor fica desligado enquanto o nível está baixo.
- Cada etapa tem um limite de 30 minutos.
- Dá para interromper a qualquer momento pelo app.
- **Não há sensor no reservatório de água pronta.** Se ele tiver menos água do que a troca pede, a bomba roda a seco no final. Prepare água suficiente (com a mesma salinidade e temperatura do aquário) antes de iniciar e, se puder, coloque nele uma boia ligada à bomba por fora.
- Regule o dreno com cuidado para não enviar a água retirada para um lugar onde ela possa transbordar.

## Gravar o programa

1. Instale o Arduino IDE e o pacote de placas "esp32" (Espressif) pelo Gerenciador de Placas.
2. Instale as bibliotecas OneWire, DallasTemperature e Adafruit ADS1X15.
3. Abra `aquario_esp32/aquario_esp32.ino` e troque `SUA_REDE` e `SUA_SENHA` pelos dados do seu Wi-Fi.
4. Escolha a placa "ESP32 Dev Module", conecte o ESP32 por USB e clique em Carregar.
5. Abra o Monitor Serial (115200). Ele mostra o IP do ESP32. Anote esse IP, e no roteador reserve esse IP para ele.
6. No app, aba Equipamentos, informe o IP.

## Testes antes de ligar equipamentos de verdade

1. Teste só o ESP32 e os relés, sem nada ligado nas tomadas. Ligue e desligue cada tomada pelo app e escute o relé estalar.
2. Depois ligue uma lâmpada comum em cada tomada e confira se a que acende é a que o app diz.
3. Só então ligue os equipamentos do aquário, um por vez.
4. Teste o aquecedor num balde com água, com termômetro de confiança ao lado, antes de usá-lo no aquário.

## Calibração

- **pH:** coloque a sonda na solução de pH 7 e, no app, toque em "Calibrar pH 7". Enxágue e repita com pH 4 e "Calibrar pH 4". Sondas de pH precisam ser recalibradas de tempos em tempos.
- **Salinidade:** use uma solução de condutividade conhecida (por exemplo 53 mS/cm, que equivale a cerca de 35 ppt de água do mar) e informe o valor no app em "Calibrar salinidade". O ESP32 compensa a temperatura. A salinidade mostrada é uma aproximação; confira de vez em quando com um refratômetro.
- As sondas de pH e de salinidade na mesma água podem interferir uma na outra. Se as leituras oscilarem, use isoladores de sinal (módulos de isolamento) ou meça uma por vez.

## Limites desta versão

- Não existe senha na API: qualquer aparelho na sua rede consegue ligar e desligar as tomadas. Use uma rede Wi-Fi com senha forte e não exponha o ESP32 à internet.
- A programação por horário depende da hora da internet (NTP). Sem internet depois de ligar, os horários e a dosadora não disparam até a hora ser obtida.
- O programa não foi testado com os equipamentos reais. Teste tudo aos poucos, como descrito acima.
