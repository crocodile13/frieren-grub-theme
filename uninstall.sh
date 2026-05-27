#!/bin/bash
# Frieren GRUB Theme - Script de Désinstallation

set -e

THEME_NAME="frieren"
LOADFONTS_SCRIPT="/etc/grub.d/09_loadfonts"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║             ⚠️  DÉSINSTALLATION DU THÈME  ⚠️               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Vérification des privilèges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Erreur : Cette opération requiert des privilèges d'administrateur (sudo).${NC}"
    exit 1
fi

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

# Détection de l'arborescence GRUB
if [ -d "/boot/grub" ]; then
    GRUB_DIR="/boot/grub"
    GRUB_CFG="/boot/grub/grub.cfg"
    GRUB_MKCONFIG="grub-mkconfig"
elif [ -d "/boot/grub2" ]; then
    GRUB_DIR="/boot/grub2"
    GRUB_CFG="/boot/grub2/grub.cfg"
    GRUB_MKCONFIG="grub2-mkconfig"
else
    echo -e "${RED}✗ Erreur : Répertoire GRUB introuvable.${NC}"
    exit 1
fi

TARGET_THEME_DIR="${GRUB_DIR}/themes/${THEME_NAME}"
GRUB_DEFAULT="/etc/default/grub"

# ==============================================================================
# PHASE 1 : NETTOYAGE DES FICHIERS GRAPHIQUES
# ==============================================================================
echo -e "${YELLOW}[1/4] Phase de suppression des fichiers graphiques...${NC}"
echo -e "${CYAN}Aperçu des opérations planifiées :${NC}"
echo "  [-] Suppression définitive du dossier : ${TARGET_THEME_DIR}"
echo ""

if [ -d "$TARGET_THEME_DIR" ]; then
    if ask_confirm "Confirmer la suppression du dossier du thème ?"; then
        rm -rf "$TARGET_THEME_DIR"
        echo -e "${GREEN}✓ Dossier supprimé.${NC}\n"
    else
        echo -e "${YELLOW}Suppression annulée.${NC}\n"
    fi
else
    echo -e "${GREEN}✓ Aucun dossier installé détecté dans ${TARGET_THEME_DIR}.${NC}\n"
fi

# ==============================================================================
# PHASE 2 : SUPPRESSION DU SCRIPT DE CHARGEMENT DES POLICES
# ==============================================================================
echo -e "${YELLOW}[2/4] Phase de suppression du script de chargement des polices...${NC}"
echo -e "${CYAN}Aperçu des opérations planifiées :${NC}"
echo "  [-] Suppression de : ${LOADFONTS_SCRIPT}"
echo "  [!] Sans cette suppression, grub-mkconfig continuerait à chercher des polices inexistantes"
echo ""

if [ -f "$LOADFONTS_SCRIPT" ]; then
    echo -e "${CYAN}  Contenu qui sera supprimé :${NC}"
    grep "loadfont" "$LOADFONTS_SCRIPT" | sed 's/^/    /' || true
    echo ""
    if ask_confirm "Confirmer la suppression du script de polices ?"; then
        rm -f "$LOADFONTS_SCRIPT"
        echo -e "${GREEN}✓ Script supprimé : ${LOADFONTS_SCRIPT}${NC}\n"
    else
        echo -e "${YELLOW}Suppression annulée.${NC}\n"
    fi
else
    echo -e "${GREEN}✓ Aucun script de polices détecté dans ${LOADFONTS_SCRIPT}.${NC}\n"
fi

# ==============================================================================
# PHASE 3 : RESTAURATION DE LA CONFIGURATION
# ==============================================================================
echo -e "${YELLOW}[3/4] Phase de nettoyage de la configuration (${GRUB_DEFAULT})${NC}"

if [ -f "$GRUB_DEFAULT" ]; then
    echo -e "${CYAN}Aperçu des modifications planifiées :${NC}"
    echo "  [-] Suppression de la ligne GRUB_THEME"
    echo "  [!] Note : Les autres variables (GFXMODE, etc.) restent inchangées pour ne pas casser votre affichage standard."
    echo ""

    if ask_confirm "Désactiver le thème dans le fichier de configuration ?"; then
        sed -i "s|^GRUB_THEME=.*|#GRUB_THEME=|" "$GRUB_DEFAULT"
        echo -e "${GREEN}✓ Thème désactivé dans la configuration.${NC}\n"
    else
        echo -e "${YELLOW}Modification de la configuration annulée.${NC}\n"
    fi
fi

# ==============================================================================
# PHASE 4 : RÉGÉNÉRATION DU BINAIRE
# ==============================================================================
echo -e "${YELLOW}[4/4] Phase de mise à jour du chargeur d'amorçage...${NC}"
echo -e "${CYAN}Aperçu de l'opération planifiée :${NC}"
echo "  [+] Exécution de la commande : ${GRUB_MKCONFIG} -o ${GRUB_CFG}"
echo "  (Indispensable pour appliquer le retrait du thème et des polices au démarrage)"
echo ""

if ask_confirm "Lancer la régénération de GRUB ?"; then
    $GRUB_MKCONFIG -o "$GRUB_CFG"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓ Le thème a été désinstallé avec succès !              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
else
    echo -e "${YELLOW}Opération différée. N'oubliez pas de lancer 'sudo ${GRUB_MKCONFIG} -o ${GRUB_CFG}' pour finaliser.${NC}"
fi
