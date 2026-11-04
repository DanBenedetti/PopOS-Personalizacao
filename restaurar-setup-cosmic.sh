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
#      dia da semana cursivo em pt-BR + data "01 DE NOVEMBRO DE 2026",
#      com configurador gráfico (calendar-widget-config) e config em
#      ~/.config/calendar-widget/config.ini
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
     dia da semana cursivo em pt-BR + data "01 DE NOVEMBRO DE 2026",
     com configurador gráfico (calendar-widget-config) e config em
     ~/.config/calendar-widget/config.ini
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

Mostra no canto inferior da tela:
  • dia da semana por extenso, em português, fonte cursiva  (ex: "Sábado")
  • data no formato "01 DE NOVEMBRO DE 2026"

Usa Wayland Layer Shell (a mesma tecnologia do wallpaper animado),
ficando fixo no canto, atrás de todas as janelas (.layer BOTTOM, como se
fosse parte do papel de parede), sem moldura de janela e sem interferir
nos cliques (KeyboardMode.NONE).

Personalização (posição, fonte, tamanhos) em:
    ~/.config/calendar-widget/config.ini
O arquivo é criado com os valores padrão na primeira execução. Para editar
sem mexer no arquivo, use o configurador gráfico `calendar-widget-config`.
"""

import configparser
import datetime
import os
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

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

COR_DIA = "#FFFFFF"
COR_DATA = "rgba(255, 255, 255, 0.82)"

# Reservas usadas só quando a fonte pedida não estiver instalada.
RESERVAS_DIA = ["Dancing Script", "Kaushan Script", "Comfortaa", "Ubuntu", "Sans"]
RESERVAS_DATA = ["Ubuntu", "DejaVu Sans", "Sans"]

# ----------------------------------------------------------------------------
# Configuração
# ----------------------------------------------------------------------------
CAMINHO_CONFIG = Path(
    os.environ.get("CALENDAR_WIDGET_CONFIG", "~/.config/calendar-widget/config.ini")
).expanduser()

PADROES = {
    "posicao": {
        "ancora_horizontal": "esquerda",  # esquerda | direita
        "margem_lateral": 44,             # distância da borda lateral (px)
        "margem_inferior": 56,            # distância do rodapé (px) — menor = mais baixo
    },
    "texto": {
        "fonte_dia": "Dancing Script",
        "tamanho_dia": 140,
        "fonte_data": "Ubuntu",
        "tamanho_data": 34,
        "espacamento": 6,                 # espaço entre as duas linhas (px)
    },
}

# Faixas aceitas: valores fora delas são cortados para o limite.
LIMITES = {
    ("posicao", "margem_lateral"): (0, 2000),
    ("posicao", "margem_inferior"): (0, 2000),
    ("texto", "tamanho_dia"): (8, 500),
    ("texto", "tamanho_data"): (6, 500),
    ("texto", "espacamento"): (0, 200),
}

ANCORAS = ("esquerda", "direita")

MODELO_CONFIG = """\
# calendar-widget — configuração
# Edite e reinicie o widget, ou use o configurador gráfico:
#     calendar-widget-config
# Todos os valores numéricos estão em pixels.

[posicao]
# Borda onde o widget se apoia: esquerda | direita
ancora_horizontal = {ancora_horizontal}
# Distância da borda lateral escolhida acima
margem_lateral = {margem_lateral}
# Distância do rodapé da tela — menor deixa o widget mais baixo
margem_inferior = {margem_inferior}

