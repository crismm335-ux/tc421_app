# App TC421

App Flutter para a controladora de LED TC421 (5 canais, WiFi). Fala UDP na porta 5000,
no formato descoberto pela engenharia reversa de github.com/sdotter/TC421.

## Como rodar

1. Instale o Flutter (3.24 ou mais novo).
2. Nesta pasta: `./setup.sh` (cria android/ e ios/, ajusta permissões, roda os testes).
3. Com o celular no **mesmo WiFi da controladora**: `flutter run`.

### iPhone, usando só o Windows (sem Mac)

O iOS só compila em Mac, então a compilação é feita na nuvem pelo GitHub (arquivo
`.github/workflows/build-ios.yml`) e a instalação pelo Sideloadly.

1. Crie uma conta no github.com e um repositório **privado** vazio (ex.: `tc421-app`).
2. Instale o Git para Windows. Nesta pasta, no terminal:
   ```
   git init
   git add .
   git commit -m "app tc421"
   git branch -M main
   git remote add origin https://github.com/SEU_USUARIO/tc421-app.git
   git push -u origin main
   ```
3. No GitHub, aba **Actions**: o build "Build iOS (sem assinatura)" começa sozinho
   (leva cerca de 10 a 15 minutos). Quando ficar verde, abra a execução e baixe o arquivo
   `tc421-ipa` em "Artifacts" (vem dentro de um .zip; extraia para obter `tc421.ipa`).
4. Instale o iTunes pelo site da Apple (não pela Microsoft Store) e o Sideloadly (sideloadly.io).
5. Conecte o iPhone por USB, toque em "Confiar". Abra o Sideloadly, arraste o `tc421.ipa`,
   digite seu Apple ID e clique em Start.
6. No iPhone: Ajustes > Geral > VPN e Gerenciamento de Dispositivo, confie no seu Apple ID.
   No iOS 16 ou mais novo, ative também o Modo Desenvolvedor (Ajustes > Privacidade e Segurança).
7. Com Apple ID gratuito o app **expira em 7 dias**: refaça o passo 5 com o mesmo arquivo.

Se o build ficar vermelho, abra o passo que falhou e me envie o texto do erro.

### Notas gerais do iPhone

- Com um Mac e o Xcode também dá para rodar direto com `flutter run`.
- O iOS só permite **broadcast** com uma permissão especial da Apple. Por isso, no iPhone,
  toque no ícone de rede no topo do app e informe o **IP da controladora** (veja a lista de
  aparelhos no painel do roteador; vale reservar o IP fixo para ela). O app salva o IP.
- Na primeira abertura o iOS pergunta se o app pode acessar a rede local: aceite.

### Android

Funciona por broadcast, sem precisar informar o IP. APK: `flutter build apk --release`.

## O que o app faz

Visual do painel neon (Aqua Light). Abas de baixo: **Início, Luminária, Equipamentos, Dosadora, Animais e Testes**. Dentro de Luminária ficam Canais, Programação e Perfis.

- **Início:** status da TC421, intensidade de agora, modos MASTER /
  Recife / Noturno, resumo do dia e "Seu aquário": o botão Personalizar escolhe o que aparece
  (sensores, alertas, níveis, tomadas, TPA, último teste de KH/Ca/Mg/NO3/PO4 e animais).
- **Canais:** cada canal com chave liga/desliga, barra e espectro. Mexer num canal com a luminária
  conectada liga o controle ao vivo; "Voltar ao cronograma" desliga. Aba Espectro mostra a mistura.
  Canal desligado vai como 0% ao vivo e no cronograma enviado.
- **Programação:** Gráfico com os 5 canais (marque quais aparecem), pontos arrastáveis, horário com
  setas de 30 em 30 min, Adicionar/Remover ponto, Duplicar curva, Limpar canal (com Desfazer) e envio.
  Tabela com os pontos de cada canal. Simulação do dia na luminária (15, 30 ou 60 s).
- **Perfis:** Biblioteca (Recife Natural, Predominância Azul, Cores Vibrantes, Crescimento
  (LPS/SPS), Apenas Visual) e Meus Perfis (salvos no celular, mais exportar/importar JSON).
- **Equipamentos:** tomadas (bomba de circulação, skimmer, reposição/ATO, bomba de recalque, aquecedor,
  resfriamento, luminária), sensores, calibração e a **TPA automática** (um botão retira os litros escolhidos do
  sump e outra bomba repõe com água nova).
