#!/bin/bash

# Script de Automatización de Escaneo Inicial - Versión Definitiva
# Autor: Security Automation Script
# Uso: ./autorecon.sh <TARGET_IP/DOMAIN>

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Verificar que se proporcionó un objetivo
if [ $# -eq 0 ]; then
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║           ERROR: SIN OBJETIVO         ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Uso: $0 <TARGET_IP/DOMAIN>${NC}"
    echo -e "${GREEN}Ejemplos:${NC}"
    echo -e "  $0 192.168.1.100"
    echo -e "  $0 realgob.dl"
    echo -e "  $0 target.com"
    exit 1
fi

TARGET=$1
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="scan_results_${TARGET//[^a-zA-Z0-9]/_}_${TIMESTAMP}"

# Banner de inicio
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              AUTORECON - ESCANEO INICIAL              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo -e "${WHITE}Objetivo:${NC} ${GREEN}$TARGET${NC}"
echo -e "${WHITE}Inicio:${NC}   $(date)"
echo ""

# =============================================
# PREGUNTAR SI GENERAR REPORTE
# =============================================
echo -e "${YELLOW}┌─[ CONFIGURACIÓN ]─────────────────────────┐${NC}"
echo -e "${YELLOW}│${NC}  ¿Deseas generar archivos de reporte?      ${YELLOW}│${NC}"
echo -e "${YELLOW}│${NC}  (s/n) - por defecto: n                    ${YELLOW}│${NC}"
echo -e "${YELLOW}└─────────────────────────────────────────┘${NC}"
echo -ne "${GREEN}➜ ${NC}"
read -r GENERATE_REPORT

if [[ "$GENERATE_REPORT" =~ ^[Ss]$ ]]; then
    SAVE_RESULTS=true
    mkdir -p "$OUTPUT_DIR"
    REPORT_FILE="${OUTPUT_DIR}/full_report.txt"
    echo -e "\n${GREEN}[✓] Reportes se guardarán en:${NC} $OUTPUT_DIR"
else
    SAVE_RESULTS=false
    echo -e "\n${YELLOW}[i] Modo solo pantalla: No se guardarán archivos${NC}"
fi
echo ""

# Función para mostrar separadores
separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

# =============================================
# 1. ESCANEO NMAP CON -sCV
# =============================================
echo -e "${YELLOW}[*] Iniciando escaneo Nmap (sCV)...${NC}"
separator

# Configurar archivos si se guardan resultados
if [ "$SAVE_RESULTS" = true ]; then
    NMAP_SCAN_FILE="${OUTPUT_DIR}/nmap_full_scan.txt"
    NMAP_FILTERED_FILE="${OUTPUT_DIR}/nmap_filtered.txt"
    touch "$NMAP_SCAN_FILE"
    touch "$NMAP_FILTERED_FILE"
else
    NMAP_SCAN_FILE="/tmp/nmap_scan_$$.txt"
    NMAP_FILTERED_FILE="/tmp/nmap_filtered_$$.txt"
fi

# Escaneo completo con -sCV
echo -e "${YELLOW}[*] Ejecutando escaneo completo...${NC}"
if [ "$SAVE_RESULTS" = true ]; then
    nmap -sCV -T4 --min-rate=1000 -p- -oN "$NMAP_SCAN_FILE" "$TARGET" > /dev/null 2>&1
else
    # Mostrar progreso en tiempo real
    nmap -sCV -T4 --min-rate=1000 -p- "$TARGET" | tee "$NMAP_SCAN_FILE"
fi

# Verificar que nmap se ejecutó correctamente
if [ ! -s "$NMAP_SCAN_FILE" ]; then
    echo -e "${RED}[!] ERROR: Nmap no generó resultados${NC}"
    echo -e "${YELLOW}[*] Probando escaneo alternativo...${NC}"
    nmap -sCV -T4 -p- "$TARGET" > "$NMAP_SCAN_FILE" 2>&1
fi

# Extraer puertos abiertos
OPEN_PORTS=$(grep -E "^[0-9]+/tcp.*open" "$NMAP_SCAN_FILE" 2>/dev/null | awk '{print $1}' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')

# Mostrar resultados en tiempo real si no se guardan
if [ "$SAVE_RESULTS" = false ]; then
    echo -e "\n${GREEN}[+] RESULTADOS NMAP:${NC}"
    separator
    grep -E "^[0-9]+/tcp" "$NMAP_SCAN_FILE" 2>/dev/null | while read -r line; do
        port=$(echo "$line" | awk '{print $1}')
        service=$(echo "$line" | awk '{print $3}')
        version=$(echo "$line" | cut -d' ' -f4-)
        echo -e "  ${GREEN}$port${NC} - ${YELLOW}$service${NC} ${WHITE}$version${NC}"
    done
fi

# Guardar resultados filtrados si aplica
if [ "$SAVE_RESULTS" = true ]; then
    {
        echo "RESULTADOS NMAP FILTRADOS"
        echo "========================="
        echo "Objetivo: $TARGET"
        echo "Fecha: $(date)"
        echo ""
        echo "Puertos Abiertos: $OPEN_PORTS"
        echo ""
        echo "Detalles por Puerto:"
        echo "-------------------"
        awk '/^PORT.*STATE.*SERVICE/,/^$/' "$NMAP_SCAN_FILE" 2>/dev/null | head -50
    } > "$NMAP_FILTERED_FILE"
fi

# Mostrar resumen de nmap
echo -e "\n${GREEN}[+] Escaneo Nmap completado${NC}"
echo -e "${WHITE}Puertos TCP abiertos encontrados:${NC} ${GREEN}${OPEN_PORTS:-Ninguno}${NC}"

# Mostrar servicios principales
echo -e "\n${YELLOW}Servicios detectados:${NC}"
grep -E "^[0-9]+/tcp.*open.*[a-zA-Z]" "$NMAP_SCAN_FILE" 2>/dev/null | head -10 | while read -r service; do
    port=$(echo "$service" | awk '{print $1}')
    service_name=$(echo "$service" | awk '{print $3}')
    version=$(echo "$service" | cut -d' ' -f4-)
    echo -e "  ${GREEN}➜${NC} ${WHITE}$port${NC} | ${YELLOW}$service_name${NC} ${version}"
done

# =============================================
# 2. DETECCIÓN DE SERVICIOS WEB
# =============================================
echo -e "\n${YELLOW}[*] Analizando servicios web...${NC}"

# Determinar URL web basada en puertos abiertos
WEB_URL=""
if echo "$OPEN_PORTS" | grep -q "443"; then
    WEB_URL="https://$TARGET"
    echo -e "${GREEN}[+] Servicio HTTPS detectado (puerto 443)${NC}"
elif echo "$OPEN_PORTS" | grep -q "80"; then
    WEB_URL="http://$TARGET"
    echo -e "${GREEN}[+] Servicio HTTP detectado (puerto 80)${NC}"
else
    # Verificar si el objetivo parece un dominio
    if [[ "$TARGET" =~ [a-zA-Z] ]] && [ ! "$TARGET" =~ ^[0-9.]+$ ]; then
        echo -e "${YELLOW}[*] Probando HTTP/HTTPS en dominio...${NC}"
        
        HTTP_CODE=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://$TARGET" 2>/dev/null || echo "FAILED")
        if [[ "$HTTP_CODE" =~ ^[234] ]]; then
            WEB_URL="http://$TARGET"
            echo -e "${GREEN}[+] Dominio responde a HTTP (código $HTTP_CODE)${NC}"
        else
            HTTPS_CODE=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "https://$TARGET" 2>/dev/null || echo "FAILED")
            if [[ "$HTTPS_CODE" =~ ^[234] ]]; then
                WEB_URL="https://$TARGET"
                echo -e "${GREEN}[+] Dominio responde a HTTPS (código $HTTPS_CODE)${NC}"
            fi
        fi
    fi
fi

# =============================================
# 3. ESCANEO GOBUSTER - SOLO CON DICCIONARIO MEDIUM
# =============================================
if [ -n "$WEB_URL" ] && [[ "$WEB_URL" =~ ^https?:// ]]; then
    echo -e "\n${GREEN}[+] Servicio web detectado en: $WEB_URL${NC}"
    
    WEB_URL=$(echo "$WEB_URL" | sed 's|/$||')
    echo -e "${YELLOW}[*] URL final para escaneo: $WEB_URL${NC}"
    
    # Determinar puerto
    PORT_NUM="web"
    if echo "$WEB_URL" | grep -q ":443"; then
        PORT_NUM="443"
    elif echo "$WEB_URL" | grep -q ":80"; then
        PORT_NUM="80"
    fi
    
    # =============================================
    # CONFIGURACIÓN DE DICCIONARIO MEDIUM
    # =============================================
    DICT_MEDIUM="/home/kali/Seclist-Dicctionaries/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt"
    
    # Verificar diccionario
    if [ ! -f "$DICT_MEDIUM" ]; then
        echo -e "${YELLOW}[!] Diccionario medium no encontrado, creando temporal...${NC}"
        DICT_MEDIUM="/tmp/medium_$$.txt"
        echo -e "admin\nlogin\ndashboard\napi\ntest\nbackup\nconfig\nwp-admin\nphpmyadmin\nserver-status\n.env\n.git\n.svn\nbackup.sql\nconfig.php\nindex.php" > "$DICT_MEDIUM"
    fi
    
    # Configurar archivos de salida
    if [ "$SAVE_RESULTS" = true ]; then
        GOBUSTER_MEDIUM_FILE="${OUTPUT_DIR}/gobuster_medium_${PORT_NUM}.txt"
        GOBUSTER_FILTERED_FILE="${OUTPUT_DIR}/gobuster_filtered_${PORT_NUM}.txt"
        GOBUSTER_LOG_FILE="${OUTPUT_DIR}/gobuster_execution.log"
        
        > "$GOBUSTER_MEDIUM_FILE"
        > "$GOBUSTER_FILTERED_FILE"
        > "$GOBUSTER_LOG_FILE"
    else
        GOBUSTER_MEDIUM_FILE="/tmp/gobuster_medium_$$.txt"
        GOBUSTER_LOG_FILE="/tmp/gobuster_log_$$.txt"
    fi
    
    # =============================================
    # DIAGNÓSTICO DEL SITIO
    # =============================================
    echo -e "\n${YELLOW}[*] Verificando accesibilidad...${NC}"
    
    HTTP_CODE=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" "$WEB_URL" 2>/dev/null || echo "FAILED")
    GOBUSTER_SSL_FLAG=""
    
    if [[ "$HTTP_CODE" =~ ^[234] ]]; then
        echo -e "${GREEN}[✓] Sitio accesible (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${YELLOW}[!] Probando con -k (ignore SSL)...${NC}"
        HTTP_CODE_SSL=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" -k "$WEB_URL" 2>/dev/null || echo "FAILED")
        if [[ "$HTTP_CODE_SSL" =~ ^[234] ]]; then
            echo -e "${GREEN}[✓] Sitio accesible con -k${NC}"
            GOBUSTER_SSL_FLAG="-k"
        else
            echo -e "${RED}[✗] Sitio no accesible, omitiendo Gobuster${NC}"
            SKIP_GOBUSTER=true
        fi
    fi
    
    # =============================================
    # EJECUTAR GOBUSTER (SOLO MEDIUM)
    # =============================================
    if [ ! "$SKIP_GOBUSTER" = true ]; then
        echo -e "\n${YELLOW}[*] Escaneando con diccionario medium...${NC}"
        echo -e "${WHITE}Esto puede tomar varios minutos...${NC}"
        
        # Extensiones ampliadas para medium
        EXTENSIONS="php,txt,html,js,json,zip,bak,old,backup,sql,config,env,xml,yml,yaml,ini,log,sh,py,rb,pl,cgi,asp,aspx,jsp,do,action"
        
        CMD="gobuster dir -u \"$WEB_URL\" -w \"$DICT_MEDIUM\" -t 20 -x $EXTENSIONS $GOBUSTER_SSL_FLAG -o \"$GOBUSTER_MEDIUM_FILE\" -q"
        
        if [ "$SAVE_RESULTS" = false ]; then
            eval $CMD 2>/dev/null
        else
            eval $CMD 2>&1 | tee -a "$GOBUSTER_LOG_FILE" >/dev/null
        fi
        
        # =============================================
        # MOSTRAR RESULTADOS DE GOBUSTER (SOLO DIRECTORIOS ENCONTRADOS)
        # =============================================
        if [ -f "$GOBUSTER_MEDIUM_FILE" ] && [ -s "$GOBUSTER_MEDIUM_FILE" ]; then
            # Contar resultados totales
            TOTAL_RESULTS=$(grep -c "Status:" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null || echo 0)
            
            echo -e "\n${CYAN}📁 DIRECTORIOS Y ARCHIVOS ENCONTRADOS:${NC}"
            echo -e "${WHITE}════════════════════════════════════════════════════════${NC}"
            
            # Mostrar TODOS los resultados encontrados (solo lo esencial)
            grep "Status:" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | while read -r line; do
                # Extraer solo la URL y el código de estado de forma limpia
                url=$(echo "$line" | grep -o 'http[^ ]*' | head -1 | sed 's/^http:\/\///' | sed 's/^https:\/\///')
                status=$(echo "$line" | grep -o 'Status: [0-9]\+' | cut -d' ' -f2)
                
                if [ -n "$url" ]; then
                    # Formatear según código de estado
                    case $status in
                        200) echo -e "  ${GREEN}✓${NC} ${WHITE}$url${NC}" ;;
                        301|302|307) echo -e "  ${YELLOW}↻${NC} ${WHITE}$url${NC} ${YELLOW}[redirect]${NC}" ;;
                        403) echo -e "  ${RED}⛔${NC} ${WHITE}$url${NC} ${RED}[forbidden]${NC}" ;;
                        401) echo -e "  ${PURPLE}🔒${NC} ${WHITE}$url${NC} ${PURPLE}[auth]${NC}" ;;
                        500) echo -e "  ${RED}💥${NC} ${WHITE}$url${NC} ${RED}[error]${NC}" ;;
                        *) echo -e "  ${BLUE}•${NC} ${WHITE}$url${NC} ${BLUE}[$status]${NC}" ;;
                    esac
                fi
            done
            
            echo -e "${WHITE}════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}Total encontrado:${NC} $TOTAL_RESULTS elementos"
            
            # =============================================
            # DESTACAR HALLAZGOS INTERESANTES
            # =============================================
            INTERESTING_FINDS=$(grep -E "\.(env|git|svn|bak|old|backup|sql|config|ini|log|sh|py|rb|pl|cgi|asp|aspx|jsp)" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | \
                               grep -E "(admin|login|backup|config|test|debug|api|dashboard|private|secret|wp|cms|drupal|joomla|phpmyadmin|mysql|database)" 2>/dev/null | \
                               grep -c "Status:" 2>/dev/null || echo 0)
            
            if [ "$INTERESTING_FINDS" -gt 0 ]; then
                echo -e "\n${PURPLE}🔍 HALLAZGOS DE INTERÉS:${NC}"
                echo -e "${WHITE}════════════════════════════════════════════════════════${NC}"
                
                grep -E "\.(env|git|svn|bak|old|backup|sql|config|ini|log|sh|py|rb|pl|cgi|asp|aspx|jsp)" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | \
                grep -E "(admin|login|backup|config|test|debug|api|dashboard|private|secret|wp|cms|drupal|joomla|phpmyadmin|mysql|database)" 2>/dev/null | \
                head -20 | while read -r line; do
                    
                    url=$(echo "$line" | grep -o 'http[^ ]*' | head -1 | sed 's/^http:\/\///' | sed 's/^https:\/\///')
                    status=$(echo "$line" | grep -o 'Status: [0-9]\+' | cut -d' ' -f2)
                    
                    if [ -n "$url" ]; then
                        echo -e "  ${PURPLE}➜${NC} ${WHITE}$url${NC} ${GREEN}[$status]${NC}"
                    fi
                done
                echo -e "${WHITE}════════════════════════════════════════════════════════${NC}"
            fi
            
        else
            echo -e "\n${YELLOW}⚠ No se encontraron directorios o archivos${NC}"
        fi
        
        echo -e "\n${GREEN}[✓] Escaneo Gobuster completado${NC}"
        
        # Procesar resultados para guardar si aplica
        if [ "$SAVE_RESULTS" = true ]; then
            MEDIUM_RESULTS=$(grep -c "Status:" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null || echo 0)
            
            {
                echo "RESULTADOS GOBUSTER - DICCIONARIO MEDIUM"
                echo "========================================="
                echo "URL: $WEB_URL"
                echo "Fecha: $(date)"
                echo "Diccionario: $DICT_MEDIUM"
                echo ""
                echo "ESTADÍSTICAS:"
                echo "-------------"
                echo "Total resultados: $MEDIUM_RESULTS"
                echo ""
                
                if [ "$MEDIUM_RESULTS" -gt 0 ]; then
                    echo "TODOS LOS RESULTADOS ENCONTRADOS:"
                    echo "---------------------------------"
                    cat "$GOBUSTER_MEDIUM_FILE"
                    echo ""
                    
                    echo "HALLAZGOS DESTACADOS:"
                    echo "--------------------"
                    grep -E "\.(env|git|svn|bak|old|backup|sql|config|ini|log)" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | \
                    grep -E "(admin|login|backup|config|test|debug|api|secret|wp|phpmyadmin)" 2>/dev/null | head -30
                else
                    echo "No se encontraron resultados"
                fi
                
            } > "$GOBUSTER_FILTERED_FILE"
        fi
    fi
    
