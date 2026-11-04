#!/usr/bin/env bash
#
# instalar-widget-calendario.sh
# =============================================================================
# Instalador do widget de calendário (aplicativo isolado, sem Aura).
#
# Instala, a partir dos arquivos desta pasta:
#   • ~/.local/bin/calendar-widget            (widget)
#   • ~/.local/bin/calendar-widget-config     (configurador gráfico)
#   • ~/.config/calendar-widget/config.ini    (criado só se não existir)
#   • ~/.local/share/applications/calendar-widget-config.desktop
#         -> atalho "Calendário — Ajustes" no menu de aplicativos
#   • ~/.config/autostart/calendar-widget.desktop  (opcional)
#
# Uso:
#   bash instalar-widget-calendario.sh                  # instala e inicia
#   bash instalar-widget-calendario.sh --no-autostart   # sem autostart
#   bash instalar-widget-calendario.sh --sem-iniciar    # não abre o widget
#   bash instalar-widget-calendario.sh --help
#
# Idempotente: rodar de novo atualiza os arquivos e mantém sua configuração,
# o atalho e o autostart. Para backup, basta guardar esta pasta (clone/zip).
# =============================================================================

set -euo pipefail

c_azul=$'\033[1;34m'; c_verde=$'\033[1;32m'
c_amarelo=$'\033[1;33m'; c_vermelho=$'\033[1;31m'; c_reset=$'\033[0m'

PASSO() { printf '\n%s==> %s%s\n' "$c_azul" "$1" "$c_reset"; }
OK()    { printf '  %s✓%s %s\n' "$c_verde" "$c_reset" "$1"; }
AVISO() { printf '  %s!%s %s\n' "$c_amarelo" "$c_reset" "$1"; }
ERRO()  { printf '  %s✗%s %s\n' "$c_vermelho" "$c_reset" "$1" >&2; }

COM_AUTOSTART=1
COM_INICIO=1

for arg in "$@"; do
    case "$arg" in
        --autostart)     COM_AUTOSTART=1 ;;
        --no-autostart)  COM_AUTOSTART=0 ;;
        --sem-iniciar)   COM_INICIO=0 ;;
        -h|--help)
            cat <<'HELP_TEXT'
instalar-widget-calendario.sh
=============================================================================
Instala o widget de calendário e o configurador gráfico deste projeto,
criando o atalho "Calendário — Ajustes" no menu de aplicativos.

Uso:
  bash instalar-widget-calendario.sh
  bash instalar-widget-calendario.sh --no-autostart
  bash instalar-widget-calendario.sh --sem-iniciar

Opções:
  --autostart      (padrão) o widget inicia sozinho no login
  --no-autostart   não cria o autostart do widget
  --sem-iniciar    não abre o widget ao terminar a instalação
  -h, --help       mostra esta ajuda

Arquivos instalados:
  ~/.local/bin/calendar-widget
  ~/.local/bin/calendar-widget-config
  ~/.config/calendar-widget/config.ini
  ~/.local/share/applications/calendar-widget-config.desktop
  ~/.config/autostart/calendar-widget.desktop          (se houver autostart)
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

# --- Origem: os arquivos ao lado deste script --------------------------------
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_SRC="$DIR/calendar-widget"
CONFIG_SRC="$DIR/calendar-widget-config"
DESKTOP_SRC="$DIR/calendar-widget-config.desktop"

PASSO "Verificando os arquivos do projeto"
for arquivo in "$WIDGET_SRC" "$CONFIG_SRC" "$DESKTOP_SRC"; do
    if [ -f "$arquivo" ]; then
        OK "$(basename "$arquivo")"
    else
        ERRO "Faltando: $arquivo"
        ERRO "Rode este script dentro da pasta do projeto (git clone/zip completo)."
        exit 1
    fi
done

# --- Dependências ------------------------------------------------------------
PASSO "Verificando dependências"
FALTANDO=0

if python3 -c 'import gi; gi.require_version("Gtk", "3.0"); gi.require_version("GtkLayerShell", "0.1"); from gi.repository import Gtk, GtkLayerShell' 2>/dev/null; then
    OK "python3-gi + gtk-layer-shell"
else
    ERRO "python3-gi e/ou gtk-layer-shell ausentes"
    FALTANDO=1
fi

if command -v fc-list >/dev/null 2>&1; then
    OK "fontconfig (fc-list)"
else
    AVISO "fc-list ausente — o widget não consegue checar fontes"
fi

if [ "$FALTANDO" -eq 1 ]; then
    printf '\nInstale as dependências e rode de novo:\n'
    printf '  %ssudo apt install -y gir1.2-gtklayershell-0.1 libgtk-layer-shell0 \\\n' "$c_azul"
    printf '      python3-gi fonts-dancingscript%s\n' "$c_reset"
    exit 1
fi

if fc-list : family 2>/dev/null | tr ',' '\n' | grep -qi "Dancing Script"; then
    OK "Fonte cursiva (Dancing Script)"
else
    AVISO "Dancing Script ausente — use outra fonte no configurador"
fi

