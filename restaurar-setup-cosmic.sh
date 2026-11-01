#!/usr/bin/env bash
#
# restaurar-setup-cosmic.sh
# =============================================================================
# Restaura o setup customizado do desktop COSMIC (Pop!_OS 24.04, Wayland):
#
#   1. Dependências de sistema (layer-shell, fonte cursiva, libmpv2, ffmpeg)
#   2. Aura — motor de wallpaper animado, com auto_pause DESLIGADO
#      (o smart_pause continua ligado: pausa em jogo fullscreen/tela bloqueada)
#   3. Widget de calendário — canto inferior esquerdo, atrás das janelas,
#      dia da semana cursivo em pt-BR + data "01 DE NOVEMBRO DE 2026"
#   4. Autostart do widget — inicia sozinho no login (padrão;
#      desative com a flag --no-autostart)
#
# Uso:
#   bash restaurar-setup-cosmic.sh                # restaura tudo (com autostart)
#   bash restaurar-setup-cosmic.sh --no-autostart # restaura sem autostart
#   bash restaurar-setup-cosmic.sh --help
#
# É seguro rodar mais de uma vez (idempotente).
# =============================================================================

set -euo pipefail

# --- Saída colorida ---------------------------------------------------------
c_azul=$'\033[1;34m'; c_verde=$'\033[1;32m'
c_amarelo=$'\033[1;33m'; c_vermelho=$'\033[1;31m'; c_reset=$'\033[0m'

PASSO() { printf '\n%s==> %s%s\n' "$c_azul" "$1" "$c_reset"; }
OK()    { printf '  %s✓%s %s\n' "$c_verde" "$c_reset" "$1"; }
AVISO() { printf '  %s!%s %s\n' "$c_amarelo" "$c_reset" "$1"; }
ERRO()  { printf '  %s✗%s %s\n' "$c_vermelho" "$c_reset" "$1" >&2; }

# Autostart LIGADO por padrão: o widget precisa voltar sozinho no login.
COM_AUTOSTART=1

# --- Argumentos -------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --autostart)    COM_AUTOSTART=1 ;;  # mantido por compatibilidade
        --no-autostart) COM_AUTOSTART=0 ;;
        -h|--help)
            # Heredoc em vez de "$0": assim o --help também funciona quando
            # o script é baixado via curl | bash (sem arquivo em disco).
            cat <<'HELP_TEXT'
restaurar-setup-cosmic.sh
=============================================================================
Restaura o setup customizado do desktop COSMIC (Pop!_OS 24.04, Wayland):

  1. Dependências de sistema (layer-shell, fonte cursiva, libmpv2, ffmpeg)
  2. Aura — motor de wallpaper animado, com auto_pause DESLIGADO
     (o smart_pause continua ligado: pausa em jogo fullscreen/tela bloqueada)
  3. Widget de calendário — canto inferior esquerdo, atrás das janelas,
     dia da semana cursivo em pt-BR + data "01 DE NOVEMBRO DE 2026"
  4. Autostart do widget — inicia sozinho no login (padrão;
     desative com a flag --no-autostart)

Uso:
  bash restaurar-setup-cosmic.sh                # restaura tudo (com autostart)
  bash restaurar-setup-cosmic.sh --no-autostart # restaura sem autostart
  bash restaurar-setup-cosmic.sh --help         # esta ajuda

Via curl (sem clonar):
  curl -fsSL https://raw.githubusercontent.com/DanBenedetti/PopOS-Personalizacao/main/restaurar-setup-cosmic.sh | bash
  curl -fsSL https://raw.githubusercontent.com/DanBenedetti/PopOS-Personalizacao/main/restaurar-setup-cosmic.sh | bash -s -- --no-autostart

É seguro rodar mais de uma vez (idempotente).
=============================================================================
HELP_TEXT
            exit 0
            ;;
        *)
            ERRO "Opção desconhecida: $arg (use --help)"
            exit 1
            ;;
    esac
done

