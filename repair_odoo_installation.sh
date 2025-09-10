#!/bin/bash
################################################################################
# Script de reparación para instalación de Odoo en Debian 12
# Soluciona problemas comunes después de una instalación fallida
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_VERSION="18.0"
OE_CONFIG="${OE_USER}-server"
OE_PORT="8069"

echo "🔧 REPARANDO INSTALACIÓN DE ODOO"
echo "=================================="

# 1. REINSTALAR Y FIJAR GIT
echo "--- Paso 1: Reinstalando Git ---"
sudo apt-get update
sudo apt-get remove git -y 2>/dev/null || true
sudo apt-get autoremove -y
sudo apt-get install git -y

# Marcar git como manualmente instalado para evitar que se desinstale
sudo apt-mark manual git

if command -v git &> /dev/null; then
    echo "✓ Git reinstalado correctamente: $(git --version)"
else
    echo "❌ ERROR: No se pudo reinstalar Git"
    echo "Instalando desde backports..."
    sudo apt-get install -t bullseye-backports git -y 2>/dev/null || true
    
    if ! command -v git &> /dev/null; then
        echo "❌ CRÍTICO: Git no se puede instalar. Abortando."
        exit 1
    fi
fi

# 2. VERIFICAR Y CREAR ESTRUCTURA DE DIRECTORIOS
echo "--- Paso 2: Verificando estructura de directorios ---"

# Crear usuario odoo si no existe
if ! id "$OE_USER" &>/dev/null; then
    echo "Creando usuario $OE_USER..."
    sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
    sudo adduser $OE_USER sudo
fi

# Crear directorios
sudo mkdir -p $OE_HOME_EXT
sudo mkdir -p $OE_HOME/custom/addons
sudo mkdir -p /var/log/$OE_USER

echo "✓ Estructura de directorios verificada"

# 3. LIMPIAR Y CLONAR ODOO
echo "--- Paso 3: Clonando Odoo ---"

# Detener servicio si está corriendo
sudo systemctl stop ${OE_CONFIG}.service 2>/dev/null || true