- **Dosadora:** 4 canais com ml por dia, número de doses, horários, recipiente, dose avulsa e calibração.
- **Animais e Testes:** cada um na sua aba.
- A engrenagem no topo das telas abre a Conexão da luminária (IP, hora, nova busca).

## iPhone sem instalar nada (versão web)

O workflow **Build Web (iPhone)** gera o app como site e publica no **GitHub Pages**, igual ao app de
finanças. Ele abre no Safari, fica na tela de início como um app e não expira. Na versão web tudo passa
pela internet (o navegador não fala direto com o ESP32 nem com a luminária), então configure antes o
**Acesso fora de casa**, logo abaixo.

1. No GitHub, no repositório: **Settings → Pages → Source: GitHub Actions** (uma vez só).
   Em conta gratuita o Pages exige repositório **público**. Pode deixar público com segurança: as senhas
   do ESP32 ficam no `segredos.h`, que não é enviado, e as do app ficam só no celular.
2. Envie o projeto e espere o **Build Web (iPhone)** ficar verde.
3. No iPhone, abra `https://<seu-usuario>.github.io/<nome-do-repositorio>/` no Safari →
   Compartilhar → **Adicionar à Tela de Início**.
4. Abra pelo ícone → engrenagem → **Acesso pela internet** → os mesmos dados do ESP32.

Depois de uma atualização, se o iPhone mostrar a versão antiga, feche o app e abra de novo.

## Senhas do ESP32

Na pasta `firmware/aquario_esp32`, copie `segredos_exemplo.h` para `segredos.h` e coloque ali o Wi-Fi,
os dados do servidor e o tópico do ntfy. O `segredos.h` fica só no seu computador (está no `.gitignore`).

## Acesso fora de casa (internet)

Em casa o app fala direto com o ESP32 e com a luminária pelo Wi-Fi. Fora de casa ele passa por um
servidor MQTT gratuito na internet, o HiveMQ Cloud: o ESP32 manda o estado para lá e recebe os
comandos, e também repassa os comandos para a luminária TC421. O app troca sozinho entre os dois.

1. **Crie o servidor (uma vez):** entre em console.hivemq.cloud, crie uma conta e um cluster do plano
   **Serverless (Free)**. Anote o **Cluster URL** (algo como `abc123.s1.eu.hivemq.cloud`).
   Em **Access Management**, crie um usuário e uma senha com permissão de **Publish and Subscribe**.
2. **No ESP32** (arquivo `firmware/aquario_esp32/segredos.h`, veja "Senhas do ESP32"): preencha `MQTT_HOST`,
   `MQTT_USER`, `MQTT_PASS` e invente um `DEVICE_ID` só seu, sem espaços (ex.: `aquario-k7p3x9`).
   Instale a biblioteca **PubSubClient** e grave de novo.
3. **No app:** engrenagem (Conexão) → **Acesso pela internet** → os mesmos 4 dados → **Salvar e conectar**.
   Quando aparecer "Pronto", teste com o Wi-Fi do celular desligado.

**Alertas no celular (opcional, app ntfy):** instale o app **ntfy** (Play Store ou App Store), toque em
"+" e assine um tópico com um nome difícil de adivinhar (ex.: `aquario-k7p3x9w2`). Coloque esse nome em
`NTFY_TOPIC` no `segredos.h`. Ele avisa quando aparece um alerta (temperatura fora do limite,
galão vazio, reposição travada, dosadora acabando), mesmo com o Aqua Light fechado.
Quem souber o nome do tópico também vê os avisos, por isso use um nome difícil.

Bom saber:
- Usuário e senha protegem os comandos. A conexão é criptografada; o ESP32 não confere o certificado
  do servidor (para simplificar).
- Pela internet, enviar a programação para a luminária demora mais (uns 10 a 30 segundos) e a
  simulação do dia pode engasgar. O resto funciona igual.
- Se o ESP32 cair, o app mostra "Aquário sem conexão" e a última leitura recebida fica de lado.

## Pontos não confirmados em hardware

- O repositório de referência só usa broadcast. Não sei se a controladora responde a pacotes
  enviados direto ao IP dela; é o primeiro teste a fazer no iPhone.
- O modo "ao vivo" não está terminado no repositório de referência.
- Se algo não responder, o status do app mostra onde parou.

## Aquário completo (ESP32)

A pasta `firmware/` tem o programa do ESP32 que controla as tomadas, temperatura, pH, salinidade e reposição. Leia `firmware/LEIAME.md` (peças, ligações, segurança e calibração). No app, a aba **Aquário** conversa com ele pelo IP.