# --- Preflight --------------------------------------------------------------
PASSO "Verificando o ambiente"

[ "$(uname -s)" = "Linux" ] || { ERRO "Este script é apenas para Linux."; exit 1; }
[ "$(uname -m)" = "x86_64" ]  || { ERRO "Arquitetura $(uname -m) não suportada (x86_64)."; exit 1; }
command -v apt-get >/dev/null 2>&1 || { ERRO "apt-get não encontrado (esperado Pop!_OS/Ubuntu/Debian)."; exit 1; }
command -v curl    >/dev/null 2>&1 || { ERRO "curl não encontrado."; exit 1; }

OK "Linux x86_64 + apt + curl"
OK "Desktop: ${XDG_CURRENT_DESKTOP:-desconhecido}"
OK "Usuário: $HOME"

# =============================================================================
# 1. DEPENDÊNCIAS DE SISTEMA
# =============================================================================
PASSO "Instalando dependências de sistema (vai pedir sua senha sudo)"

sudo apt-get update -qq

sudo apt-get install -y \
    curl \
    python3 \
    python3-gi \
    gir1.2-gtk-3.0 \
    gir1.2-gtklayershell-0.1 \
    libgtk-layer-shell0 \
    fonts-dancingscript \
    libmpv2 \
    ffmpeg

OK "Dependências instaladas"

# Confirmação rápida das duas peças críticas
python3 - <<'PYEOF'
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, GtkLayerShell  # noqa: F401
print("  \033[1;32m✓\033[0m Gtk 3.0 + GtkLayerShell carregam")
PYEOF

fc-list : family | tr ',' '\n' | grep -qi "Dancing Script" \
    && OK "Fonte cursiva 'Dancing Script' disponível" \
    || AVISO "Dancing Script não encontrada (o widget usará fallback)"

# =============================================================================
# 2. AURA — WALLPAPER ANIMADO
# =============================================================================
PASSO "Instalando o Aura (motor de wallpaper animado)"

AURA_TMP="$(mktemp -d -t aura-restore-XXXXXX)"
trap 'rm -rf "$AURA_TMP"' EXIT INT TERM

curl -fsSL https://raw.githubusercontent.com/antwny/aura/main/install.sh \
     -o "$AURA_TMP/install.sh"

bash "$AURA_TMP/install.sh" --user

command -v aura >/dev/null 2>&1 && OK "Aura instalado em ~/.local/bin/aura" \
    || { ERRO "Aura não ficou no PATH."; exit 1; }

# =============================================================================
# 3. WIDGET DE CALENDÁRIO
# =============================================================================
PASSO "Instalando o widget de calendário"

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/calendar-widget" <<'PYEOF'
#!/usr/bin/env python3
"""
calendar-widget — Widget de calendário para COSMIC Desktop (Wayland).

Mostra no canto inferior esquerdo da tela:
  • dia da semana por extenso, em português, fonte cursiva  (ex: "Sábado")
  • data no formato "01 DE NOVEMBRO DE 2026"

Usa Wayland Layer Shell (a mesma tecnologia do wallpaper animado),
ficando fixo no canto inferior esquerdo, atrás de todas as janelas
(.layer BOTTOM, como se fosse parte do papel de parede), sem moldura
de janela e sem interferir nos cliques (KeyboardMode.NONE).
"""

import gi
import datetime

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gtk, GtkLayerShell, GLib, Gdk

# ----------------------------------------------------------------------------
# Textos em português (não dependemos de locale do sistema)
# ----------------------------------------------------------------------------
DIAS_SEMANA = [
    "Domingo",
    "Segunda-feira",
    "Terça-feira",
    "Quarta-feira",
    "Quinta-feira",
    "Sexta-feira",
    "Sábado",
]

MESES = [
    "JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
    "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO",
]

# ----------------------------------------------------------------------------
# Aparência
# ----------------------------------------------------------------------------
# Fonte cursiva para o dia da semana, com fallbacks caso a principal falte.
FONTES_CURSIVAS = [
    "Dancing Script",
    "Kaushan Script",
    "Comfortaa",
    "Ubuntu",
]