# Limpiar directorio completamente
echo "Limpiando directorio $OE_HOME_EXT..."
sudo rm -rf $OE_HOME_EXT/*
sudo rm -rf $OE_HOME_EXT/.git 2>/dev/null || true

# Clonar Odoo con verificación
echo "Clonando Odoo $OE_VERSION..."
cd /tmp

# Usar método más robusto
if sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo.git odoo-temp; then
    echo "✓ Clone temporal exitoso"
    
    # Mover archivos al directorio final
    sudo mv odoo-temp/* $OE_HOME_EXT/
    sudo mv odoo-temp/.* $OE_HOME_EXT/ 2>/dev/null || true
    sudo rm -rf odoo-temp
    
    if [ -f "$OE_HOME_EXT/odoo-bin" ]; then
        echo "✓ Odoo clonado exitosamente"
    else
        echo "❌ ERROR: odoo-bin no encontrado después del clone"
    fi
else
    echo "❌ ERROR: No se pudo clonar Odoo"
    
    # Método alternativo: descargar ZIP
    echo "Intentando descarga directa..."
    wget -q https://github.com/odoo/odoo/archive/refs/heads/$OE_VERSION.zip -O /tmp/odoo.zip
    
    if [ -f "/tmp/odoo.zip" ]; then
        cd /tmp
        unzip -q odoo.zip
        sudo mv odoo-$OE_VERSION/* $OE_HOME_EXT/
        sudo rm -rf odoo-$OE_VERSION odoo.zip
        echo "✓ Odoo descargado vía ZIP"
    else
        echo "❌ CRÍTICO: No se pudo descargar Odoo"
        exit 1
    fi
fi

# 4. VERIFICAR ARCHIVOS CRÍTICOS
echo "--- Paso 4: Verificando archivos críticos ---"

critical_files=(
    "$OE_HOME_EXT/odoo-bin"
    "$OE_HOME_EXT/addons"
    "$OE_HOME_EXT/odoo"
)

all_good=true
for file in "${critical_files[@]}"; do
    if [ -e "$file" ]; then
        echo "✓ $file - EXISTE"
    else
        echo "❌ $file - NO ENCONTRADO"
        all_good=false
    fi
done

if [ "$all_good" = false ]; then
    echo "❌ CRÍTICO: Faltan archivos esenciales de Odoo"
    echo "Listando contenido del directorio:"
    ls -la $OE_HOME_EXT/
    exit 1
fi

# 5. CONFIGURAR PERMISOS
echo "--- Paso 5: Configurando permisos ---"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*
sudo chown -R $OE_USER:$OE_USER /var/log/$OE_USER
sudo chmod +x $OE_HOME_EXT/odoo-bin

echo "✓ Permisos configurados"

# 6. VERIFICAR/REPARAR CONFIGURACIÓN
echo "--- Paso 6: Verificando configuración ---"

if [ ! -f "/etc/${OE_CONFIG}.conf" ]; then
    echo "Creando archivo de configuración..."
    
    # Generar password aleatorio si no existe
    if [ -z "$OE_SUPERADMIN" ]; then
        OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    fi
    
    sudo tee /etc/${OE_CONFIG}.conf > /dev/null <<EOF
[options] 
; This is the password that allows database operations:
admin_passwd = ${OE_SUPERADMIN}
http_port = ${OE_PORT}
logfile = /var/log/${OE_USER}/${OE_CONFIG}.log
addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons
EOF
    
    sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
    sudo chmod 640 /etc/${OE_CONFIG}.conf
    echo "✓ Configuración creada"
else
    echo "✓ Configuración ya existe"
fi

# 7. REPARAR SERVICIO SYSTEMD
echo "--- Paso 7: Reparando servicio systemd ---"

sudo tee /etc/systemd/system/${OE_CONFIG}.service > /dev/null <<EOF
[Unit]
Description=Odoo${OE_VERSION}
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo${OE_VERSION}
PermissionsStartOnly=true
User=${OE_USER}
Group=${OE_USER}
ExecStart=${OE_HOME_EXT}/odoo-bin -c /etc/${OE_CONFIG}.conf
StandardOutput=journal+console
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}.service

echo "✓ Servicio systemd reparado"

# 8. PROBAR INSTALACIÓN
echo "--- Paso 8: Probando instalación ---"

# Hacer una prueba básica de Odoo
echo "Probando odoo-bin..."
if sudo -u $OE_USER timeout 10s $OE_HOME_EXT/odoo-bin --help > /dev/null 2>&1; then
    echo "✓ odoo-bin responde correctamente"
else
    echo "⚠️  odoo-bin puede tener problemas, pero continuando..."
fi

# Iniciar servicio
echo "Iniciando servicio Odoo..."
sudo systemctl start ${OE_CONFIG}.service

sleep 5

# 9. VERIFICACIÓN FINAL
echo "--- VERIFICACIÓN FINAL ---"
echo "=========================="

verification_failed=false

echo -n "Git: "
if command -v git &> /dev/null; then
    echo "✅ $(git --version)"
else
    echo "❌ NO ENCONTRADO"
    verification_failed=true
fi

echo -n "Odoo binary: "
if [ -f "$OE_HOME_EXT/odoo-bin" ] && [ -x "$OE_HOME_EXT/odoo-bin" ]; then
    echo "✅ EXISTE y es ejecutable"
else
    echo "❌ NO ENCONTRADO o no ejecutable"
    verification_failed=true
fi

echo -n "Odoo addons: "
if [ -d "$OE_HOME_EXT/addons" ]; then
    addon_count=$(ls -1 "$OE_HOME_EXT/addons" 2>/dev/null | wc -l)
    echo "✅ $addon_count módulos encontrados"
else
    echo "❌ DIRECTORIO NO ENCONTRADO"
    verification_failed=true
fi

echo -n "Servicio Odoo: "
if sudo systemctl is-active --quiet ${OE_CONFIG}.service; then
    echo "✅ CORRIENDO"
else
    echo "❌ NO CORRIENDO"
    echo "Ver logs: sudo journalctl -u ${OE_CONFIG}.service -n 20"
    verification_failed=true
fi

echo ""
if [ "$verification_failed" = false ]; then
    echo "🎉 ¡REPARACIÓN EXITOSA!"
    echo "Odoo está disponible en: http://localhost:$OE_PORT"
    echo "Logs en tiempo real: sudo journalctl -u ${OE_CONFIG}.service -f"
else
    echo "⚠️  ALGUNOS PROBLEMAS PERSISTEN"
    echo "Revisa los logs para más detalles:"
    echo "sudo journalctl -u ${OE_CONFIG}.service -n 50"
fi

echo ""
echo "COMANDOS ÚTILES:"
echo "================"
echo "Ver estado: sudo systemctl status ${OE_CONFIG}.service"
echo "Ver logs: sudo journalctl -u ${OE_CONFIG}.service -f"
echo "Reiniciar: sudo systemctl restart ${OE_CONFIG}.service"
echo "Parar: sudo systemctl stop ${OE_CONFIG}.service"