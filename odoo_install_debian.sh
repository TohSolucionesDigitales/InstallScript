#!/bin/bash
################################################################################
# Script for installing Odoo on Debian 12 (Bookworm) - REVISED VERSION
# Adapted from Ubuntu script by Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Debian server. It can install multiple Odoo instances
# in one Debian because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install.sh
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 16.0, 15.0, 14.0 or saas-22. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 17.0
OE_VERSION="18.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Installs postgreSQL V16 instead of defaults (e.g V15 for Debian 12) - this improves performance
INSTALL_POSTGRESQL_SIXTEEN="True"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="False"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Set the website name
WEBSITE_NAME="ekotrapp18.tohsoluciones.com"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="False"
# Provide Email to register ssl certificate
ADMIN_EMAIL="sergio.rivero@tohsoluciones.com"

##
###  WKHTMLTOPDF download links for Debian 12
## For Debian 12 (Bookworm), we'll use the package from the official repositories or GitHub
WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bullseye_amd64.deb"
WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bullseye_i386.deb"

echo "🚀 INICIANDO INSTALACIÓN DE ODOO ${OE_VERSION} EN DEBIAN 12"
echo "============================================================"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Paso 1: Actualizando sistema ----"
sudo apt-get update
sudo apt-get upgrade -y

# Install essential tools FIRST and keep them
echo -e "\n---- Paso 2: Instalando herramientas esenciales ----"
sudo apt-get install -y \
    curl \
    gnupg2 \
    wget \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    unzip \
    software-properties-common

#--------------------------------------------------
# Install and LOCK Git (CRITICAL - must persist)
#--------------------------------------------------
echo -e "\n---- Paso 3: Instalando y asegurando Git ----"

# Remove any conflicting packages first
sudo apt-get autoremove -y

# Install git with dependencies
sudo apt-get install -y git git-man liberror-perl

# Mark git and its dependencies as manually installed (prevents auto-removal)
sudo apt-mark manual git git-man liberror-perl

# Verify git installation
if command -v git &> /dev/null; then
    echo "✅ Git instalado correctamente: $(git --version)"
    # Double-lock git to prevent removal
    echo "git hold" | sudo dpkg --set-selections
else
    echo "❌ CRÍTICO: Git no se pudo instalar"
    exit 1
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Paso 4: Instalando PostgreSQL ----"
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    echo "Instalando PostgreSQL 16..."
    # Add PostgreSQL official APT repository for Debian 12
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install postgresql-16 postgresql-server-dev-16 -y
else
    echo "Instalando PostgreSQL por defecto..."
    sudo apt-get install postgresql postgresql-server-dev-all -y
fi

echo "Creando usuario PostgreSQL para Odoo..."
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Python and dependencies
#--------------------------------------------------
echo -e "\n---- Paso 5: Instalando Python y dependencias ----"
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-wheel \
    python3-setuptools \
    python3-ldap

echo -e "\n---- Paso 6: Instalando dependencias de compilación ----"
sudo apt-get install -y \
    build-essential \
    libxslt1-dev \
    libzip-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libmysqlclient-dev \
    libjpeg-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    tcl8.6-dev \
    tk8.6-dev \
    python3-tk \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    pkg-config

echo "Instalando dependencias adicionales de LDAP..."
sudo apt-get install -y libldap-2.5-0 libldap-common libsasl2-2 libsasl2-modules libsasl2-modules-db

# Install Node.js and npm (Debian 12 compatible)
echo -e "\n---- Paso 7: Instalando Node.js ----"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install nodejs -y
sudo npm install -g less less-plugin-clean-css rtlcss

#--------------------------------------------------
# Install Python packages
#--------------------------------------------------
echo -e "\n---- Paso 8: Instalando paquetes de Python ----"

# Install python3-ldap from system packages FIRST to avoid compilation issues
echo "Instalando python-ldap desde repositorios del sistema..."
sudo apt-get install python3-ldap -y

# Install psycopg2-binary
echo "Instalando psycopg2-binary..."
sudo pip3 install --break-system-packages psycopg2-binary

# Download and modify requirements.txt to exclude python-ldap
echo "Preparando requirements de Odoo (excluyendo python-ldap)..."
cd /tmp
wget -q https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt -O requirements_original.txt

# Remove python-ldap from requirements to avoid compilation
grep -v "python-ldap" requirements_original.txt > requirements_modified.txt

# Install modified requirements
echo "Instalando requirements de Odoo (python-ldap excluido)..."
sudo pip3 install --break-system-packages -r requirements_modified.txt

# Cleanup
rm -f requirements_original.txt requirements_modified.txt

