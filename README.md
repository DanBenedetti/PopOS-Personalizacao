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

Com autostart do widget (inicia junto no login):

```bash
curl -fsSL https://raw.githubusercontent.com/DanBenedetti/PopOS-Personalizacao/main/restaurar-setup-cosmic.sh | bash -s -- --autostart
```

Ou clonando o repositório:

```bash
git clone https://github.com/DanBenedetti/PopOS-Personalizacao.git
cd PopOS-Personalizacao
bash restaurar-setup-cosmic.sh
```

---

## Opções

| Flag | Efeito |
|---|---|
| *(nenhuma)* | restaura dependências + Aura + widget |
| `--autostart` | cria `~/.config/autostart/calendar-widget.desktop` |
| `--help` | mostra a ajuda (funciona também via `curl \| bash`) |

---

## O que o script faz

1. **Verifica o ambiente** — Linux, x86_64, `apt`, `curl`
2. **Instala dependências** — `gir1.2-gtklayershell-0.1`, `libgtk-layer-shell0`,
   `python3-gi`, `fonts-dancingscript`, `libmpv2`, `ffmpeg`
3. **Instala o Aura** — instalador oficial, com checksum SHA-256
4. **Grava o widget** em `~/.local/bin/calendar-widget`
5. **Aplica a configuração do Aura** — preserva um `config.json` existente
   ou cria do zero (schema v1.9.2), garantindo `auto_pause=false` e
   `smart_pause=true`
6. **(opcional)** cria o autostart do widget
7. **Verifica tudo** — compila o widget, testa Aura/mpvpaper, valida o JSON

O script é **idempotente**: rodar várias vezes não quebra nada.

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `restaurar-setup-cosmic.sh` | script de restauração completo e **autocontido** (o widget vai embutido) |
| `calendar-widget` | widget de calendário — Python 3 + GTK3 + `gtk-layer-shell` |

### Parâmetros de aparência do widget

Estão no topo do `calendar-widget`, fáceis de calibrar:

| Onde | Valor | O que controla |
|---|---|---|
| CSS `.cal-dia` / `font_desc` | `140px` | tamanho do dia da semana |
| CSS `.cal-data` / `font_desc` | `34px` | tamanho da data |
| `pack_start(...)` | `6` | espaçamento entre as linhas |
| `Edge.BOTTOM, 96` | `96` | margem inferior (folga do dock) |
| `Layer.BOTTOM` | — | camada: atrás das janelas |

---

## Limitações conhecidas

- **Não faz backup dos vídeos de wallpaper.** O script cria
  `~/Imagens/Wallpapers/Aura/`, mas os arquivos de mídia precisam ser
  copiados manualmente.
- O `--autostart` é opt-in (por padrão o widget só vive durante a sessão).

## Licença

Uso pessoal.
