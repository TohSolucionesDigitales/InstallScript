#!/bin/bash
################################################################################
# Script mejorado para instalar Odoo 16 con ambiente virtual
# Basado en el script de Yenthe Van Ginneken
# Mejoras: Ambiente virtual, systemd, optimización para grandes volúmenes
#-------------------------------------------------------------------------------
# Este script instala Odoo 16 en un ambiente virtual separado
# Compatible con instalación de Odoo 19 en paralelo
#-------------------------------------------------------------------------------
# Uso:
# sudo chmod +x odoo16_install_improved.sh
# ./odoo16_install_improved.sh
################################################################################

# ====== CONFIGURACIÓN BÁSICA ======
OE_USER="odoo16"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="$OE_HOME/odoo-server"
VENV_PATH="$OE_HOME/venv"

# ====== CONFIGURACIÓN DE VERSIÓN ======
OE_VERSION="16.0"
IS_ENTERPRISE="False"

# ====== CONFIGURACIÓN DE PUERTOS ======
# Puerto HTTP principal (diferente al de Odoo 19)
OE_PORT="8016"
# Puerto longpolling (diferente al de Odoo 19)
LONGPOLLING_PORT="8116"

# ====== CONFIGURACIÓN DE BASE DE DATOS ======
# Usuario PostgreSQL dedicado para Odoo 16
DB_USER="odoo16"
DB_PASSWORD="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)"

# ====== CONFIGURACIÓN DE SISTEMA ======
INSTALL_WKHTMLTOPDF="True"
INSTALL_POSTGRESQL_FOURTEEN="True"
INSTALL_NGINX="False"

# ====== CONFIGURACIÓN DE SEGURIDAD ======
OE_SUPERADMIN="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)"
OE_CONFIG="${OE_USER}"

# ====== CONFIGURACIÓN SSL (si aplica) ======
ENABLE_SSL="False"
WEBSITE_NAME="odoo16.example.com"
ADMIN_EMAIL="admin@example.com"

# ====== CONFIGURACIÓN PARA ALTO VOLUMEN ======
# Workers: 2 * número_de_cores + 1 (ajustar según servidor)
WORKERS="9"
# Límite de memoria por worker (en MB)
WORKER_LIMIT_MEMORY="2147483648"  # 2GB
WORKER_LIMIT_MEMORY_HARD="3221225472"  # 3GB
# Límite de tiempo para requests (en segundos)
WORKER_LIMIT_TIME_CPU="600"
WORKER_LIMIT_TIME_REAL="1200"
# Máximo de conexiones cron concurrentes
MAX_CRON_THREADS="2"
# Database pool size
DB_MAXCONN="128"
DB_TEMPLATE="template0"

# ====== LINKS DE WKHTMLTOPDF ======
if [[ $(lsb_release -r -s) == "22.04" ]]; then
    WKHTMLTOX_X64="https://packages.ubuntu.com/jammy/wkhtmltopdf"
else
    WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
fi

##
###  INICIO DE LA INSTALACIÓN
##

echo "=============================================="
echo "  Instalación de Odoo 16 con Ambiente Virtual"
echo "=============================================="
echo ""

#--------------------------------------------------
# Actualizar sistema
#--------------------------------------------------
echo -e "\n==== Actualizando sistema ===="
sudo add-apt-repository universe -y
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Instalar PostgreSQL
#--------------------------------------------------
echo -e "\n==== Instalando PostgreSQL 14 ===="
if [ $INSTALL_POSTGRESQL_FOURTEEN = "True" ]; then
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install postgresql-14 postgresql-client-14 -y
else
    sudo apt-get install postgresql postgresql-server-dev-all -y
fi

# Crear usuario PostgreSQL para Odoo 16
echo -e "\n==== Creando usuario PostgreSQL: $DB_USER ===="
sudo su - postgres -c "psql -c \"CREATE USER $DB_USER WITH CREATEDB PASSWORD '$DB_PASSWORD';\"" 2> /dev/null || true

# Optimizar PostgreSQL para alto volumen
echo -e "\n==== Optimizando PostgreSQL para alto volumen ===="
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+(?=\.)' | head -1)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"