# Verify python-ldap works
echo "Verificando instalación de python-ldap..."
python3 -c "import ldap; print('✓ python-ldap instalado correctamente desde paquetes del sistema')" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️ Advertencia: verificación de python-ldap falló, pero la instalación continuará"
    echo "La autenticación LDAP puede no funcionar correctamente"
fi

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\n---- Paso 9: Instalando wkhtmltopdf ----"
    
    # Try to install from Debian repositories first
    sudo apt-get install wkhtmltopdf -y
    
    # If the above doesn't work, install from GitHub releases
    if ! command -v wkhtmltopdf &> /dev/null; then
        echo "Instalando wkhtmltopdf desde GitHub..."
        #pick up correct one from x64 & x32 versions:
        if [ "`getconf LONG_BIT`" == "64" ];then
            _url=$WKHTMLTOX_X64
        else
            _url=$WKHTMLTOX_X32
        fi
        
        cd /tmp
        sudo wget $_url
        sudo apt-get install -f ./`basename $_url` -y
        
        # Create symbolic links if they don't exist
        if [ ! -L /usr/bin/wkhtmltopdf ]; then
            sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin 2>/dev/null || true
        fi
        if [ ! -L /usr/bin/wkhtmltoimage ]; then
            sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin 2>/dev/null || true
        fi
    fi
else
    echo "wkhtmltopdf no se instalará por elección del usuario"
fi

echo -e "\n---- Paso 10: Creando usuario del sistema Odoo ----"
if ! id "$OE_USER" &>/dev/null; then
    sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
    sudo adduser $OE_USER sudo
else
    echo "Usuario $OE_USER ya existe"
fi

echo "Creando directorio de logs..."
sudo mkdir -p /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO - CRITICAL SECTION
#--------------------------------------------------
echo -e "\n==== Paso 11: Instalando servidor Odoo ===="

# VERIFY GIT IS STILL AVAILABLE
echo "Verificando que Git sigue disponible..."
if ! command -v git &> /dev/null; then
    echo "❌ CRÍTICO: Git desapareció durante la instalación"
    echo "Reinstalando Git urgentemente..."
    sudo apt-get install git -y
    sudo apt-mark manual git
    echo "git hold" | sudo dpkg --set-selections
    
    if ! command -v git &> /dev/null; then
        echo "❌ FATAL: No se puede recuperar Git"
        exit 1
    fi
fi

echo "✅ Git confirmado: $(git --version)"

# Create directories
sudo mkdir -p $OE_HOME_EXT
sudo mkdir -p $OE_HOME/custom/addons