COR_DIA = "#FFFFFF"
COR_DATA = "rgba(255, 255, 255, 0.82)"

CSS = f"""
.cal-root {{
    background: transparent;
    border: none;
    border-radius: 0;
}}
.cal-dia {{
    color: {COR_DIA};
    font-size: 140px;
    text-shadow: 0 4px 24px rgba(0, 0, 0, 0.85), 0 1px 4px rgba(0, 0, 0, 0.75);
}}
.cal-data {{
    color: {COR_DATA};
    font-size: 34px;
    font-weight: bold;
    letter-spacing: 6.4px;
    text-shadow: 0 3px 16px rgba(0, 0, 0, 0.85), 0 1px 3px rgba(0, 0, 0, 0.75);
}}
"""


def fonte_cursiva_disponivel():
    """Retorna a primeira fonte cursiva instalada no sistema."""
    try:
        import subprocess
        instaladas = subprocess.run(
            ["fc-list", ":", "family"],
            capture_output=True, text=True, timeout=10,
        ).stdout
        familias = {f.strip() for f in instaladas.replace(",", "\n").splitlines()}
        for nome in FONTES_CURSIVAS:
            if nome in familias:
                return nome
    except Exception:
        pass
    return FONTES_CURSIVAS[-1]


def textos_de_hoje():
    """Gera (dia_da_semana, data) para a data atual."""
    agora = datetime.datetime.now()
    # weekday(): 0=segunda..6=domingo  ->  ajustar para 0=domingo
    dia = DIAS_SEMANA[(agora.weekday() + 1) % 7]
    data = f"{agora.day:02d} DE {MESES[agora.month - 1]} DE {agora.year}"
    return dia, data


class CalendarWidget:
    def __init__(self):
        self.fonte = fonte_cursiva_disponivel()
        self._ultimo = None

        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_title("Calendar Widget")
        self.win.set_app_paintable(True)
        self.win.set_resizable(False)
        self.win.set_decorated(False)

        # Fundo transparente de verdade (necessário em GTK3 sobre Wayland)
        visual = self.win.get_screen().get_rgba_visual()
        if visual is not None and self.win.get_screen().is_composited():
            self.win.set_visual(visual)

        # --- Layer Shell: fixo no canto inferior esquerdo ---
        # Layer BOTTOM: acima do wallpaper (BACKGROUND), porém ATRÁS de
        # todas as janelas -> o texto parece parte do papel de parede.
        # (OVERLAY ficaria por cima dos aplicativos; TOP por cima das janelas
        #  e na mesma altura do dock.)
        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT, True)
        # Margem inferior folgada para não nascer em cima do dock (que fica
        # ancorado na borda inferior do COSMIC).
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.BOTTOM, 96)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.LEFT, 44)
        # -1 => não reserva espaço e não é empurrado por zonas exclusivas
        GtkLayerShell.set_exclusive_zone(self.win, -1)
        # Não captura teclado/cliques: passa direto pra janela de baixo
        try:
            GtkLayerShell.set_keyboard_mode(
                self.win, GtkLayerShell.KeyboardMode.NONE
            )
        except AttributeError:
            GtkLayerShell.set_keyboard_interactivity(self.win, False)

        # --- Conteúdo ---
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.box.set_valign(Gtk.Align.CENTER)
        self.box.set_halign(Gtk.Align.CENTER)
        self.box.set_margin_top(18)
        self.box.set_margin_bottom(18)
        self.box.set_margin_start(30)
        self.box.set_margin_end(30)
        self.box.get_style_context().add_class("cal-root")

        self.lbl_dia = Gtk.Label()
        self.lbl_dia.set_halign(Gtk.Align.CENTER)
        self.lbl_dia.get_style_context().add_class("cal-dia")

        self.lbl_data = Gtk.Label()
        self.lbl_data.set_halign(Gtk.Align.CENTER)
        self.lbl_data.get_style_context().add_class("cal-data")

        self.box.pack_start(self.lbl_dia, False, False, 0)
        self.box.pack_start(self.lbl_data, False, False, 6)
        self.win.add(self.box)

        self._aplicar_css()
        self.atualizar()

        self.win.connect("destroy", Gtk.main_quit)
        self.win.show_all()

        # Checa a cada 20s; só redesenha se o texto mudou (vira o relógio
        # da meia-noite pra frente sem custo).
        GLib.timeout_add_seconds(20, self._tick)

    def _aplicar_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def atualizar(self):
        dia, data = textos_de_hoje()
        if (dia, data) == self._ultimo:
            return
        self._ultimo = (dia, data)

        # Fonte cursiva via markup Pango (escapando nada: textos são nossos)
        self.lbl_dia.set_markup(
            f'<span font_desc="{self.fonte} 140">{dia}</span>'
        )
        self.lbl_data.set_markup(f'<span font_desc="Ubuntu 34">{data}</span>')
        self.win.resize(1, 1)

    def _tick(self):
        self.atualizar()
        return True  # mantém o timer vivo

    def run(self):
        Gtk.main()


