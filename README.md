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

- **Conexão:** acha a controladora (por IP ou broadcast) e lê o MAC. Botão para sincronizar a hora.
- **Controle:** 5 sliders. Com "Controle ao vivo" ligado, mandam os valores na hora (experimental).
- **Cronograma:** 48 pontos (um a cada 30 min) x 5 canais, com presets, e envio para a controladora.

## Pontos não confirmados em hardware

- O repositório de referência só usa broadcast. Não sei se a controladora responde a pacotes
  enviados direto ao IP dela; é o primeiro teste a fazer no iPhone.
- O modo "ao vivo" não está terminado no repositório de referência.
- Se algo não responder, o status do app mostra onde parou.

## Aquário completo (ESP32)

A pasta `firmware/` tem o programa do ESP32 que controla as tomadas, temperatura, pH, salinidade e reposição. Leia `firmware/LEIAME.md` (peças, ligações, segurança e calibração). No app, a aba **Aquário** conversa com ele pelo IP.