sudo cp $PG_CONF ${PG_CONF}.backup

# Calcular valores según RAM disponible
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
SHARED_BUFFERS=$((TOTAL_RAM * 1024 / 4))  # 25% de RAM
EFFECTIVE_CACHE=$((TOTAL_RAM * 1024 / 2))  # 50% de RAM

sudo tee -a $PG_CONF > /dev/null <<EOF

# ===== Optimización Odoo 16 - Alto Volumen =====
shared_buffers = ${SHARED_BUFFERS}MB
effective_cache_size = ${EFFECTIVE_CACHE}MB
maintenance_work_mem = 512MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
EOF

sudo systemctl restart postgresql

#--------------------------------------------------
# Instalar dependencias del sistema
#--------------------------------------------------
echo -e "\n==== Instalando dependencias del sistema ===="
sudo apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-wheel \
    build-essential \
    wget \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    libzip-dev \
    node-less \
    npm \
    gdebi-core \
    fonts-liberation

#--------------------------------------------------
# Instalar Node.js y herramientas
#--------------------------------------------------
echo -e "\n==== Instalando Node.js y rtlcss ===="
sudo npm install -g rtlcss

#--------------------------------------------------
# Instalar wkhtmltopdf
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\n==== Instalando wkhtmltopdf ===="
    if [[ $(lsb_release -r -s) == "22.04" ]]; then
        sudo apt install wkhtmltopdf -y
    else
        cd /tmp
        sudo wget $WKHTMLTOX_X64
        sudo gdebi --n $(basename $WKHTMLTOX_X64)
        sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf 2>/dev/null || true
        sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage 2>/dev/null || true
    fi
fi

#--------------------------------------------------
# Crear usuario del sistema para Odoo 16
#--------------------------------------------------
echo -e "\n==== Creando usuario del sistema: $OE_USER ===="
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'Odoo 16' --group $OE_USER

#--------------------------------------------------
# Crear estructura de directorios
#--------------------------------------------------
echo -e "\n==== Creando estructura de directorios ===="
sudo mkdir -p $OE_HOME
sudo mkdir -p /var/log/$OE_USER
sudo mkdir -p $OE_HOME/custom/addons
sudo mkdir -p $OE_HOME/data
sudo mkdir -p $OE_HOME/backups

#--------------------------------------------------
# Clonar repositorio de Odoo 16
#--------------------------------------------------
echo -e "\n==== Descargando Odoo 16 ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

#--------------------------------------------------
# Crear ambiente virtual
#--------------------------------------------------
echo -e "\n==== Creando ambiente virtual de Python ===="
sudo -u $OE_USER python3 -m venv $VENV_PATH

# Actualizar pip, setuptools y wheel en el ambiente virtual
sudo -u $OE_USER $VENV_PATH/bin/pip install --upgrade pip setuptools wheel

#--------------------------------------------------
# Instalar dependencias de Python en el venv
#--------------------------------------------------
echo -e "\n==== Instalando dependencias de Python en el ambiente virtual ===="
sudo -u $OE_USER $VENV_PATH/bin/pip install -r $OE_HOME_EXT/requirements.txt

# Instalar paquetes adicionales para mejor rendimiento
sudo -u $OE_USER $VENV_PATH/bin/pip install \
    psycopg2-binary \
    psutil \
    watchdog

#--------------------------------------------------
# Instalar Odoo Enterprise (si aplica)
#--------------------------------------------------
if [ $IS_ENTERPRISE = "True" ]; then
    echo -e "\n==== Instalando Odoo Enterprise ===="
    sudo mkdir -p $OE_HOME/enterprise/addons
    sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons"
    
    sudo -u $OE_USER $VENV_PATH/bin/pip install \
        num2words \
        ofxparse \
        dbfread \
        ebaysdk \
        firebase_admin \
        pyOpenSSL
fi

