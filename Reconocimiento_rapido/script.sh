#!/bin/bash

# Script de Automatización de Escaneo Inicial
# Autor: Ander-350-Coder
# Uso: ./autorecon.sh <TARGET_IP/DOMAIN>

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que se proporcionó un objetivo
if [ $# -eq 0 ]; then
    echo -e "${RED}[!] Uso: $0 <TARGET_IP/DOMAIN>${NC}"
    echo -e "${YELLOW}[*] Ejemplo: $0 192.168.1.100${NC}"
    echo -e "${YELLOW}[*] Ejemplo: $0 realgob.dl${NC}"
    echo -e "${YELLOW}[*] Ejemplo: $0 target.com${NC}"
    exit 1
fi

TARGET=$1
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="scan_results_${TARGET//[^a-zA-Z0-9]/_}_${TIMESTAMP}"
REPORT_FILE="${OUTPUT_DIR}/full_report.txt"

# Crear directorio de resultados
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}[+] Iniciando escaneo inicial contra: $TARGET${NC}"
echo -e "${GREEN}[+] Directorio de resultados: $OUTPUT_DIR${NC}"
echo ""

# Función para mostrar separadores
separator() {
    echo -e "${BLUE}=============================================${NC}"
}

# =============================================
# 1. ESCANEO NMAP CON -sCV
# =============================================
echo -e "${YELLOW}[*] Iniciando escaneo Nmap (sCV)...${NC}"
separator

# Archivos de salida
NMAP_SCAN_FILE="${OUTPUT_DIR}/nmap_full_scan.txt"
NMAP_FILTERED_FILE="${OUTPUT_DIR}/nmap_filtered.txt"

# Crear archivos ANTES de ejecutar
touch "$NMAP_SCAN_FILE"
touch "$NMAP_FILTERED_FILE"

# Escaneo completo con -sCV
echo -e "${YELLOW}[*] Ejecutando escaneo completo...${NC}"
nmap -sCV -T4 --min-rate=1000 -p- -oN "$NMAP_SCAN_FILE" "$TARGET" > /dev/null 2>&1

# Verificar que nmap se ejecutó correctamente
if [ ! -s "$NMAP_SCAN_FILE" ]; then
    echo -e "${RED}[!] ERROR: Nmap no generó resultados${NC}"
    echo -e "${YELLOW}[*] Probando escaneo alternativo...${NC}"
    nmap -sCV -T4 -p- "$TARGET" > "$NMAP_SCAN_FILE" 2>&1
fi

# Filtrar información importante
echo -e "${GREEN}[+] Extraendo información relevante...${NC}"

# Extraer puertos abiertos
OPEN_PORTS=$(grep -E "^[0-9]+/tcp.*open" "$NMAP_SCAN_FILE" 2>/dev/null | awk '{print $1}' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')

# Mostrar resultados filtrados
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
    
    # Extraer sección por sección
    awk '/^PORT.*STATE.*SERVICE/,/^$/' "$NMAP_SCAN_FILE" 2>/dev/null | head -50
    
    echo ""
    echo "Información Adicional:"
    echo "---------------------"
    grep -A 5 "Service detection performed\|Nmap done" "$NMAP_SCAN_FILE" 2>/dev/null | head -10
    
} > "$NMAP_FILTERED_FILE"

# Mostrar resumen de nmap
echo -e "${GREEN}[+] Escaneo Nmap completado${NC}"
echo -e "${YELLOW}[*] Puertos TCP abiertos encontrados:${NC}"
if [ -n "$OPEN_PORTS" ] && [ "$OPEN_PORTS" != "" ]; then
    echo -e "${GREEN}$OPEN_PORTS${NC}"
else
    echo -e "${RED}[-] No se encontraron puertos TCP abiertos${NC}"
fi

# Mostrar servicios principales
echo -e "\n${YELLOW}[*] Servicios principales detectados:${NC}"
grep -E "^[0-9]+/tcp.*open.*[a-zA-Z]" "$NMAP_SCAN_FILE" 2>/dev/null | head -10 | while read -r service; do
    port=$(echo "$service" | awk '{print $1}')
    service_name=$(echo "$service" | awk '{print $3}')
    version=$(echo "$service" | cut -d' ' -f4-)
    echo -e "${GREEN}  $port - $service_name${NC}"
    [ -n "$version" ] && echo "      Versión: $version"
done

