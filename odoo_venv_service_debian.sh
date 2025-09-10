#!/bin/bash
################################################################################
# Script para convertir el servicio Odoo a entorno virtual
# Ejecutar después de crear el entorno virtual de Odoo
################################################################################

# Configuración (ajusta estos valores según tu instalación)
OE_USER="odoo"
OE_CONFIG="odoo-server"
OE_HOME="/odoo"
OE_HOME_EXT="/odoo/odoo-server"
VENV_PATH="/odoo/venv"

echo "🔧 CONVIRTIENDO SERVICIO ODOO A ENTORNO VIRTUAL"
echo "================================================"

# Verificar que el entorno virtual existe
if [ ! -d "$VENV_PATH" ]; then
    echo "❌ ERROR: El entorno virtual no existe en $VENV_PATH"
    echo "Primero debes crear el entorno virtual:"
    echo "sudo -u $OE_USER python3 -m venv $VENV_PATH"
    exit 1
fi

# Verificar que odoo-bin existe
if [ ! -f "$OE_HOME_EXT/odoo-bin" ]; then
    echo "❌ ERROR: odoo-bin no encontrado en $OE_HOME_EXT/odoo-bin"
    exit 1
fi

# Detener el servicio actual
echo "Deteniendo servicio Odoo actual..."
sudo systemctl stop ${OE_CONFIG}.service

# Crear el nuevo archivo de servicio systemd con entorno virtual
echo "Creando nuevo archivo de servicio systemd con entorno virtual..."
sudo tee /etc/systemd/system/${OE_CONFIG}.service > /dev/null <<EOF
[Unit]
Description=Odoo Server (Virtual Environment)
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=notify
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=${OE_USER}
Group=${OE_USER}
Environment=PATH="${VENV_PATH}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment=VIRTUAL_ENV="${VENV_PATH}"
ExecStart=${VENV_PATH}/bin/python3 ${OE_HOME_EXT}/odoo-bin -c /etc/${OE_CONFIG}.conf
WorkingDirectory=${OE_HOME_EXT}
StandardOutput=journal+console
StandardError=journal+console
Restart=on-failure
RestartSec=10s
KillMode=mixed
TimeoutStopSec=60s

# Límites de recursos (opcional, ajusta según tus necesidades)
LimitNOFILE=65536
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Archivo de servicio actualizado"

# Recargar systemd
echo "Recargando configuración de systemd..."
sudo systemctl daemon-reload

# Habilitar el servicio
echo "Habilitando servicio..."
sudo systemctl enable ${OE_CONFIG}.service

# Verificar que el entorno virtual tiene las dependencias necesarias
echo "Verificando dependencias en el entorno virtual..."
sudo -u $OE_USER $VENV_PATH/bin/pip list | grep -E "(psycopg2|lxml|Pillow|reportlab)" || {
    echo "⚠️  Advertencia: Algunas dependencias pueden faltar en el entorno virtual"
    echo "Instala las dependencias con:"
    echo "sudo -u $OE_USER $VENV_PATH/bin/pip install -r $OE_HOME_EXT/requirements.txt"
}

# Crear script de inicio actualizado
echo "Actualizando script de inicio..."
sudo tee $OE_HOME_EXT/start.sh > /dev/null <<EOF
#!/bin/bash
# Script de inicio de Odoo con entorno virtual
source $VENV_PATH/bin/activate
exec $VENV_PATH/bin/python3 $OE_HOME_EXT/odoo-bin -c /etc/${OE_CONFIG}.conf
EOF
sudo chmod 755 $OE_HOME_EXT/start.sh
sudo chown $OE_USER:$OE_USER $OE_HOME_EXT/start.sh

# Intentar iniciar el servicio
echo "Iniciando servicio Odoo con entorno virtual..."
sudo systemctl start ${OE_CONFIG}.service

# Esperar un momento y verificar el estado
sleep 3
echo ""
echo "🔍 VERIFICACIÓN DEL SERVICIO"
echo "============================"

if sudo systemctl is-active --quiet ${OE_CONFIG}.service; then
    echo "✅ Servicio iniciado correctamente"
    echo "Estado: $(sudo systemctl is-active ${OE_CONFIG}.service)"
else
    echo "❌ Servicio falló al iniciar"
    echo "Estado: $(sudo systemctl is-active ${OE_CONFIG}.service)"
    echo ""
    echo "📋 LOGS DEL SERVICIO (últimas 10 líneas):"
    sudo journalctl -u ${OE_CONFIG}.service -n 10 --no-pager
fi

echo ""
echo "📋 INFORMACIÓN DEL SERVICIO ACTUALIZADO"
echo "========================================"
echo "Servicio: ${OE_CONFIG}.service"
echo "Entorno virtual: $VENV_PATH"
echo "Python del entorno: $VENV_PATH/bin/python3"
echo "Odoo binary: $OE_HOME_EXT/odoo-bin"
echo "Archivo de configuración: /etc/${OE_CONFIG}.conf"
echo ""
echo "🚀 COMANDOS ÚTILES:"
echo "Ver estado: sudo systemctl status $OE_CONFIG"
echo "Ver logs: sudo journalctl -u $OE_CONFIG -f"
echo "Reiniciar: sudo systemctl restart $OE_CONFIG"
echo "Detener: sudo systemctl stop $OE_CONFIG"
echo ""
echo "🔧 PARA ACTIVAR MANUALMENTE EL ENTORNO VIRTUAL:"
echo "sudo -u $OE_USER bash"
echo "source $VENV_PATH/bin/activate"
echo ""