#--------------------------------------------------
# Configurar permisos
#--------------------------------------------------
echo -e "\n==== Configurando permisos ===="
sudo chown -R $OE_USER:$OE_USER $OE_HOME
sudo chown -R $OE_USER:$OE_USER /var/log/$OE_USER
sudo chmod -R 755 $OE_HOME

#--------------------------------------------------
# Crear archivo de configuración
#--------------------------------------------------
echo -e "\n==== Creando archivo de configuración ===="

ADDONS_PATH="$OE_HOME_EXT/addons,$OE_HOME/custom/addons"
if [ $IS_ENTERPRISE = "True" ]; then
    ADDONS_PATH="$ADDONS_PATH,$OE_HOME/enterprise/addons"
fi

sudo tee /etc/${OE_CONFIG}.conf > /dev/null <<EOF
[options]
; ===== Configuración General =====
admin_passwd = $OE_SUPERADMIN
db_host = False
db_port = False
db_user = $DB_USER
db_password = $DB_PASSWORD
db_maxconn = $DB_MAXCONN
db_template = $DB_TEMPLATE

; ===== Rutas =====
addons_path = $ADDONS_PATH
data_dir = $OE_HOME/data

; ===== Logging =====
logfile = /var/log/$OE_USER/${OE_CONFIG}.log
log_level = info
log_handler = :INFO

; ===== Puertos =====
http_port = $OE_PORT
longpolling_port = $LONGPOLLING_PORT

; ===== Workers (para producción) =====
workers = $WORKERS
max_cron_threads = $MAX_CRON_THREADS

; ===== Límites de memoria =====
limit_memory_soft = $WORKER_LIMIT_MEMORY
limit_memory_hard = $WORKER_LIMIT_MEMORY_HARD

; ===== Límites de tiempo =====
limit_time_cpu = $WORKER_LIMIT_TIME_CPU
limit_time_real = $WORKER_LIMIT_TIME_REAL

; ===== Límites de requests =====
limit_request = 8192

; ===== Proxy mode (si usas Nginx) =====
proxy_mode = False

; ===== Lista de bases de datos =====
; Descomentar y configurar según necesidad
; dbfilter = ^%d$
; list_db = True

; ===== Sin demo data por defecto =====
without_demo = True

; ===== Server wide modules =====
server_wide_modules = base,web
EOF

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Crear servicio systemd moderno
#--------------------------------------------------
echo -e "\n==== Creando servicio systemd ===="

sudo tee /etc/systemd/system/${OE_CONFIG}.service > /dev/null <<EOF
[Unit]
Description=Odoo 16 Server
Documentation=https://www.odoo.com/documentation/16.0/
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$OE_USER
Group=$OE_USER
ExecStart=$VENV_PATH/bin/python3 $OE_HOME_EXT/odoo-bin -c /etc/${OE_CONFIG}.conf
WorkingDirectory=$OE_HOME_EXT
StandardOutput=journal+console

# Seguridad
PrivateTmp=true
NoNewPrivileges=true

# Límites de recursos
LimitNOFILE=65535
LimitNPROC=8192

# Reinicio automático
Restart=on-failure
RestartSec=10s

# Timeout para inicio y parada
TimeoutStartSec=300
TimeoutStopSec=120

# Kill mode
KillMode=mixed
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

#--------------------------------------------------
# Habilitar e iniciar servicio
#--------------------------------------------------
echo -e "\n==== Habilitando e iniciando servicio ===="
sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}.service
sudo systemctl start ${OE_CONFIG}.service