# =============================================
# 2. DETECCIÓN DE SERVICIOS WEB (SIMPLIFICADA)
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
    # Verificar si el objetivo parece un dominio (tiene letras)
    if [[ "$TARGET" =~ [a-zA-Z] ]]; then
        echo -e "${YELLOW}[*] Objetivo parece dominio, probando HTTP/HTTPS...${NC}"
        
        # Probar HTTP primero
        HTTP_CODE=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://$TARGET" 2>/dev/null || echo "FAILED")
        if [[ "$HTTP_CODE" =~ ^[234] ]]; then
            WEB_URL="http://$TARGET"
            echo -e "${GREEN}[+] Dominio responde a HTTP (código $HTTP_CODE)${NC}"
        else
            # Probar HTTPS
            HTTPS_CODE=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "https://$TARGET" 2>/dev/null || echo "FAILED")
            if [[ "$HTTPS_CODE" =~ ^[234] ]]; then
                WEB_URL="https://$TARGET"
                echo -e "${GREEN}[+] Dominio responde a HTTPS (código $HTTPS_CODE)${NC}"
            fi
        fi
    fi
fi

# =============================================
# 3. ESCANEO GOBUSTER - SI HAY URL WEB
# =============================================
if [ -n "$WEB_URL" ] && [[ "$WEB_URL" =~ ^https?:// ]]; then
    echo -e "\n${GREEN}[+] Servicio web detectado en: $WEB_URL${NC}"
    
    # Limpiar URL (quitar / al final si existe)
    WEB_URL=$(echo "$WEB_URL" | sed 's|/$||')
    echo -e "${YELLOW}[*] URL final para escaneo: $WEB_URL${NC}"
    
    # Obtener puerto de la URL
    PORT_NUM="web"
    if echo "$WEB_URL" | grep -q ":443"; then
        PORT_NUM="443"
    elif echo "$WEB_URL" | grep -q ":80"; then
        PORT_NUM="80"
    fi
    
    # =============================================
    # CONFIGURACIÓN DE DICCIONARIOS
    # =============================================
    
    # Diccionario COMMON (básico)
    DICT_COMMON="/usr/share/wordlists/dirb/common.txt"
    
    # Diccionario MEDIUM (Seclists completo) - TU RUTA
    DICT_MEDIUM="/home/kali/Seclist-Dicctionaries/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt"
    
    echo -e "${YELLOW}[*] Usando direcciones exactas de diccionarios${NC}"
    echo -e "${GREEN}[+] Diccionario common: $DICT_COMMON${NC}"
    echo -e "${GREEN}[+] Diccionario medium: $DICT_MEDIUM${NC}"
    
    # Verificación de diccionarios
    if [ ! -f "$DICT_COMMON" ]; then
        echo -e "${RED}[!] ERROR: No se encontró el diccionario common.txt${NC}"
        echo -e "${YELLOW}[*] Creando diccionario temporal mínimo...${NC}"
        DICT_COMMON="${OUTPUT_DIR}/common_mini.txt"
        echo -e "admin\nlogin\ndashboard\napi\ntest\nbackup\nconfig\nwp-admin\nphpmyadmin\nserver-status" > "$DICT_COMMON"
    fi
    
    if [ ! -f "$DICT_MEDIUM" ]; then
        echo -e "${RED}[!] ERROR: No se encontró el diccionario medium${NC}"
        echo -e "${YELLOW}[*] Usando diccionario common para ambos escaneos${NC}"
        DICT_MEDIUM="$DICT_COMMON"
    fi
    
    # =============================================
    # ARCHIVOS DE SALIDA
    # =============================================
    GOBUSTER_COMMON_FILE="${OUTPUT_DIR}/gobuster_common_${PORT_NUM}.txt"
    GOBUSTER_MEDIUM_FILE="${OUTPUT_DIR}/gobuster_medium_${PORT_NUM}.txt"
    GOBUSTER_FILTERED_FILE="${OUTPUT_DIR}/gobuster_filtered_${PORT_NUM}.txt"
    GOBUSTER_LOG_FILE="${OUTPUT_DIR}/gobuster_execution.log"
    
    # Crear archivos vacíos ANTES de ejecutar
    > "$GOBUSTER_COMMON_FILE"
    > "$GOBUSTER_MEDIUM_FILE"
    > "$GOBUSTER_FILTERED_FILE"
    > "$GOBUSTER_LOG_FILE"
    
    # =============================================
    # DIAGNÓSTICO RÁPIDO DEL SITIO
    # =============================================
    echo -e "\n${YELLOW}[*] Realizando diagnóstico rápido...${NC}"
    
    HTTP_CODE=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" "$WEB_URL" 2>/dev/null || echo "FAILED")
    echo -e "${YELLOW}[*] Código HTTP: $HTTP_CODE${NC}"
    
    if [[ "$HTTP_CODE" =~ ^[234] ]]; then
        echo -e "${GREEN}[+] Sitio accesible, procediendo con escaneo...${NC}"
        CAN_SCAN=true
    else
        echo -e "${RED}[!] Sitio no accesible (HTTP $HTTP_CODE)${NC}"
        echo -e "${YELLOW}[*] Intentando con -k (ignore SSL)...${NC}"
        
        # Probar ignorando SSL
        HTTP_CODE_SSL=$(timeout 10 curl -s -o /dev/null -w "%{http_code}" -k "$WEB_URL" 2>/dev/null || echo "FAILED")
        if [[ "$HTTP_CODE_SSL" =~ ^[234] ]]; then
            echo -e "${GREEN}[+] Sitio accesible con -k, ajustando comando...${NC}"
            # Añadir flag -k a Gobuster
            GOBUSTER_SSL_FLAG="-k"
            CAN_SCAN=true
        else
            CAN_SCAN=false
            echo -e "${RED}[!] No se puede acceder al sitio${NC}"
        fi
    fi
    
    # =============================================
    # EJECUTAR GOBUSTER
    # =============================================
    if [ "$CAN_SCAN" = true ]; then
        # Función para ejecutar gobuster
        run_gobuster() {
            local dict_type=$1
            local dict_file=$2
            local output_file=$3
            local extensions=$4
            
            echo -e "\n${YELLOW}[*] Ejecutando Gobuster ($dict_type)...${NC}"
            echo -e "${YELLOW}[*] Comando: gobuster dir -u \"$WEB_URL\" -w \"$dict_file\" -t 20 -x $extensions ${GOBUSTER_SSL_FLAG}${NC}"
            
            # Construir comando
            CMD="gobuster dir -u \"$WEB_URL\" -w \"$dict_file\" -t 20 -x $extensions"
            [ -n "$GOBUSTER_SSL_FLAG" ] && CMD="$CMD $GOBUSTER_SSL_FLAG"
            CMD="$CMD -o \"$output_file\""
            
            # Ejecutar
            echo -e "${YELLOW}[*] Iniciando... (puede tardar varios minutos)${NC}"
            eval timeout 600 $CMD 2>&1 | tee -a "$GOBUSTER_LOG_FILE"
            
            local exit_code=${PIPESTATUS[0]}
            
            if [ $exit_code -eq 0 ]; then
                echo -e "${GREEN}[✓] Gobuster ($dict_type) completado${NC}"
                return 0
            elif [ $exit_code -eq 124 ]; then
                echo -e "${YELLOW}[!] Gobuster ($dict_type) timeout (10 minutos)${NC}"
                return 1
            else
                echo -e "${RED}[✗] Gobuster ($dict_type) falló (código $exit_code)${NC}"
                return 1
            fi
        }
        
        # Ejecutar Gobuster con common
        run_gobuster "common" "$DICT_COMMON" "$GOBUSTER_COMMON_FILE" "php,txt,html,js,json"
        COMMON_SUCCESS=$?
        
        # Ejecutar Gobuster con medium (siempre, no solo si common tuvo éxito)
        echo -e "\n${YELLOW}[*] Continuando con diccionario medium...${NC}"
        run_gobuster "medium" "$DICT_MEDIUM" "$GOBUSTER_MEDIUM_FILE" "php,txt,html,js,json,zip,bak,old,backup,sql,config,env"
        
        # =============================================
        # PROCESAR RESULTADOS
        # =============================================
        echo -e "\n${GREEN}[+] Procesando resultados...${NC}"
        
        # Contar resultados
        COMMON_RESULTS=0
        MEDIUM_RESULTS=0
        
        if [ -f "$GOBUSTER_COMMON_FILE" ] && [ -s "$GOBUSTER_COMMON_FILE" ]; then
            COMMON_RESULTS=$(grep -c "Status:" "$GOBUSTER_COMMON_FILE" 2>/dev/null || echo 0)
        fi
        
        if [ -f "$GOBUSTER_MEDIUM_FILE" ] && [ -s "$GOBUSTER_MEDIUM_FILE" ]; then
            MEDIUM_RESULTS=$(grep -c "Status:" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null || echo 0)
        fi
        
        # Crear archivo filtrado
        {
            echo "RESULTADOS GOBUSTER"
            echo "==================="
            echo "URL: $WEB_URL"
            echo "Fecha: $(date)"
            echo "Diccionarios:"
            echo "  - Common: $DICT_COMMON"
            echo "  - Medium: $DICT_MEDIUM"
            echo ""
            echo "ESTADÍSTICAS:"
            echo "-------------"
            echo "Resultados common: $COMMON_RESULTS"
            echo "Resultados medium: $MEDIUM_RESULTS"
            echo ""
            
            if [ "$COMMON_RESULTS" -gt 0 ]; then
                echo "RESULTADOS COMMON (todos):"
                echo "-------------------------"
                cat "$GOBUSTER_COMMON_FILE"
                echo ""
            else
                echo "No se encontraron resultados con diccionario common"
                echo ""
            fi
            
            if [ "$MEDIUM_RESULTS" -gt 0 ]; then
                echo "RESULTADOS MEDIUM (más relevantes):"
                echo "----------------------------------"
                # Filtrar resultados interesantes
                grep -E "Status: (200|301|302|307|403|401)" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | \
                grep -E "\.(php|txt|sql|log|bak|config|ini|env|sh|py|xml|json)" 2>/dev/null | \
                grep -E "(admin|login|backup|config|test|debug|api|dashboard|private|secret|wp|cms|drupal|joomla)" 2>/dev/null | \
                head -30
                echo ""
                
                echo "ARCHIVOS DE CONFIGURACIÓN ENCONTRADOS:"
                echo "--------------------------------------"
                grep -E "Status: (200|301|302|307|403|401)" "$GOBUSTER_MEDIUM_FILE" 2>/dev/null | \
                grep -E "\.(config|ini|env|cfg|conf|properties|yml|yaml|xml|json)$" 2>/dev/null | \
                head -15
            else
                echo "No se encontraron resultados con diccionario medium"
                echo ""
            fi
            
        } > "$GOBUSTER_FILTERED_FILE"
        
        # Mostrar resumen
        echo -e "${GREEN}[+] Escaneo Gobuster completado${NC}"
        echo -e "${YELLOW}[*] Resultados encontrados:${NC}"
        echo -e "  Common: ${GREEN}$COMMON_RESULTS${NC} resultados"
        echo -e "  Medium: ${GREEN}$MEDIUM_RESULTS${NC} resultados"
        
        # Mostrar algunos resultados si hay
        if [ "$COMMON_RESULTS" -gt 0 ]; then
            echo -e "\n${YELLOW}[*] Algunos resultados common:${NC}"
            grep "Status:" "$GOBUSTER_COMMON_FILE" 2>/dev/null | head -5
        fi
        
    else
        echo -e "${RED}[!] No se pudo ejecutar Gobuster - sitio no accesible${NC}"
        echo "Sitio web no accesible" > "$GOBUSTER_FILTERED_FILE"
    fi
    
else
    echo -e "${YELLOW}[*] No se detectaron servicios web accesibles${NC}"
fi

# =============================================
# 4. ESCANEO UDP RÁPIDO
# =============================================
echo -e "\n${YELLOW}[*] Ejecutando escaneo UDP rápido...${NC}"
separator

UDP_SCAN_FILE="${OUTPUT_DIR}/nmap_udp_scan.txt"
UDP_PORTS="53,67,68,69,123,161,162,500,514,520,623,998"

# Crear archivo antes
> "$UDP_SCAN_FILE"

nmap -sU -T4 -p $UDP_PORTS --open -oN "$UDP_SCAN_FILE" "$TARGET" > /dev/null 2>&1

if grep -q "open" "$UDP_SCAN_FILE" 2>/dev/null; then
    echo -e "${GREEN}[+] Puertos UDP abiertos encontrados:${NC}"
    grep "open" "$UDP_SCAN_FILE" 2>/dev/null | while read -r line; do
        port=$(echo "$line" | awk '{print $1}')
        service=$(echo "$line" | awk '{print $3}')
        echo -e "  ${GREEN}$port - $service${NC}"
    done
else
    echo -e "${RED}[-] No se encontraron puertos UDP abiertos${NC}"
fi

# =============================================
# 5. GENERAR REPORTE FINAL
# =============================================
echo -e "\n${GREEN}[+] Generando reporte final...${NC}"
separator

{
    echo "REPORTE COMPLETO DE ESCANEO INICIAL - AUTORECON"
    echo "================================================"
    echo "Objetivo: $TARGET"
    echo "Fecha: $(date)"
    echo "Directorio: $OUTPUT_DIR"
    echo ""
    echo "1. RESUMEN EJECUTIVO"
    echo "===================="
    echo "Puertos TCP abiertos: ${OPEN_PORTS:-Ninguno}"
    echo "Servicios web detectados: ${WEB_URL:-Ninguno}"
    echo ""
    
    echo "2. ESCANEO NMAP (sCV)"
    echo "====================="
    [ -f "$NMAP_FILTERED_FILE" ] && cat "$NMAP_FILTERED_FILE" || echo "No disponible"
    echo ""
    
    echo "3. ESCANEO GOBUSTER"
    echo "==================="
    if [ -f "$GOBUSTER_FILTERED_FILE" ]; then
        cat "$GOBUSTER_FILTERED_FILE"
    else
        echo "No se realizó escaneo web"
    fi
    echo ""
    
    echo "4. ESCANEO UDP"
    echo "=============="
    if [ -f "$UDP_SCAN_FILE" ] && grep -q "open" "$UDP_SCAN_FILE" 2>/dev/null; then
        grep -E "PORT|open" "$UDP_SCAN_FILE" 2>/dev/null
    else
        echo "No se encontraron puertos UDP abiertos"
    fi
    echo ""
    
    echo "5. RECOMENDACIONES"
    echo "=================="
    echo "1. Investigar servicios en puertos: $OPEN_PORTS"
    if [ -n "$WEB_URL" ] && [[ "$WEB_URL" =~ ^https?:// ]]; then
        echo "2. Analizar servicio web: $WEB_URL"
        echo "3. Revisar archivos expuestos encontrados"
        echo "4. Probar vulnerabilidades según versiones detectadas"
    fi
    echo "5. Verificar configuraciones por defecto"
    echo "6. Realizar pruebas de autenticación si aplica"
    echo ""
    echo "================================================"
    echo "Reporte generado automáticamente por AutoRecon"
    echo "================================================"
    
} > "$REPORT_FILE"

# Mostrar resumen final
echo -e "${GREEN}[+] ESCANEO COMPLETADO${NC}"
separator
echo -e "${YELLOW}[*] Resumen del escaneo:${NC}"
echo -e "  - Objetivo: ${GREEN}$TARGET${NC}"
echo -e "  - Puertos TCP abiertos: ${GREEN}${OPEN_PORTS:-Ninguno}${NC}"
if [ -n "$WEB_URL" ] && [[ "$WEB_URL" =~ ^https?:// ]]; then
    echo -e "  - Servicio web: ${GREEN}$WEB_URL${NC}"
    if [ -f "$GOBUSTER_FILTERED_FILE" ]; then
        COMMON_RESULTS=$(grep "Resultados common:" "$GOBUSTER_FILTERED_FILE" 2>/dev/null | awk '{print $3}')
        MEDIUM_RESULTS=$(grep "Resultados medium:" "$GOBUSTER_FILTERED_FILE" 2>/dev/null | awk '{print $3}')
        echo -e "  - Resultados Gobuster: ${GREEN}Common=$COMMON_RESULTS, Medium=$MEDIUM_RESULTS${NC}"
    fi
fi
echo -e "  - Reporte completo: ${GREEN}$REPORT_FILE${NC}"
echo ""
echo -e "${YELLOW}[*] Archivos generados:${NC}"
ls -1 "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.log 2>/dev/null | head -15 | while read file; do
    filename=$(basename "$file")
    echo -e "  - ${GREEN}$filename${NC}"
done
echo ""
echo -e "${GREEN}[+] Para ver el reporte completo:${NC}"
echo -e "    ${YELLOW}cat \"$REPORT_FILE\"${NC}"
echo ""
echo -e "${GREEN}[+] Para ver logs de ejecución:${NC}"
echo -e "    ${YELLOW}cat \"$OUTPUT_DIR/gobuster_execution.log\"${NC}"
echo ""
echo -e "${GREEN}[✓] ¡Listo para análisis manual!${NC}"