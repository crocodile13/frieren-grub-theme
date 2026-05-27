#!/bin/bash
# Frieren GRUB Theme v4.0 - Déploiement Interactif et Sécurisé

set -e

THEME_NAME="frieren"
LOADFONTS_SCRIPT="/etc/grub.d/09_loadfonts"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       🌸 Frieren GRUB Theme v4.0 - Configuration 🌸       ║"
echo "║              Procédure d'installation standard            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check privilège
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Erreur : Cette opération requiert des privilèges d'administrateur (sudo).${NC}"
    exit 1
fi

# Répertoire source script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_THEME_DIR="${SCRIPT_DIR}/frieren-theme"

# Check source directory
if [ ! -d "$SRC_THEME_DIR" ]; then
    echo -e "${RED}✗ Erreur : Le dossier source '${SRC_THEME_DIR}' est introuvable.${NC}"
    exit 1
fi

# Fonction validation interactive réutilisable
ask_confirm() {
    while true; do
        read -r -p "$1 [O/n] " response
        case "$response" in
            [oO][uU][iI]|[oO]|"") return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo -e "${RED}Veuillez répondre par 'o' (oui) ou 'n' (non).${NC}" ;;
        esac
    done
}

# Fonction édition fichier de conf GRUB
update_grub_conf() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    elif grep -q "^#${key}=" "$file"; then
        sed -i "s|^#${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# detection de arborescence GRUB cible (jsp trop si ca marche vu que je suis le seul a l'avoir installé....)
if [ -d "/boot/grub" ]; then
    GRUB_DIR="/boot/grub"
    GRUB_CFG="/boot/grub/grub.cfg"
    GRUB_MKCONFIG="grub-mkconfig"
elif [ -d "/boot/grub2" ]; then
    GRUB_DIR="/boot/grub2"
    GRUB_CFG="/boot/grub2/grub.cfg"
    GRUB_MKCONFIG="grub2-mkconfig"
else
    echo -e "${RED}✗ Erreur : Répertoire GRUB introuvable sur ce système.${NC}"
    exit 1
fi

TARGET_THEME_DIR="${GRUB_DIR}/themes/${THEME_NAME}"

# sélection de la résolution cible, je a fait 2, ya pas grand chose a faire pour en faire dautres globalemen: background.png a resize + resolution dans /etc/default/grub + theme.txt (adapter les positions absolues)
echo -e "${YELLOW}Sélectionnez la résolution d'affichage cible :${NC}"
echo "1) 1920x1080 (1080p)"
echo "2) 2560x1440 (1440p)"
while true; do
    read -r -p "Option (1 ou 2) : " res_choice
    if [ "$res_choice" = "1" ]; then
        SELECTED_GFXMODE="1920x1080"
        THEME_TXT_SRC="theme_1080p.txt"
        BG_PNG_SRC="background_1080.png"
        break
    elif [ "$res_choice" = "2" ]; then
        SELECTED_GFXMODE="2560x1440"
        THEME_TXT_SRC="theme_1440.txt"
        BG_PNG_SRC="background_1440.png"
        break
    else
        echo -e "${RED}Sélection invalide. Saisissez 1 ou 2.${NC}"
    fi
done

# ==============================================================================
# PHASE 1 : DÉPLOIEMENT DES COMPOSANTS GRAPHIQUES
# ==============================================================================
echo -e "\n${YELLOW}[1/4] Phase de déploiement des composants graphiques...${NC}"
echo -e "${CYAN}Aperçu des opérations planifiées :${NC}"
echo "  [-] Suppression de l'ancienne version (si existante) : ${TARGET_THEME_DIR}"
echo "  [+] Copie globale du dossier : ${SRC_THEME_DIR} → ${TARGET_THEME_DIR}"
echo "  [+] Application résolution : Cloner et renommer ${THEME_TXT_SRC} → theme.txt"
echo "  [+] Application arrière-plan : Cloner et renommer ${BG_PNG_SRC} → background.png"
echo "  [-] Nettoyage : Suppression des fichiers de résolution non utilisés dans la cible"
echo ""

if ask_confirm "Procéder à l'exécution de ces opérations de fichiers ?"; then
    mkdir -p "${GRUB_DIR}/themes"
    if [ -d "$TARGET_THEME_DIR" ]; then
        rm -rf "$TARGET_THEME_DIR"
    fi

    cp -r "$SRC_THEME_DIR" "$TARGET_THEME_DIR"
    cp "${TARGET_THEME_DIR}/${THEME_TXT_SRC}" "${TARGET_THEME_DIR}/theme.txt"
    cp "${TARGET_THEME_DIR}/${BG_PNG_SRC}" "${TARGET_THEME_DIR}/background.png"
    rm -f "${TARGET_THEME_DIR}"/theme_*.txt
    rm -f "${TARGET_THEME_DIR}"/background_*.png

    echo -e "${GREEN}✓ Opérations de fichiers exécutées avec succès.${NC}\n"
else
    echo -e "${YELLOW}Phase annulée. Les fichiers système n'ont pas été modifiés.${NC}\n"
fi