#--------------------------------------------------
# Configurar logrotate
#--------------------------------------------------
echo -e "\n==== Configurando logrotate ===="
sudo tee /etc/logrotate.d/${OE_CONFIG} > /dev/null <<EOF
/var/log/$OE_USER/*.log {
    daily
    rotate 30
    maxage 90
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $OE_USER $OE_USER
    sharedscripts
    postrotate
        systemctl reload ${OE_CONFIG}.service > /dev/null 2>&1 || true
    endscript
}
EOF

#--------------------------------------------------
# Crear script de backup
#--------------------------------------------------
echo -e "\n==== Creando script de backup ===="
sudo tee $OE_HOME/backup.sh > /dev/null <<'EOFBACKUP'
#!/bin/bash
# Script de backup para Odoo 16

BACKUP_DIR="/opt/odoo16/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_USER="odoo16"

# Crear directorio si no existe
mkdir -p $BACKUP_DIR

# Listar todas las bases de datos
DBS=$(su - postgres -c "psql -t -A -c \"SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');\"")

for DB in $DBS; do
    echo "Respaldando base de datos: $DB"
    su - postgres -c "pg_dump -U $DB_USER -F c -b -v -f $BACKUP_DIR/${DB}_${TIMESTAMP}.backup $DB"
done

# Eliminar backups antiguos (más de 7 días)
find $BACKUP_DIR -name "*.backup" -mtime +7 -delete

echo "Backup completado: $(date)"
EOFBACKUP

sudo chmod +x $OE_HOME/backup.sh
sudo chown $OE_USER:$OE_USER $OE_HOME/backup.sh

#--------------------------------------------------
# Instalar Nginx (opcional)
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
    echo -e "\n==== Instalando y configurando Nginx ===="
    sudo apt install nginx -y
    
    sudo tee /etc/nginx/sites-available/${OE_CONFIG} > /dev/null <<EOFNGINX
# Configuración Odoo 16
upstream odoo16 {
    server 127.0.0.1:$OE_PORT;
}

upstream odoo16_longpolling {
    server 127.0.0.1:$LONGPOLLING_PORT;
}

# Redirección HTTP a HTTPS
server {
    listen 80;
    server_name $WEBSITE_NAME;
    
    # Permitir certbot
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/www/html;
    }
    
    # Redireccionar todo lo demás a HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# Configuración HTTPS
server {
    listen 443 ssl http2;
    server_name $WEBSITE_NAME;
    
    # Logs
    access_log /var/log/nginx/${OE_CONFIG}-access.log;
    error_log /var/log/nginx/${OE_CONFIG}-error.log;
    
    # SSL (configurar después con certbot)
    # ssl_certificate /etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$WEBSITE_NAME/privkey.pem;
    
    # Headers de seguridad
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Tamaños y timeouts para archivos grandes
    client_max_body_size 512M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # Buffers optimizados
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    proxy_busy_buffers_size 256k;
    
    # Timeouts largos para operaciones pesadas
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    
    # Headers para proxy
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    
    # Compresión
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;
    
    # Odoo
    location / {
        proxy_pass http://odoo16;
        proxy_redirect off;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }
    
    # Longpolling
    location /longpolling {
        proxy_pass http://odoo16_longpolling;
    }
    
    # Cache estático
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 7d;
        proxy_pass http://odoo16;
        add_header Cache-Control "public, no-transform";
    }
    
    location ~ /[a-zA-Z0-9_-]*/static/ {
        proxy_cache_valid 200 90m;
        proxy_cache_valid 404 1m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo16;
    }
}
EOFNGINX
    
    sudo ln -sf /etc/nginx/sites-available/${OE_CONFIG} /etc/nginx/sites-enabled/${OE_CONFIG}
    sudo nginx -t && sudo systemctl reload nginx
    
    # Actualizar configuración de Odoo para proxy mode
    sudo sed -i 's/proxy_mode = False/proxy_mode = True/' /etc/${OE_CONFIG}.conf
    sudo systemctl restart ${OE_CONFIG}.service
fi

#--------------------------------------------------
# Configurar SSL con Certbot (si aplica)
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ]; then
    if [ $ADMIN_EMAIL != "admin@example.com" ] && [ $WEBSITE_NAME != "odoo16.example.com" ]; then
        echo -e "\n==== Instalando Certbot y configurando SSL ===="
        sudo apt-get update -y
        sudo snap install core
        sudo snap refresh core
        sudo snap install --classic certbot
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
        sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
        sudo systemctl reload nginx
    fi
fi

#--------------------------------------------------
# Crear script de monitoreo
#--------------------------------------------------
echo -e "\n==== Creando script de monitoreo ===="
sudo tee $OE_HOME/monitor.sh > /dev/null <<'EOFMONITOR'
#!/bin/bash
# Script de monitoreo para Odoo 16