if __name__ == "__main__":
    CalendarWidget().run()
PYEOF

chmod +x "$HOME/.local/bin/calendar-widget"

# Garante que o binário do Aura também esteja em ~/.local/bin (o instalador
# do Aura coloca lá; só garantimos que o PATH do usuário o alcance)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) OK "~/.local/bin já está no PATH" ;;
    *)
        AVISO "~/.local/bin fora do PATH — adicionando ao ~/.bashrc"
        grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null || \
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        ;;
esac

OK "Widget instalado em ~/.local/bin/calendar-widget"

# =============================================================================
# 4. CONFIGURAÇÃO DO AURA (auto_pause DESLIGADO, smart_pause LIGADO)
# =============================================================================
PASSO "Aplicando a configuração do Aura"

python3 - <<'PYEOF'
import json
import os
from pathlib import Path

cfg_path = Path.home() / ".config" / "aura" / "config.json"

# Configuração conhecida-bom (schema Aura v1.9.2). Usada só se o arquivo
# ainda não existir (instalação fresca).
config_padrao = {
    "version": "1.9.2",
    "current": "",
    "wallpapers": {},
    "dirs": [os.path.expanduser("~/Imagens/Wallpapers/Aura")],
    "custom_videos": [],
    "output": "*",
    "scaling": {},
    "auto_theme": True,
    "auto_dark": True,
    "theme_mode": "auto",
    "rotation": False,
    "interval": 30,
    "order": "random",
    "seq_index": 0,
    "mute": True,
    "volume": 100,
    "hwdec": "auto-safe",
    "gpu_preference": "auto",
    "smart_pause": True,
    "auto_pause": False,
    "auto_pause_mode": "partial",
    "pause_on_battery": False,
    "keep_running_on_close": True,
    "autostart": False,
    "language": "pt",
    "favorites": [],
    "library_sort": "newest",
    "rotation_only_favorites": False,
    "rotation_media_filter": "all",
    "backend": "auto",
    "tray_click_action": "switcher",
    "switcher_only_favorites": False,
    "switcher_position": "top",
    "switcher_style": "honeycomb",
    "window_width": 1920.0,
    "window_height": 976.0,
    "window_x": None,
    "window_y": None,
    "dms_underlay_sync": True,
    "monitor_order": [],
}

if cfg_path.exists():
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    origem = "config existente (preservado)"
else:
    cfg = dict(config_padrao)
    origem = "config novo (criado do zero)"

# --- Os dois ajustes que importam ---
# auto_pause = False  -> o vídeo NÃO pausa ao abrir janelas em grade
#                         (importante no COSMIC, que é tiling por padrão)
# smart_pause = True  -> continua pausando em jogo fullscreen e tela bloqueada
cfg["auto_pause"] = False
cfg["smart_pause"] = True
cfg["auto_pause_mode"] = "partial"

