# Setup do desktop COSMIC — Pop!_OS

Setup customizado para o **COSMIC Desktop** no **Pop!_OS 24.04 (Wayland)**,
feito para ser reproduzido em qualquer máquina minha que rode Pop!_OS.

O que ele instala:

- **Wallpaper animado** via [Aura](https://github.com/antwny/aura), com
  `auto_pause = false` (o vídeo **não** pausa ao abrir janelas em grade —
  importante no COSMIC, que é tiling por padrão) e `smart_pause = true`
  (continua pausando em **jogo em tela cheia** e **tela bloqueada**).
- **Widget de calendário** no canto inferior esquerdo: dia da semana
  por extenso em português com fonte cursiva (`Dancing Script`) e a data
  no formato `01 DE NOVEMBRO DE 2026`.
- **Configurador gráfico** (`calendar-widget-config`) para ajustar posição,
  fonte e tamanhos, com prévia da tela e botão **Aplicar** — com atalho
  **Calendário — Ajustes** no menu de aplicativos.

O widget usa **Wayland Layer Shell** na camada `BOTTOM` — acima do wallpaper,
mas **atrás de todas as janelas**, com `KeyboardMode.NONE` (cliques e teclado
atravessam). Ou seja: ele faz parte visualmente do papel de parede e não
atrapalha o uso.

---

## Instalação rápida (em outro Pop!_OS)

Sem clonar nada:

```bash
curl -fsSL https://raw.githubusercontent.com/DanBenedetti/PopOS-Personalizacao/main/restaurar-setup-cosmic.sh | bash
```

Sem o autostart do widget (por padrão ele **inicia junto no login**):

```bash
curl -fsSL https://raw.githubusercontent.com/DanBenedetti/PopOS-Personalizacao/main/restaurar-setup-cosmic.sh | bash -s -- --no-autostart
```

**Só o widget de calendário** (sem Aura/wallpaper): rode o instalador
dedicado dentro da pasta do projeto — ele cria o atalho do menu, o
`config.ini` e o autostart:

```bash
git clone https://github.com/DanBenedetti/PopOS-Personalizacao.git
cd PopOS-Personalizacao
bash instalar-widget-calendario.sh
```

Opções: `--no-autostart`, `--sem-iniciar`, `--help`.

Ou clonando o repositório (setup completo, com Aura):

```bash
git clone https://github.com/DanBenedetti/PopOS-Personalizacao.git
cd PopOS-Personalizacao
bash restaurar-setup-cosmic.sh
```

---

## Opções

| Flag | Efeito |
|---|---|
| *(nenhuma)* | restaura dependências + Aura + widget **e cria o autostart** |
| `--autostart` | idem ao padrão (mantido por compatibilidade) |
| `--no-autostart` | restaura **sem** criar o autostart do widget |
| `--help` | mostra a ajuda (funciona também via `curl \| bash`) |

---

## O que o script faz

1. **Verifica o ambiente** — Linux, x86_64, `apt`, `curl`
2. **Instala dependências** — `gir1.2-gtklayershell-0.1`, `libgtk-layer-shell0`,
   `python3-gi`, `fonts-dancingscript`, `libmpv2`, `ffmpeg`
3. **Instala o Aura** — instalador oficial, com checksum SHA-256
4. **Grava o widget** em `~/.local/bin/calendar-widget`
5. **Grava o configurador** em `~/.local/bin/calendar-widget-config`, cria
   `~/.config/calendar-widget/config.ini` (preservado se já existir) e o
   atalho `~/.local/share/applications/calendar-widget-config.desktop`
6. **Aplica a configuração do Aura** — preserva um `config.json` existente
   ou cria do zero (schema v1.9.2), garantindo `auto_pause=false` e
   `smart_pause=true`
7. **cria o autostart do widget** (padrão; desative com `--no-autostart`)
8. **Verifica tudo** — compila widget/configurador, testa Aura/mpvpaper,
   valida os JSONs e o atalho do menu

O script é **idempotente**: rodar várias vezes não quebra nada.

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `restaurar-setup-cosmic.sh` | script de restauração completo e **autocontido** (o widget vai embutido) |
| `instalar-widget-calendario.sh` | instalador **só do widget** (usa os arquivos desta pasta; cria atalho, config e autostart) |
| `calendar-widget` | widget de calendário — Python 3 + GTK3 + `gtk-layer-shell` |
| `calendar-widget-config` | configurador gráfico do widget (GTK3) |
| `calendar-widget-config.desktop` | atalho de menu do configurador |

### Personalizar o widget

**Pela interface (recomendado):** abra **Calendário — Ajustes** no menu de
aplicativos, ou rode no terminal:

```bash
calendar-widget-config
```

A janela tem prévia de uma tela 1920×1080, escolha da borda (esquerda/direita),
margens em pixels, fonte e tamanho de cada linha, e espaço entre elas.
**Aplicar** grava a configuração e reinicia o widget na hora; **Restaurar
padrões** volta aos valores originais.

**Pelo arquivo** `~/.config/calendar-widget/config.ini`:

```ini
[posicao]
ancora_horizontal = esquerda   # esquerda | direita
margem_lateral = 44            # distância da borda lateral escolhida
margem_inferior = 56           # distância do rodapé: menor = mais baixo

[texto]
fonte_dia = Dancing Script     # nome da família (veja: fc-list : family)
tamanho_dia = 140              # px
fonte_data = Ubuntu
tamanho_data = 34              # px
espacamento = 6               # espaço entre as duas linhas
```

O arquivo é criado com os padrões na primeira execução. Valores ausentes,
inválidos ou fora de faixa caem no padrão sem quebrar o widget, e uma fonte
não instalada usa a reserva mais próxima (aviso no terminal). Depois de editar
à mão, reinicie o widget para valer — o configurador relê o arquivo ao abrir,
e o **Aplicar** dele reinicia o widget.

---

## Limitações conhecidas

- **Não faz backup dos vídeos de wallpaper.** O script cria
  `~/Imagens/Wallpapers/Aura/`, mas os arquivos de mídia precisam ser
  copiados manualmente.
- Para **não** ter o widget no login, rode o script com `--no-autostart`.

## Licença

Uso pessoal.