# --- Binários ----------------------------------------------------------------
PASSO "Instalando o widget e o configurador"
mkdir -p "$HOME/.local/bin"
install -m 755 "$WIDGET_SRC"  "$HOME/.local/bin/calendar-widget"
install -m 755 "$CONFIG_SRC"  "$HOME/.local/bin/calendar-widget-config"
OK "~/.local/bin/calendar-widget"
OK "~/.local/bin/calendar-widget-config"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) OK "~/.local/bin já está no PATH" ;;
    *)
        AVISO "~/.local/bin fora do PATH — adicionando ao ~/.bashrc"
        if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        fi
        ;;
esac

# --- Configuração ------------------------------------------------------------
PASSO "Configuração"
CONFIG_WIDGET="$HOME/.config/calendar-widget/config.ini"
if [ -f "$CONFIG_WIDGET" ]; then
    OK "Mantida a configuração existente ($CONFIG_WIDGET)"
else
    mkdir -p "$(dirname "$CONFIG_WIDGET")"
    if CALENDAR_WIDGET_CONFIG="$CONFIG_WIDGET" python3 - >/dev/null 2>&1 <<'PYEOF'
import os
import pathlib
from importlib.machinery import SourceFileLoader
import importlib.util

caminho = pathlib.Path(os.environ["HOME"]) / ".local" / "bin" / "calendar-widget"
loader = SourceFileLoader("calendar_widget_base", str(caminho))
spec = importlib.util.spec_from_loader(loader.name, loader)
modulo = importlib.util.module_from_spec(spec)
loader.exec_module(modulo)
modulo.salvar_config(modulo.carregar_config())
PYEOF
    then
        OK "Configuração padrão criada ($CONFIG_WIDGET)"
    else
        AVISO "Sem config pronta — o widget cria os padrões no primeiro uso"
    fi
fi

# --- Atalho no menu ----------------------------------------------------------
PASSO "Criando o atalho no menu de aplicativos"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/calendar-widget-config.desktop" <<DEEOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Calendário — Ajustes
GenericName=Widget de calendário
Comment=Ajusta posição, fonte e tamanhos do widget de calendário
Exec=$HOME/.local/bin/calendar-widget-config
Icon=x-office-calendar
Terminal=false
StartupNotify=true
Categories=Settings;DesktopSettings;
Keywords=calendario;widget;fonte;tamanho;posicao;ajustes;
DEEOF
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi
OK "Atalho \"Calendário — Ajustes\" (menu de aplicativos)"

# --- Autostart ---------------------------------------------------------------
if [ "$COM_AUTOSTART" -eq 1 ]; then
    PASSO "Configurando o autostart"
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/calendar-widget.desktop" <<DEEOF
[Desktop Entry]
Type=Application
Name=Calendar Widget
GenericName=Widget de calendário
Comment=Dia da semana e data por extenso, atrás das janelas
Exec=$HOME/.local/bin/calendar-widget
Icon=x-office-calendar
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
DEEOF
    OK "~/.config/autostart/calendar-widget.desktop"
else
    AVISO "Autostart não criado (--no-autostart)"
fi

# --- Verificação -------------------------------------------------------------
PASSO "Verificando a instalação"
python3 -m py_compile "$HOME/.local/bin/calendar-widget" \
    "$HOME/.local/bin/calendar-widget-config" \
    && OK "Widget e configurador compilam sem erro" \
    || { ERRO "Erro de sintaxe nos arquivos instalados."; exit 1; }
rm -rf "$HOME/.local/bin/__pycache__"

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$HOME/.local/share/applications/calendar-widget-config.desktop" \
        >/dev/null 2>&1 \
        && OK "Atalho do menu válido" \
        || AVISO "desktop-file-validate não validou o atalho"
fi

# --- Iniciar agora -----------------------------------------------------------
if [ "$COM_INICIO" -eq 1 ]; then
    PASSO "Iniciando o widget"
    if pgrep -f "bin/calendar-widget$" >/dev/null 2>&1; then
        pkill -f "bin/calendar-widget$" || true
        sleep 1
        OK "Instância anterior encerrada"
    fi
    setsid "$HOME/.local/bin/calendar-widget" >/dev/null 2>&1 &
    sleep 1
    if pgrep -f "bin/calendar-widget$" >/dev/null 2>&1; then
        OK "Widget rodando"
    else
        AVISO "O widget não confirmou a subida — rode: calendar-widget"
    fi
fi

# =============================================================================
printf '\n%s════════════════════════════════════════════════════════%s\n' "$c_azul" "$c_reset"
printf '%s✨ Widget de calendário instalado!%s\n\n' "$c_verde" "$c_reset"
printf 'Como usar:\n'
printf '  • Ajustes:  %sCalendário — Ajustes%s no menu de aplicativos\n' "$c_azul" "$c_reset"
printf '              ou %scalendar-widget-config%s no terminal\n' "$c_azul" "$c_reset"
printf '  • Config:   %s%s%s\n' "$c_azul" "$CONFIG_WIDGET" "$c_reset"
printf '  • Widget:   %s~/.local/bin/calendar-widget%s\n' "$c_azul" "$c_reset"
printf '\nBackup: guarde a pasta do projeto (clone/zip) e rode este script\n'
printf 'de novo depois de formatar — sua config em ~/.config/calendar-widget/\n'
printf 'também vale a pena copiar.\n'
printf '%s════════════════════════════════════════════════════════%s\n' "$c_azul" "$c_reset"