cfg_path.parent.mkdir(parents=True, exist_ok=True)
cfg_path.write_text(
    json.dumps(cfg, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

# Garante que a pasta de wallpapers exista
wall_dir = Path.home() / "Imagens" / "Wallpapers" / "Aura"
wall_dir.mkdir(parents=True, exist_ok=True)

print(f"  \033[1;32m✓\033[0m auto_pause=False, smart_pause=True  ({origem})")
print(f"  \033[1;32m✓\033[0m Pasta de wallpapers: {wall_dir}")
PYEOF

# =============================================================================
# 5. AUTOSTART (padrão; desative com --no-autostart)
# =============================================================================
if [ "$COM_AUTOSTART" -eq 1 ]; then
    PASSO "Configurando autostart do widget"
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/calendar-widget.desktop" <<DEEOF
[Desktop Entry]
Type=Application
Name=Calendar Widget
GenericName=Widget de calendário
Comment=Canto inferior esquerdo: dia da semana e data por extenso
Exec=$HOME/.local/bin/calendar-widget
Icon=calendar
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
DEEOF
    OK "Autostart criado (~/.config/autostart/calendar-widget.desktop)"
else
    AVISO "Autostart desativado (--no-autostart): o widget NÃO voltará no login"
fi

# =============================================================================
# 6. VERIFICAÇÃO FINAL
# =============================================================================
PASSO "Verificando a instalação"

# 6.1 Sintaxe do widget
python3 -m py_compile "$HOME/.local/bin/calendar-widget" \
    && OK "Widget compila sem erro" \
    || { ERRO "Widget com erro de sintaxe."; exit 1; }

# 6.2 Aura responde
"$HOME/.local/bin/aura" --version >/dev/null 2>&1 \
    && OK "Aura responde ($("$HOME/.local/bin/aura" --version 2>&1 | head -1))" \
    || ERRO "Aura não respondeu"

# 6.3 mpvpaper carrega as bibliotecas
if [ -x "$HOME/.local/bin/mpvpaper" ]; then
    "$HOME/.local/bin/mpvpaper" -h >/dev/null 2>&1 \
        && OK "mpvpaper carrega as libs de vídeo" \
        || AVISO "mpvpaper não carrega (rode: sudo apt install -y libmpv2)"
fi

# 6.4 Config do Aura válido
python3 -c "
import json, pathlib
c = json.loads((pathlib.Path.home()/'.config/aura/config.json').read_text())
assert c['auto_pause'] is False, 'auto_pause deveria ser False'
assert c['smart_pause'] is True, 'smart_pause deveria ser True'
print('  \033[1;32m✓\033[0m Config do Aura válido (auto_pause=False, smart_pause=True)')
" || ERRO "Config do Aura inválido"

# 6.5 Fonte cursiva
fc-list : family | tr ',' '\n' | grep -qi "Dancing Script" \
    && OK "Fonte cursiva instalada" \
    || AVISO "Fonte cursiva ausente"

# =============================================================================
printf '\n%s════════════════════════════════════════════════════════%s\n' "$c_azul" "$c_reset"
printf '%s✨ Restauração concluída!%s\n\n' "$c_verde" "$c_reset"
printf 'Para usar agora:\n'
printf '  • Widget:   %s~/.local/bin/calendar-widget%s  (inicia sozinho no login)\n' "$c_azul" "$c_reset"
printf '  • Wallpaper:%saura%s  -> escolha um vídeo/papel na interface\n' "$c_azul" "$c_reset"
printf '  • Trocar:   %saura next%s      • Pausar: %saura toggle-pause%s\n' \
       "$c_azul" "$c_reset" "$c_azul" "$c_reset"
printf '\nObs: o wallpaper anterior não é restaurado (arquivos de vídeo\n'
printf 'não fazem backup). Basta arrastar seus vídeos para:\n'
printf '  ~/Imagens/Wallpapers/Aura\n'
printf '%s════════════════════════════════════════════════════════%s\n' "$c_azul" "$c_reset"