# Remove any existing content in the directory
if [ -d "$OE_HOME_EXT" ] && [ "$(ls -A $OE_HOME_EXT 2>/dev/null)" ]; then
    echo "Limpiando directorio existente $OE_HOME_EXT..."
    sudo rm -rf $OE_HOME_EXT/*
    sudo rm -rf $OE_HOME_EXT/.git* 2>/dev/null || true
fi

echo "Iniciando proceso de clonado de Odoo..."
echo "Directorio destino: $OE_HOME_EXT"
echo "Versión: $OE_VERSION"

# Try multiple methods to get Odoo
clone_success=false

# Method 1: Direct git clone
echo "Método 1: Clone directo con git..."
if sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo.git $OE_HOME_EXT/; then
    echo "✅ Clonado exitoso con git"
    clone_success=true
else
    echo "❌ Clone directo falló"
    
    # Method 2: Clone to temp directory then move
    echo "Método 2: Clone a directorio temporal..."
    sudo rm -rf $OE_HOME_EXT/* 2>/dev/null || true
    cd /tmp
    sudo rm -rf odoo-clone 2>/dev/null || true
    
    if sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo.git odoo-clone; then
        echo "Moviendo archivos desde directorio temporal..."
        sudo mv odoo-clone/* $OE_HOME_EXT/
        sudo mv odoo-clone/.git* $OE_HOME_EXT/ 2>/dev/null || true
        sudo rm -rf odoo-clone
        echo "✅ Clonado exitoso con método temporal"
        clone_success=true
    else
        echo "❌ Clone temporal también falló"
        
        # Method 3: Download ZIP
        echo "Método 3: Descarga ZIP..."
        cd /tmp
        sudo rm -f odoo.zip 2>/dev/null || true
        sudo rm -rf odoo-$OE_VERSION 2>/dev/null || true
        
        if wget -q https://github.com/odoo/odoo/archive/refs/heads/$OE_VERSION.zip -O odoo.zip; then
            if unzip -q odoo.zip; then
                sudo mv odoo-$OE_VERSION/* $OE_HOME_EXT/
                sudo rm -rf odoo-$OE_VERSION odoo.zip
                echo "✅ Descarga ZIP exitosa"
                clone_success=true
            else
                echo "❌ Fallo al descomprimir ZIP"
            fi
        else
            echo "❌ Fallo al descargar ZIP"
        fi
    fi
fi

# Verify clone was successful
if [ "$clone_success" = true ] && [ -f "$OE_HOME_EXT/odoo-bin" ]; then
    echo "✅ Odoo instalado exitosamente: odoo-bin encontrado en $OE_HOME_EXT/odoo-bin"
else
    echo "❌ CRÍTICO: Instalación de Odoo falló completamente"
    echo "Contenido del directorio $OE_HOME_EXT:"
    ls -la $OE_HOME_EXT/ 2>/dev/null || echo "Directorio vacío o inexistente"
    exit 1
fi

# Verify addons directory
if [ ! -d "$OE_HOME_EXT/addons" ]; then
    echo "❌ CRÍTICO: Directorio de addons no encontrado"
    exit 1
else
    addon_count=$(ls -1 "$OE_HOME_EXT/addons" | wc -l)
    echo "✅ Directorio de addons encontrado con $addon_count módulos"
fi

#--------------------------------------------------
# Enterprise installation (if requested)
#--------------------------------------------------
if [ $IS_ENTERPRISE = "True" ]; then
    echo -e "\n---- Instalando versión Enterprise ----"
    sudo su $OE_USER -c "mkdir -p $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir -p $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an official Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo "✅ Código Enterprise agregado bajo $OE_HOME/enterprise/addons"
    echo "Instalando librerías específicas de Enterprise..."
    sudo pip3 install --break-system-packages num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
fi

echo -e "\n---- Paso 12: Configurando permisos ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*
sudo chmod +x $OE_HOME_EXT/odoo-bin

echo -e "\n---- Paso 13: Creando archivo de configuración ----"
sudo touch /etc/${OE_CONFIG}.conf
echo "Creando archivo de configuración del servidor..."

if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo "Generando contraseña aleatoria de admin..."
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

sudo tee /etc/${OE_CONFIG}.conf > /dev/null <<EOF
[options] 
; This is the password that allows database operations:
admin_passwd = ${OE_SUPERADMIN}
http_port = ${OE_PORT}
logfile = /var/log/${OE_USER}/${OE_CONFIG}.log
EOF

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo "Creando script de inicio..."
sudo tee $OE_HOME_EXT/start.sh > /dev/null <<EOF
#!/bin/sh
sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf
EOF
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Create systemd service file
#--------------------------------------------------
echo -e "\n---- Paso 14: Creando servicio systemd ----"
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

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
    echo -e "\n---- Paso 15: Instalando y configurando Nginx ----"
    sudo apt install nginx -y
    
    sudo tee /etc/nginx/sites-available/$WEBSITE_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name $WEBSITE_NAME;

    # Add Headers for odoo proxy mode
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    proxy_set_header X-Client-IP \$remote_addr;
    proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

    # odoo log files
    access_log /var/log/nginx/$OE_USER-access.log;
    error_log /var/log/nginx/$OE_USER-error.log;

    # increase proxy buffer size
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;

    # force timeouts if the backend dies
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

    types {
        text/less less;
        text/scss scss;
    }

    # enable data compression
    gzip on;
    gzip_min_length 1100;
    gzip_buffers 4 32k;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
    gzip_vary on;
    client_header_buffer_size 4k;
    large_client_header_buffers 4 64k;
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:$OE_PORT;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires 2d;
        proxy_pass http://127.0.0.1:$OE_PORT;
        add_header Cache-Control "public, no-transform";
    }

    # cache some static data in memory for 60mins.
    location ~ /[a-zA-Z0-9_-]*/static/ {
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404 1m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://127.0.0.1:$OE_PORT;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl reload nginx
    sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
    echo "✅ Nginx configurado. Archivo: /etc/nginx/sites-available/$WEBSITE_NAME"
else
    echo "Nginx no se instalará por elección del usuario"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ] && [ $WEBSITE_NAME != "_" ]; then
    echo -e "\n---- Instalando certificado SSL con Certbot ----"
    sudo apt-get update -y
    sudo apt-get install snapd -y
    sudo snap install core; sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
    sudo systemctl reload nginx
    echo "✅ SSL/HTTPS habilitado!"
else
    echo "SSL/HTTPS no se habilitará por configuración del usuario"
    if [ "$ADMIN_EMAIL" = "odoo@example.com" ]; then 
        echo "Certbot no soporta registrar odoo@example.com. Debes usar un email real."
    fi
    if [ "$WEBSITE_NAME" = "_" ]; then
        echo "El nombre del sitio web está como '_'. No se puede obtener certificado SSL para '_'."
    fi
fi