[texto]
# Nome exato da família da fonte (confira com: fc-list : family)
fonte_dia = {fonte_dia}
# Tamanho da fonte do dia da semana
tamanho_dia = {tamanho_dia}
# Fonte e tamanho da linha da data
fonte_data = {fonte_data}
tamanho_data = {tamanho_data}
# Espaço entre o dia da semana e a data
espacamento = {espacamento}
"""


def _como_int(valor, padrao, limites):
    """Converte para inteiro; em caso de lixo, usa o padrão."""
    try:
        numero = int(str(valor).strip())
    except (TypeError, ValueError):
        return padrao
    minimo, maximo = limites
    return max(minimo, min(maximo, numero))


def carregar_config(caminho=None):
    """Lê o config.ini; qualquer valor ausente/inválido cai no padrão."""
    caminho = Path(caminho).expanduser() if caminho else CAMINHO_CONFIG
    config = {secao: dict(chaves) for secao, chaves in PADROES.items()}

    parser = configparser.ConfigParser()
    try:
        lido = parser.read(caminho, encoding="utf-8")
    except (configparser.Error, OSError) as erro:
        print(
            f"calendar-widget: não consegui ler {caminho} ({erro}); usando padrões",
            file=sys.stderr,
        )
        return config

    if not lido:
        return config

    for secao, chaves in PADROES.items():
        if not parser.has_section(secao):
            continue
        for chave, padrao in chaves.items():
            bruto = parser.get(secao, chave, fallback=None)
            if bruto is None:
                continue
            if isinstance(padrao, int):
                limites = LIMITES.get((secao, chave), (0, 100000))
                config[secao][chave] = _como_int(bruto, padrao, limites)
            else:
                valor = bruto.strip().strip('"').strip("'")
                config[secao][chave] = valor or padrao

    ancora = str(config["posicao"]["ancora_horizontal"]).lower()
    config["posicao"]["ancora_horizontal"] = (
        ancora if ancora in ANCORAS else PADROES["posicao"]["ancora_horizontal"]
    )
    return config


def salvar_config(config, caminho=None):
    """Grava o config.ini (com comentários) e devolve o caminho usado."""
    caminho = Path(caminho).expanduser() if caminho else CAMINHO_CONFIG
    caminho.parent.mkdir(parents=True, exist_ok=True)
    valores = {
        **config["posicao"],
        **config["texto"],
    }
    caminho.write_text(MODELO_CONFIG.format(**valores), encoding="utf-8")
    return caminho


# ----------------------------------------------------------------------------
# Fontes
# ----------------------------------------------------------------------------
def familias_instaladas():
    """Conjunto com as famílias que o sistema tem (vazio se fc-list faltar)."""
    try:
        saida = subprocess.run(
            ["fc-list", ":", "family"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return set()

    familias = set()
    for linha in saida.splitlines():
        for nome in linha.split(","):
            nome = nome.strip()
            if nome:
                familias.add(nome)
    return familias


def resolver_fonte(pedida, reservas, instaladas):
    """Devolve a fonte pedida se existir; senão a primeira reserva instalada."""
    if not instaladas:
        # Sem fc-list não dá para checar: confia na configuração.
        return pedida

    por_nome = {familia.lower(): familia for familia in instaladas}
    for candidata in [pedida] + list(reservas):
        if not candidata:
            continue
        achada = por_nome.get(candidata.lower())
        if achada:
            return achada
    return "Sans"


def montar_css(texto):
    """CSS gerado a partir dos tamanhos configurados."""
    return f"""