else
    echo -e "${YELLOW}[i] No se detectaron servicios web accesibles${NC}"
fi

# =============================================
# 4. ESCANEO UDP RÁPIDO
# =============================================
echo -e "\n${YELLOW}[*] Ejecutando escaneo UDP rápido...${NC}"
separator

if [ "$SAVE_RESULTS" = true ]; then
    UDP_SCAN_FILE="${OUTPUT_DIR}/nmap_udp_scan.txt"
else
    UDP_SCAN_FILE="/tmp/udp_scan_$$.txt"
fi

UDP_PORTS="53,67,68,69,123,161,162,500,514,520,623,998"

> "$UDP_SCAN_FILE"
nmap -sU -T4 -p $UDP_PORTS --open -oN "$UDP_SCAN_FILE" "$TARGET" > /dev/null 2>&1

if grep -q "open" "$UDP_SCAN_FILE" 2>/dev/null; then
    echo -e "${GREEN}[+] Puertos UDP abiertos encontrados:${NC}"
    grep "open" "$UDP_SCAN_FILE" 2>/dev/null | while read -r line; do
        port=$(echo "$line" | awk '{print $1}')
        service=$(echo "$line" | awk '{print $3}')
        echo -e "  ${GREEN}➜${NC} ${WHITE}$port${NC} - ${YELLOW}$service${NC}"
    done
