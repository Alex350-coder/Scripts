📄 README - AutoRecon
markdown
# AutoRecon - Escáner Automático de Puertos y Directorios

![Bash](https://img.shields.io/badge/Bash-5.0+-blue)
![Nmap](https://img.shields.io/badge/Nmap-7.0+-orange)
![Gobuster](https://img.shields.io/badge/Gobuster-3.0+-purple)

## 📋 Descripción
Script automatizado para escaneo inicial en pentesting. Combina **Nmap** (puertos/servicios) y **Gobuster** (fuzzing web) con output limpio y profesional.

## 🚀 Instalación
```bash
git clone https://github.com/tuusuario/autorecon.git
cd autorecon
chmod +x autorecon.sh
🛠️ Requisitos
bash📄 README - AutoRecon
markdown
# AutoRecon - Escáner Automático de Puertos y Directorios

![Bash](https://img.shields.io/badge/Bash-5.0+-blue)
![Nmap](https://img.shields.io/badge/Nmap-7.0+-orange)
![Gobuster](https://img.shields.io/badge/Gobuster-3.0+-purple)
```
## 📋 Descripción
Script automatizado para escaneo inicial en pentesting. Combina **Nmap** (puertos/servicios) y **Gobuster** (fuzzing web) con output limpio y profesional.

## 🚀 Instalación
```bash
git clone https://github.com/tuusuario/autorecon.git
cd autorecon
chmod +x autorecon.sh
```
🛠️ Requisitos
```bash
sudo apt install nmap gobuster seclists curl
```
📖 Uso Básico
```bash
./autorecon.sh <IP/DOMINIO>
Ejemplos
bash
./autorecon.sh 192.168.1.100
./autorecon.sh realgob.dl
./autorecon.sh target.com
```
# ✨ Características
🔍 Escaneo Nmap completo (-sCV) con detección de versiones

🌐 Detección automática de servicios web (HTTP/HTTPS)

📁 Fuzzing con diccionario medium de SecLists

🎯 Output limpio - solo muestra directorios encontrados

📊 Modo interactivo (elige si guardar reportes)

🔒 Manejo automático de SSL (-k cuando necesario)

# 💻 Modo Interactivo
text
┌─[ CONFIGURACIÓN ]────────────┐
│  ¿Generar archivos? (s/n)    │
└─────────────────────────────┘
➜ s  # Guarda resultados en archivos
➜ n  # Solo muestra en pantalla
## 📁 Estructura de Archivos
text
scan_results_objetivo_fecha/
├── full_report.txt
├── nmap_full_scan.txt
├── nmap_filtered.txt
├── gobuster_medium_80.txt
├── gobuster_filtered_80.txt
└── nmap_udp_scan.txt
🎯 Output de Ejemplo
text
╔════════════════════════════════════╗
║        AUTORECON - v1.0            ║
╚════════════════════════════════════╝
Objetivo: realgob.dl

[+] Puertos abiertos: 22,80,3306
[+] Servicio web: http://realgob.dl

# 📁 DIRECTORIOS ENCONTRADOS:
════════════════════════════════════
  ✓ admin
  ✓ login
  ↻ assets [redirect]
  ✓ backup.sql
  ✓ .env
════════════════════════════════════
Total: 5 elementos

[✓] Escaneo completado

⚙️ Configuración
Edita las rutas de diccionarios en el script:

bash
DICT_MEDIUM="/ruta/a/tu/diccionario-medium.txt"
🎨 Iconos
✓ → 200 OK

↻ → Redirección

⛔ → 403 Prohibido

🔒 → 401 Auth requerida

⚠️ Legal
Solo usar en sistemas autorizados. El uso no autorizado es ilegal.

📝 Licencia
MIT

Happy Hacking! 🚀