SERVICE_NAME="odoo16"

# Verificar si el servicio está corriendo
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "$(date): Servicio $SERVICE_NAME no está corriendo. Reiniciando..."
    systemctl start $SERVICE_NAME
    # Enviar notificación (configurar según necesidad)
    # mail -s "Alerta: $SERVICE_NAME reiniciado" admin@example.com
fi

# Verificar uso de memoria
MEMORY_USAGE=$(ps aux | grep odoo-bin | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
if (( $(echo "$MEMORY_USAGE > 8000" | bc -l) )); then
    echo "$(date): Uso de memoria alto: ${MEMORY_USAGE}MB"
    # Enviar alerta
fi

# Verificar espacio en disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "$(date): Espacio en disco bajo: ${DISK_USAGE}%"
    # Enviar alerta
fi
EOFMONITOR

sudo chmod +x $OE_HOME/monitor.sh
sudo chown $OE_USER:$OE_USER $OE_HOME/monitor.sh

# Agregar a cron (cada 5 minutos)
(sudo crontab -u root -l 2>/dev/null; echo "*/5 * * * * $OE_HOME/monitor.sh >> /var/log/$OE_USER/monitor.log 2>&1") | sudo crontab -u root -

#--------------------------------------------------
# Información final
#--------------------------------------------------
echo ""
echo "=============================================="
echo "  ¡Instalación de Odoo 16 completada!"
echo "=============================================="
echo ""
echo "Detalles de la instalación:"
echo "----------------------------"
echo "Usuario del sistema: $OE_USER"
echo "Directorio home: $OE_HOME"
echo "Ambiente virtual: $VENV_PATH"
echo "Puerto HTTP: $OE_PORT"
echo "Puerto longpolling: $LONGPOLLING_PORT"
echo "Usuario PostgreSQL: $DB_USER"
echo "Password PostgreSQL: $DB_PASSWORD"
echo "Archivo de configuración: /etc/${OE_CONFIG}.conf"
echo "Password admin (master): $OE_SUPERADMIN"
echo "Directorio de logs: /var/log/$OE_USER"
echo "Directorio de datos: $OE_HOME/data"
echo "Directorio de backups: $OE_HOME/backups"
echo "Addons personalizados: $OE_HOME/custom/addons"
echo ""
echo "Comandos útiles:"
echo "----------------"
echo "Iniciar servicio:    sudo systemctl start ${OE_CONFIG}"
echo "Detener servicio:    sudo systemctl stop ${OE_CONFIG}"
echo "Reiniciar servicio:  sudo systemctl restart ${OE_CONFIG}"
echo "Estado del servicio: sudo systemctl status ${OE_CONFIG}"
echo "Ver logs:            sudo journalctl -u ${OE_CONFIG} -f"
echo "Ver logs archivo:    sudo tail -f /var/log/$OE_USER/${OE_CONFIG}.log"
echo ""
echo "Configuración de workers: $WORKERS"
echo "Límite de memoria por worker: $((WORKER_LIMIT_MEMORY / 1024 / 1024))MB"
echo ""
if [ $INSTALL_NGINX = "True" ]; then
    echo "Nginx configurado: /etc/nginx/sites-available/${OE_CONFIG}"
    echo "Acceder vía: http://$WEBSITE_NAME"
else
    echo "Acceder vía: http://tu-servidor:$OE_PORT"
fi
echo ""
echo "IMPORTANTE:"
echo "-----------"
echo "1. Guarda las contraseñas en un lugar seguro"
echo "2. Cambia el password admin en la primera ejecución"
echo "3. Configura el filtro de bases de datos (dbfilter) en producción"
echo "4. Ajusta los workers según los recursos del servidor"
echo "5. Este Odoo 16 puede convivir con Odoo 19 en otro ambiente virtual"
echo "6. Script de backup: $OE_HOME/backup.sh"
echo "7. Script de monitoreo: $OE_HOME/monitor.sh (ejecuta cada 5 min)"
echo ""
echo "=============================================="