.cal-root {{
    background: transparent;
    border: none;
    border-radius: 0;
}}
.cal-dia {{
    color: {COR_DIA};
    font-size: {texto["tamanho_dia"]}px;
    text-shadow: 0 4px 24px rgba(0, 0, 0, 0.85), 0 1px 4px rgba(0, 0, 0, 0.75);
}}
.cal-data {{
    color: {COR_DATA};
    font-size: {texto["tamanho_data"]}px;
    font-weight: bold;
    letter-spacing: 6.4px;
    text-shadow: 0 3px 16px rgba(0, 0, 0, 0.85), 0 1px 3px rgba(0, 0, 0, 0.75);
}}
"""


def textos_de_hoje():
    """Gera (dia_da_semana, data) para a data atual."""
    agora = datetime.datetime.now()
    # weekday(): 0=segunda..6=domingo  ->  ajustar para 0=domingo
    dia = DIAS_SEMANA[(agora.weekday() + 1) % 7]
    data = f"{agora.day:02d} DE {MESES[agora.month - 1]} DE {agora.year}"
    return dia, data


class CalendarWidget:
    def __init__(self, config=None, caminho_config=None):
        self.caminho_config = (
            Path(caminho_config).expanduser() if caminho_config else CAMINHO_CONFIG
        )
        self.config = config or carregar_config(self.caminho_config)
        self.texto = self.config["texto"]
        posicao = self.config["posicao"]

        instaladas = familias_instaladas()
        self.fonte_dia = resolver_fonte(
            self.texto["fonte_dia"], RESERVAS_DIA, instaladas
        )
        self.fonte_data = resolver_fonte(
            self.texto["fonte_data"], RESERVAS_DATA, instaladas
        )
        for pedida, usada in (
            (self.texto["fonte_dia"], self.fonte_dia),
            (self.texto["fonte_data"], self.fonte_data),
        ):
            if pedida.lower() != usada.lower():
                print(
                    f"calendar-widget: fonte '{pedida}' não instalada; "
                    f"usando '{usada}'",
                    file=sys.stderr,
                )

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

        # --- Layer Shell: fixo no canto inferior ---
        # Layer BOTTOM: acima do wallpaper (BACKGROUND), porém ATRÁS de
        # todas as janelas -> o texto parece parte do papel de parede.
        # (OVERLAY ficaria por cima dos aplicativos; TOP por cima das janelas
        #  e na mesma altura do dock.)
        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM, True)
        if posicao["ancora_horizontal"] == "direita":
            GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.RIGHT, True)
            borda_lateral = GtkLayerShell.Edge.RIGHT
        else:
            GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT, True)
            borda_lateral = GtkLayerShell.Edge.LEFT
        # Margem inferior maior = widget mais alto na tela.
        GtkLayerShell.set_margin(
            self.win, GtkLayerShell.Edge.BOTTOM, posicao["margem_inferior"]
        )
        GtkLayerShell.set_margin(
            self.win, borda_lateral, posicao["margem_lateral"]
        )
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
        self.box.pack_start(
            self.lbl_data, False, False, self.texto["espacamento"]
        )
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
        provider.load_from_data(montar_css(self.texto).encode("utf-8"))
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

        # Fonte via markup Pango (escapando o nome: vem da configuração)
        fonte_dia = GLib.markup_escape_text(self.fonte_dia, -1)
        fonte_data = GLib.markup_escape_text(self.fonte_data, -1)
        self.lbl_dia.set_markup(
            f'<span font_desc="{fonte_dia} {self.texto["tamanho_dia"]}">{dia}</span>'
        )
        self.lbl_data.set_markup(
            f'<span font_desc="{fonte_data} {self.texto["tamanho_data"]}">{data}</span>'
        )
        self.win.resize(1, 1)

    def _tick(self):
        self.atualizar()
        return True  # mantém o timer vivo

    def run(self):
        Gtk.main()


if __name__ == "__main__":
    # Primeira execução: cria o config.ini para o arquivo ficar descobrível
    # e editável à mão.
    if not CAMINHO_CONFIG.exists():
        try:
            salvar_config(carregar_config())
        except OSError as erro:
            print(
                f"calendar-widget: não consegui criar {CAMINHO_CONFIG} ({erro})",
                file=sys.stderr,
            )
    CalendarWidget().run()
PYEOF

cat > "$HOME/.local/bin/calendar-widget-config" <<'PYEOF'
#!/usr/bin/env python3
"""
calendar-widget-config — configurador gráfico do calendar-widget.

Janela GTK3 para ajustar o widget sem editar arquivos:
  • posição: borda lateral (esquerda/direita) e margens
  • texto: fonte e tamanho do dia da semana e da data, espaço entre linhas
  • prévia de uma tela 1920x1080 mostrando onde o texto vai cair