echo -e "\n---- Paso 16: Iniciando servicio Odoo ----"
sudo systemctl start ${OE_CONFIG}.service

sleep 5

echo "-----------------------------------------------------------"
echo "🎉 VERIFICACIÓN DE INSTALACIÓN 🎉"
echo "-----------------------------------------------------------"

# Verify critical components
echo "Verificando componentes de la instalación:"

verification_failed=false

echo -n "✓ Git: "
if command -v git &> /dev/null; then
    echo "✅ $(git --version)"
else
    echo "❌ NOT FOUND"
    verification_failed=true
fi

echo -n "✓ PostgreSQL: "
if command -v psql &> /dev/null; then
    echo "✅ $(sudo -u postgres psql --version)"
else
    echo "❌ NOT FOUND"
    verification_failed=true
fi

echo -n "✓ Python: "
if command -v python3 &> /dev/null; then
    echo "✅ $(python3 --version)"
else
    echo "❌ NOT FOUND"
    verification_failed=true
fi

echo -n "✓ Node.js: "
if command -v node &> /dev/null; then
    echo "✅ $(node --version)"
else
    echo "❌ NOT FOUND"
    verification_failed=true
fi

echo -n "✓ Odoo binary: "
if [ -f "$OE_HOME_EXT/odoo-bin" ]; then
    echo "✅ EXISTS at $OE_HOME_EXT/odoo-bin"
else
    echo "❌ NOT FOUND at $OE_HOME_EXT/odoo-bin"
    verification_failed=true
fi

echo -n "✓ Odoo config: "
if [ -f "/etc/${OE_CONFIG}.conf" ]; then
    echo "✅ EXISTS at /etc/${OE_CONFIG}.conf"
else
    echo "❌ NOT FOUND"
    verification_failed=true
fi

echo -n "✓ Odoo service: "
if sudo systemctl is-enabled ${OE_CONFIG}.service &> /dev/null; then
    if sudo systemctl is-active --quiet ${OE_CONFIG}.service; then
        echo "✅ ENABLED and RUNNING"
    else
        echo "⚠️  ENABLED but NOT RUNNING"
        echo "   Logs: sudo journalctl -u ${OE_CONFIG}.service -n 10"
    fi
else
    echo "❌ NOT ENABLED"
    verification_failed=true
fi

echo -n "✓ Odoo addons: "
if [ -d "$OE_HOME_EXT/addons" ]; then
    addon_count=$(ls -1 "$OE_HOME_EXT/addons" | wc -l)
    echo "✅ $addon_count modules found"
else
    echo "❌ ADDONS DIRECTORY NOT FOUND"
    verification_failed=true
fi

echo "-----------------------------------------------------------"
if [ "$verification_failed" = false ]; then
    echo "🎉 ¡INSTALACIÓN COMPLETAMENTE EXITOSA!"
else
    echo "⚠️  INSTALACIÓN COMPLETADA CON ALGUNAS ADVERTENCIAS"
    echo "Revisa los logs para más detalles: sudo journalctl -u ${OE_CONFIG}.service -n 20"
fi

echo ""
echo "📋 RESUMEN DE INSTALACIÓN"
echo "========================"
echo "Puerto: $OE_PORT"
echo "Usuario del servicio: $OE_USER"
echo "Archivo de configuración: /etc/${OE_CONFIG}.conf"
echo "Directorio de logs: /var/log/$OE_USER"
echo "Usuario PostgreSQL: $OE_USER"
echo "Ubicación del código: $OE_HOME_EXT"
echo "Carpeta de addons: $OE_HOME_EXT/addons/"
echo "Carpeta de addons personalizados: $OE_HOME/custom/addons/"
echo "Contraseña superadmin (base de datos): $OE_SUPERADMIN"
echo ""
echo "🚀 COMANDOS DE SERVICIO:"
echo "Iniciar Odoo: sudo systemctl start $OE_CONFIG"
echo "Detener Odoo: sudo systemctl stop $OE_CONFIG"
echo "Reiniciar Odoo: sudo systemctl restart $OE_CONFIG"
echo "Ver estado: sudo systemctl status $OE_CONFIG"
echo "Ver logs en tiempo real: sudo journalctl -u $OE_CONFIG -f"
echo ""
if [ $INSTALL_NGINX = "True" ]; then
    echo "🌐 NGINX:"
    echo "Archivo de configuración: /etc/nginx/sites-available/$WEBSITE_NAME"
    echo "Sitio web: http://$WEBSITE_NAME"
    echo ""
fi
echo "🌐 ACCESO:"
echo "Odoo está disponible en: http://localhost:$OE_PORT"
echo "Gestión de base de datos: http://localhost:$OE_PORT/web/database/manager"
echo "-----------------------------------------------------------"