else
    echo -e "${YELLOW}[-] No se encontraron puertos UDP abiertos${NC}"
fi

# =============================================
# 5. GENERAR REPORTE FINAL (si aplica)
# =============================================
if [ "$SAVE_RESULTS" = true ]; then
    echo -e "\n${YELLOW}[*] Generando reporte final...${NC}"
    separator
    
    {
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║        REPORTE COMPLETO DE ESCANEO - AUTORECON        ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Objetivo: $TARGET"
        echo "Fecha: $(date)"
        echo "Directorio: $OUTPUT_DIR"
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "1. RESUMEN EJECUTIVO"
        echo "════════════════════════════════════════════════════════"
        echo "Puertos TCP abiertos: ${OPEN_PORTS:-Ninguno}"
        echo "Servicios web detectados: ${WEB_URL:-Ninguno}"
        echo ""
        
        echo "════════════════════════════════════════════════════════"
        echo "2. ESCANEO NMAP"
        echo "════════════════════════════════════════════════════════"
        [ -f "$NMAP_FILTERED_FILE" ] && cat "$NMAP_FILTERED_FILE" || echo "No disponible"
        echo ""
        
        echo "════════════════════════════════════════════════════════"
        echo "3. ESCANEO GOBUSTER (MEDIUM)"
        echo "════════════════════════════════════════════════════════"
        if [ -f "$GOBUSTER_FILTERED_FILE" ]; then
            cat "$GOBUSTER_FILTERED_FILE"
        else
            echo "No se realizó escaneo web o no se encontraron resultados"
        fi
        echo ""
        
        echo "════════════════════════════════════════════════════════"
        echo "4. ESCANEO UDP"
        echo "════════════════════════════════════════════════════════"
        if [ -f "$UDP_SCAN_FILE" ] && grep -q "open" "$UDP_SCAN_FILE" 2>/dev/null; then
            grep -E "PORT|open" "$UDP_SCAN_FILE" 2>/dev/null
        else
            echo "No se encontraron puertos UDP abiertos"
        fi
        echo ""
        
        echo "════════════════════════════════════════════════════════"
        echo "5. RECOMENDACIONES"
        echo "════════════════════════════════════════════════════════"
        echo "➜ Investigar servicios en puertos: $OPEN_PORTS"
        if [ -n "$WEB_URL" ] && [[ "$WEB_URL" =~ ^https?:// ]]; then
            echo "➜ Analizar servicio web: $WEB_URL"
            echo "➜ Revisar archivos expuestos encontrados"
        fi
        echo "➜ Verificar versiones de software para vulnerabilidades"
        echo "➜ Probar credenciales por defecto"
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "Reporte generado automáticamente por AutoRecon"
        echo "════════════════════════════════════════════════════════"
        
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}[✓] Reporte guardado en:${NC} $REPORT_FILE"
fi

# =============================================
# MOSTRAR RESUMEN FINAL
# =============================================
echo -e "\n${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    ESCANEO COMPLETADO                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo -e "${WHITE}Objetivo:${NC}     ${GREEN}$TARGET${NC}"
echo -e "${WHITE}Puertos TCP:${NC}   ${GREEN}${OPEN_PORTS:-Ninguno}${NC}"
if [ -n "$WEB_URL" ]; then
    echo -e "${WHITE}Servicio web:${NC} ${GREEN}$WEB_URL${NC}"
fi
echo -e "${WHITE}Finalizado:${NC}   $(date)"
echo ""

if [ "$SAVE_RESULTS" = true ]; then
    echo -e "${GREEN}📁 Resultados guardados en:${NC}"
    echo -e "  ${YELLOW}➜${NC} $OUTPUT_DIR/"
    echo -e "  ${YELLOW}➜${NC} Reporte: $REPORT_FILE"
    echo ""
    echo -e "${YELLOW}Para ver el reporte:${NC}"
    echo -e "  cat \"$REPORT_FILE\""
else
    echo -e "${YELLOW}Modo solo pantalla: No se guardaron archivos${NC}"
fi

echo -e "\n${GREEN}[✓] ¡Listo para análisis manual!${NC}"

# Limpiar archivos temporales
rm -f /tmp/nmap_scan_$$.txt /tmp/nmap_filtered_$$.txt /tmp/gobuster_*_$$.txt /tmp/udp_scan_$$.txt /tmp/medium_$$.txt 2>/dev/null
