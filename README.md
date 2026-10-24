# App TC421

App Flutter para a controladora de LED TC421 (5 canais, WiFi). Fala UDP na porta 5000,
no formato descoberto pela engenharia reversa de github.com/sdotter/TC421.

## Como rodar

1. Instale o Flutter (3.24 ou mais novo) e ative a depuração USB no celular.
2. Nesta pasta: `./setup.sh` (cria android/ e ios/, ajusta permissões, roda os testes).
3. Com o celular no **mesmo WiFi da controladora**: `flutter run`.
4. Para gerar o APK: `flutter build apk --release`.

## O que o app faz

- **Conexão:** acha a controladora por broadcast e lê o MAC. Botão para sincronizar a hora.
- **Controle:** 5 sliders. Com "Controle ao vivo" ligado, mandam os valores na hora (experimental).
- **Cronograma:** 48 pontos (um a cada 30 min) x 5 canais, com presets, e envio para a controladora.

## Pontos não confirmados em hardware

O repositório de referência não termina o modo "ao vivo" e não documenta a resposta ao
fim do envio. Se algo não responder, o status do app mostra onde parou.