Ao aplicar, grava ~/.config/calendar-widget/config.ini e reinicia o widget.
Também dá para editar o arquivo à mão — este configurador apenas lê e
escreve nele (mesmas chaves, mesmos padrões).
"""

import importlib.util
import os
from importlib.machinery import SourceFileLoader
import signal
import subprocess
import sys
import time
from pathlib import Path

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")

from gi.repository import Gdk, GLib, Gtk, Pango

AQUI = Path(__file__).resolve().parent
NOME_WIDGET = "calendar-widget"

# Mapa da tela usado na prévia (proporcional a 1920x1080).
LARGURA_MAPA = 560
ALTURA_MAPA = 260
FATOR = LARGURA_MAPA / 1920


# ----------------------------------------------------------------------------
# Localizar e carregar o código do widget (padrões + leitura/escrita do config)
# ----------------------------------------------------------------------------
def achar_widget():
    for candidato in (
        AQUI / NOME_WIDGET,
        Path.home() / ".local" / "bin" / NOME_WIDGET,
    ):
        if candidato.is_file():
            return candidato
    return None


def carregar_modulo_widget(caminho):
    # O arquivo do widget não tem extensão .py, então o loader é explícito.
    loader = SourceFileLoader("calendar_widget_base", str(caminho))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    modulo = importlib.util.module_from_spec(spec)
    loader.exec_module(modulo)
    return modulo


def pids_do_widget():
    """PIDs de processos do widget (sem pegar este configurador)."""
    encontrados = []
    proprio = os.getpid()
    for entrada in os.listdir("/proc"):
        if not entrada.isdigit() or int(entrada) == proprio:
            continue
        try:
            bruto = Path(f"/proc/{entrada}/cmdline").read_bytes()
        except OSError:
            continue
        argumentos = [p.decode("utf-8", "replace") for p in bruto.split(b"\0") if p]
        if not argumentos:
            continue
        # cobre "python3 /caminho/calendar-widget" e execução direta
        if any(os.path.basename(a) == NOME_WIDGET for a in argumentos[:2]):
            encontrados.append(int(entrada))
    return encontrados


class JanelaConfig(Gtk.Window):
    def __init__(self, caminho_widget, modulo):
        super().__init__(title="Calendário — Ajustes")
        self.caminho_widget = caminho_widget
        self.modulo = modulo
        self.config = modulo.carregar_config()
        self._atualizando = False

        self.set_default_size(620, -1)
        self.set_border_width(18)

        caixa = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.add(caixa)

        caixa.pack_start(self._construir_previa(), False, False, 0)
        caixa.pack_start(self._construir_posicao(), False, False, 0)
        caixa.pack_start(self._construir_texto(), False, False, 0)

        rodape = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.lbl_status = Gtk.Label(label="")
        self.lbl_status.set_xalign(0)
        self.lbl_status.set_line_wrap(True)
        self.lbl_status.get_style_context().add_class("dim-label")

        self.btn_salvar = Gtk.Button(label="Aplicar")
        self.btn_salvar.get_style_context().add_class("suggested-action")

        fechar = Gtk.Button(label="Fechar")

        rodape.pack_start(self.lbl_status, True, True, 0)
        rodape.pack_start(self.btn_salvar, False, False, 0)
        rodape.pack_start(fechar, False, False, 0)
        caixa.pack_start(rodape, False, False, 0)

        self.btn_salvar.connect("clicked", self._aplicar)
        fechar.connect("clicked", lambda *_: self.close())

        self._preencher_campos()
        self.connect("destroy", Gtk.main_quit)

    # -- construção da interface ------------------------------------------
    def _construir_previa(self):
        moldura = Gtk.Frame(label="Prévia (tela 1920×1080)")

        self.mapa = Gtk.Fixed()
        self.mapa.set_size_request(LARGURA_MAPA, ALTURA_MAPA)
        self.mapa.get_style_context().add_class("mapa-tela")
        moldura.add(self.mapa)

        self.float_previa = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.lbl_prev_dia = Gtk.Label()
        self.lbl_prev_data = Gtk.Label()
        self.float_previa.pack_start(self.lbl_prev_dia, False, False, 0)
        self.float_previa.pack_start(self.lbl_prev_data, False, False, 0)
        self.mapa.put(self.float_previa, 0, 0)

        return moldura

    def _construir_posicao(self):
        moldura = Gtk.Frame(label="Posição")
        grade = Gtk.Grid(row_spacing=8, column_spacing=12)
        grade.set_border_width(10)
        moldura.add(grade)

        self.radio_esq = Gtk.RadioButton.new_with_label_from_widget(
            None, "Borda esquerda"
        )
        self.radio_dir = Gtk.RadioButton.new_with_label_from_widget(
            self.radio_esq, "Borda direita"
        )
        grade.attach(self.radio_esq, 0, 0, 2, 1)
        grade.attach(self.radio_dir, 2, 0, 2, 1)

        grade.attach(Gtk.Label(label="Margem lateral (px):", xalign=0), 0, 1, 2, 1)
        self.spin_margem_lateral = Gtk.SpinButton.new_with_range(0, 2000, 2)
        grade.attach(self.spin_margem_lateral, 2, 1, 2, 1)

        grade.attach(Gtk.Label(label="Margem inferior (px):", xalign=0), 0, 2, 2, 1)
        self.spin_margem_inferior = Gtk.SpinButton.new_with_range(0, 2000, 2)
        grade.attach(self.spin_margem_inferior, 2, 2, 2, 1)

        dica = Gtk.Label(
            label="Margem inferior menor = widget mais perto do rodapé.",
            xalign=0,
        )
        dica.get_style_context().add_class("dim-label")
        grade.attach(dica, 0, 3, 4, 1)

        for radio in (self.radio_esq, self.radio_dir):
            radio.connect("toggled", self._atualizar_previa)
        for spin in (self.spin_margem_lateral, self.spin_margem_inferior):
            spin.connect("value-changed", self._atualizar_previa)
        return moldura

    def _construir_texto(self):
        moldura = Gtk.Frame(label="Texto")
        grade = Gtk.Grid(row_spacing=8, column_spacing=12)
        grade.set_border_width(10)
        moldura.add(grade)

        grade.attach(Gtk.Label(label="Dia da semana:", xalign=0), 0, 0, 1, 1)

        self.btn_fonte_dia = Gtk.FontButton()
        self.btn_fonte_dia.set_use_font(True)
        self.btn_fonte_dia.set_use_size(False)
        self.btn_fonte_dia.set_title("Fonte do dia da semana")
        grade.attach(self.btn_fonte_dia, 1, 0, 1, 1)

        self.spin_tam_dia = Gtk.SpinButton.new_with_range(8, 500, 2)
        self.spin_tam_dia.set_tooltip_text("Tamanho da fonte do dia da semana")
        grade.attach(self.spin_tam_dia, 2, 0, 1, 1)

        grade.attach(Gtk.Label(label="Data:", xalign=0), 0, 1, 1, 1)

        self.btn_fonte_data = Gtk.FontButton()
        self.btn_fonte_data.set_use_font(True)
        self.btn_fonte_data.set_use_size(False)
        self.btn_fonte_data.set_title("Fonte da data")
        grade.attach(self.btn_fonte_data, 1, 1, 1, 1)

        self.spin_tam_data = Gtk.SpinButton.new_with_range(6, 500, 2)
        self.spin_tam_data.set_tooltip_text("Tamanho da fonte da data")
        grade.attach(self.spin_tam_data, 2, 1, 1, 1)

        grade.attach(Gtk.Label(label="Espaço entre linhas:", xalign=0), 0, 2, 1, 1)
        self.spin_espaco = Gtk.SpinButton.new_with_range(0, 200, 2)
        grade.attach(self.spin_espaco, 1, 2, 1, 1)

        self.btn_padroes = Gtk.Button(label="Restaurar padrões")
        grade.attach(self.btn_padroes, 2, 2, 1, 1)

        for controle in (self.btn_fonte_dia, self.btn_fonte_data):
            controle.connect("font-set", self._atualizar_previa)
        for controle in (
            self.spin_tam_dia,
            self.spin_tam_data,
            self.spin_espaco,
        ):
            controle.connect("value-changed", self._atualizar_previa)
        self.btn_padroes.connect("clicked", self._restaurar_padroes)
        return moldura

    # -- estado -> campos --------------------------------------------------
    def _preencher_campos(self):
        self._atualizando = True
        posicao = self.config["posicao"]
        texto = self.config["texto"]

        if posicao["ancora_horizontal"] == "direita":
            self.radio_dir.set_active(True)
        else:
            self.radio_esq.set_active(True)
        self.spin_margem_lateral.set_value(posicao["margem_lateral"])
        self.spin_margem_inferior.set_value(posicao["margem_inferior"])

        self.btn_fonte_dia.set_font(f"{texto['fonte_dia']} 12")
        self.spin_tam_dia.set_value(texto["tamanho_dia"])
        self.btn_fonte_data.set_font(f"{texto['fonte_data']} 12")
        self.spin_tam_data.set_value(texto["tamanho_data"])
        self.spin_espaco.set_value(texto["espacamento"])

        self._atualizando = False
        GLib.idle_add(self._atualizar_previa)

    def _familia(self, botao):
        """Só o nome da família, sem o tamanho escolhido no diálogo."""
        familia = Pango.FontDescription.from_string(botao.get_font()).get_family()
        return familia or botao.get_font()

    def _config_dos_campos(self):
        return {
            "posicao": {
                "ancora_horizontal": (
                    "direita" if self.radio_dir.get_active() else "esquerda"
                ),
                "margem_lateral": int(self.spin_margem_lateral.get_value()),
                "margem_inferior": int(self.spin_margem_inferior.get_value()),
            },
            "texto": {
                "fonte_dia": self._familia(self.btn_fonte_dia),
                "tamanho_dia": int(self.spin_tam_dia.get_value()),
                "fonte_data": self._familia(self.btn_fonte_data),
                "tamanho_data": int(self.spin_tam_data.get_value()),
                "espacamento": int(self.spin_espaco.get_value()),
            },
        }

    # -- prévia ------------------------------------------------------------
    def _atualizar_previa(self, *_):
        if self._atualizando:
            return False

        config = self._config_dos_campos()
        texto = config["texto"]
        dia, data = self.modulo.textos_de_hoje()

        tam_dia = max(8, round(texto["tamanho_dia"] * FATOR))
        tam_data = max(6, round(texto["tamanho_data"] * FATOR))
        escape = GLib.markup_escape_text

        self.lbl_prev_dia.set_markup(
            f'<span font_desc="{escape(texto["fonte_dia"], -1)} {tam_dia}">'
            f"{escape(dia, -1)}</span>"
        )
        self.lbl_prev_data.set_markup(
            f'<span font_desc="{escape(texto["fonte_data"], -1)} {tam_data}" '
            f'foreground="#D0D0D0">{escape(data, -1)}</span>'
        )
        self.float_previa.set_spacing(max(0, round(texto["espacamento"] * FATOR)))

        requisicao = self.float_previa.get_preferred_size()[1]
        largura = requisicao.width or 1
        altura = requisicao.height or 1

        x = config["posicao"]["margem_lateral"] * FATOR
        y = ALTURA_MAPA - config["posicao"]["margem_inferior"] * FATOR - altura
        if config["posicao"]["ancora_horizontal"] == "direita":
            x = LARGURA_MAPA - x - largura

        self.mapa.move(self.float_previa, int(max(0, x)), int(max(0, y)))
        return False

    # -- ações -------------------------------------------------------------
    def _restaurar_padroes(self, *_):
        self.config = {s: dict(c) for s, c in self.modulo.PADROES.items()}
        self._preencher_campos()
        self._status("Padrões restaurados na janela — clique em Aplicar.")

    def _aplicar(self, *_):
        config = self._config_dos_campos()
        try:
            destino = self.modulo.salvar_config(config)
        except OSError as erro:
            self._erro(f"Não consegui salvar a configuração:\n{erro}")
            return

        self.config = config
        rodando, iniciou = self._reiniciar_widget(destino)

        if iniciou:
            self._status(f"Salvo em {destino}\nWidget reiniciado.")
        elif rodando:
            self._status(
                f"Salvo em {destino}\nWidget parado; inicie com: calendar-widget"
            )
        else:
            self._status(
                f"Salvo em {destino}\nO widget não está em execução — "
                "ele usará estes valores na próxima vez que iniciar."
            )

    def _reiniciar_widget(self, config_usado):
        """Para o widget em execução e sobe de novo. Devolve (rodava, iniciou)."""
        pids = pids_do_widget()
        rodava = bool(pids)
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass

        # Dá até ~1s para ele sair antes de subir a nova instância.
        for _ in range(10):
            if not pids_do_widget():
                break
            time.sleep(0.1)

        if self.caminho_widget is None:
            return rodava, False

        ambiente = dict(os.environ)
        ambiente["CALENDAR_WIDGET_CONFIG"] = str(config_usado)
        try:
            subprocess.Popen(
                [str(self.caminho_widget)],
                cwd=str(self.caminho_widget.parent),
                env=ambiente,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError as erro:
            self._erro(f"O widget não subiu:\n{erro}")
            return rodava, False
        return rodava, True

    def _status(self, mensagem):
        self.lbl_status.set_text(mensagem)

    def _erro(self, mensagem):
        dialogo = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=mensagem,
        )
        dialogo.run()
        dialogo.destroy()


def main():
    caminho = achar_widget()
    if caminho is None:
        sys.exit(
            "calendar-widget não encontrado.\n"
            "Rode restaurar-setup-cosmic.sh ou coloque o widget em ~/.local/bin."
        )

    modulo = carregar_modulo_widget(caminho)

    provedor = Gtk.CssProvider()
    provedor.load_from_data(
        """
        .mapa-tela {
            background-color: #1b1b1f;
            border: 1px solid #3a3a42;
            border-radius: 6px;
        }
        """,
        -1,
    )
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provedor,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    JanelaConfig(caminho, modulo).show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
PYEOF

chmod +x "$HOME/.local/bin/calendar-widget" "$HOME/.local/bin/calendar-widget-config"

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

# --- Configuração do widget ------------------------------------------------
# Criada a partir dos padrões do próprio widget; preservada se já existir.
CONFIG_WIDGET="$HOME/.config/calendar-widget/config.ini"
if [ -f "$CONFIG_WIDGET" ]; then
    OK "Configuração do widget preservada ($CONFIG_WIDGET)"
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
        OK "Configuração do widget criada ($CONFIG_WIDGET)"
    else
        AVISO "Sem config pronta — o widget cria os padrões no primeiro uso"
    fi
fi

OK "Configurador gráfico instalado: calendar-widget-config"

# --- Atalho no menu de aplicativos -----------------------------------------
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
OK "Atalho no menu: Calendário — Ajustes"

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

# 6.1 Sintaxe do widget e do configurador
python3 -m py_compile "$HOME/.local/bin/calendar-widget" \
    "$HOME/.local/bin/calendar-widget-config" \
    && OK "Widget e configurador compilam sem erro" \
    || { ERRO "Erro de sintaxe no widget/configurador."; exit 1; }
rm -rf "$HOME/.local/bin/__pycache__"

# 6.1b Configuração do widget
if [ -f "$CONFIG_WIDGET" ]; then
    OK "Configuração do widget pronta ($CONFIG_WIDGET)"
else
    AVISO "Config do widget ausente — o widget cria no primeiro uso"
fi

# 6.1c Atalho do menu válido
desktop-file-validate "$HOME/.local/share/applications/calendar-widget-config.desktop" \
    >/dev/null 2>&1 \
    && OK "Atalho do menu válido" \
    || AVISO "desktop-file-validate não validou o atalho"

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
printf '  • Ajustes:  %sCalendário — Ajustes%s (menu de aplicativos)\n' \
       "$c_azul" "$c_reset"
printf '              ou %scalendar-widget-config%s no terminal\n' "$c_azul" "$c_reset"
printf '  • Wallpaper:%saura%s  -> escolha um vídeo/papel na interface\n' "$c_azul" "$c_reset"
printf '  • Trocar:   %saura next%s      • Pausar: %saura toggle-pause%s\n' \
       "$c_azul" "$c_reset" "$c_azul" "$c_reset"
printf '\nObs: o wallpaper anterior não é restaurado (arquivos de vídeo\n'
printf 'não fazem backup). Basta arrastar seus vídeos para:\n'
printf '  ~/Imagens/Wallpapers/Aura\n'
printf '%s════════════════════════════════════════════════════════%s\n' "$c_azul" "$c_reset"