# ==============================================================================
# PHASE 2 : SCRIPT DE CHARGEMENT DES POLICES
# ==============================================================================
echo -e "${YELLOW}[2/4] Phase de déploiement du script de chargement des polices...${NC}"
echo -e "${CYAN}Aperçu des opérations planifiées :${NC}"
echo "  [+] Création de : ${LOADFONTS_SCRIPT}"
echo "  [+] Contenu : lignes loadfont pour chaque .pf2 installé dans ${TARGET_THEME_DIR}/fonts/"
echo "  [!] Ce script est invoqué par grub-mkconfig pour injecter les polices dans grub.cfg"
echo "  [!] Sans lui, GRUB ignore les polices du thème et affiche du texte en taille par défaut"
echo ""

if ask_confirm "Créer le script de chargement des polices ?"; then
    {
        echo "#!/bin/sh"
        echo "# Généré par Frieren GRUB Theme install.sh — NE PAS ÉDITER MANUELLEMENT"
        echo "# Charge les polices du thème au démarrage de GRUB."
        echo "# Supprimé automatiquement par uninstall.sh."
        echo "cat << 'EOF'"
        for pf2 in "${TARGET_THEME_DIR}/fonts/"*.pf2; do
            [ -f "$pf2" ] || continue
            # Chemin relatif à partir de /boot pour la syntaxe ($root)/boot/...
            rel="${pf2#/boot}"
            echo "loadfont (\$root)/boot${rel}"
        done
        echo "EOF"
    } > "$LOADFONTS_SCRIPT"
    chmod +x "$LOADFONTS_SCRIPT"
    echo -e "${GREEN}✓ Script créé et rendu exécutable : ${LOADFONTS_SCRIPT}${NC}"
    echo -e "${CYAN}  Contenu généré :${NC}"
    grep "loadfont" "$LOADFONTS_SCRIPT" | sed 's/^/    /'
    echo ""
else
    echo -e "${YELLOW}Phase annulée. Le script de polices n'a pas été créé.${NC}"
    echo -e "${YELLOW}⚠  Les polices du thème risquent de ne pas s'afficher à la bonne taille.${NC}\n"
fi

# ==============================================================================
# PHASE 3 : CONFIGURATION GRUB
# ==============================================================================
GRUB_DEFAULT="/etc/default/grub"

if [ -f "$GRUB_DEFAULT" ]; then
    echo -e "${YELLOW}[3/4] Phase de modification de la configuration (${GRUB_DEFAULT})${NC}"

    echo -e "${CYAN}Aperçu des modifications planifiées :${NC}"
    echo "  [!] Un fichier de sauvegarde sera créé : ${GRUB_DEFAULT}.backup"
    echo "  [+] GRUB_THEME=\"${TARGET_THEME_DIR}/theme.txt\""
    echo "  [+] GRUB_GFXMODE=${SELECTED_GFXMODE}"
    echo "  [+] GRUB_GFXPAYLOAD_LINUX=keep"
    echo "  [+] GRUB_TIMEOUT=8"
    echo "  [+] GRUB_TIMEOUT_STYLE=menu"
    echo "  [+] GRUB_TERMINAL_OUTPUT=\"gfxterm\""
    echo "  [+] GRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=3 splash apparmor=1 security=apparmor vt.global_cursor_default=0\""
    echo ""

    if ask_confirm "Appliquer ces modifications au fichier de configuration GRUB ?"; then
        cp "$GRUB_DEFAULT" "${GRUB_DEFAULT}.backup"
        update_grub_conf "GRUB_THEME" "\"${TARGET_THEME_DIR}/theme.txt\"" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_GFXMODE" "${SELECTED_GFXMODE}" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_GFXPAYLOAD_LINUX" "keep" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_TIMEOUT" "8" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_TIMEOUT_STYLE" "menu" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_TERMINAL_OUTPUT" "\"gfxterm\"" "$GRUB_DEFAULT"
        update_grub_conf "GRUB_CMDLINE_LINUX_DEFAULT" "\"quiet loglevel=3 splash apparmor=1 security=apparmor vt.global_cursor_default=0\"" "$GRUB_DEFAULT"
        echo -e "${GREEN}✓ Modifications appliquées et sauvegarde générée.${NC}"
    else
        echo -e "${YELLOW}Opération annulée. Le fichier de configuration n'a pas été modifié.${NC}"
    fi
fi

# ==============================================================================
# PHASE 4 : RÉGÉNÉRATION DU BINAIRE
# ==============================================================================
echo -e "\n${YELLOW}[4/4] Phase de régénération du binaire d'amorçage...${NC}"
echo -e "${CYAN}Aperçu de l'opération planifiée :${NC}"
echo "  [+] Exécution de la commande : ${GRUB_MKCONFIG} -o ${GRUB_CFG}"
echo "  (Cette action va compiler les modifications pour les rendre effectives au démarrage)"
echo ""

if ask_confirm "Lancer la compilation finale de GRUB ?"; then
    $GRUB_MKCONFIG -o "$GRUB_CFG"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓ Installation terminée ! Le système est prêt.          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
else
    echo -e "${YELLOW}Compilation ignorée. N'oubliez pas d'exécuter 'sudo ${GRUB_MKCONFIG} -o ${GRUB_CFG}' manuellement avant de reboot.${NC}"
fi
