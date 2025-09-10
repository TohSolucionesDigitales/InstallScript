#!/bin/bash
################################################################################
# Script for installing Odoo on Debian 12 (Bookworm)
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

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

# Install curl and gnupg for repository management
sudo apt-get install curl gnupg2 wget lsb-release ca-certificates apt-transport-https -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "=== Install and configure PostgreSQL ... ==="
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    echo -e "=== Installing postgreSQL V16 due to the user's choice ... ==="
    # Add PostgreSQL official APT repository for Debian 12
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install postgresql-16 postgresql-server-dev-16 -y
else
    echo -e "=== Installing the default postgreSQL version based on Debian version ... ==="
    sudo apt-get install postgresql postgresql-server-dev-all -y
fi

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 ---"
sudo apt-get install python3 python3-pip python3-dev python3-venv python3-wheel python3-setuptools -y

echo -e "\n--- Installing build dependencies ---"
sudo apt-get install git build-essential wget curl libxslt1-dev libzip-dev libldap2-dev libsasl2-dev \
    libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpng-dev libjpeg62-turbo-dev \
    zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
    libharfbuzz-dev libfribidi-dev libxcb1-dev pkg-config -y

# Install Node.js and npm (Debian 12 compatible)
echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install nodejs -y
sudo npm install -g less less-plugin-clean-css rtlcss

echo -e "\n---- Install python packages/requirements ----"

# Install python3-ldap from system packages FIRST to avoid compilation issues
echo "Installing python-ldap from system packages to avoid compilation errors..."
sudo apt-get install python3-ldap -y

# Additional packages that might be needed
echo "Installing additional Python packages..."
sudo pip3 install --break-system-packages psycopg2-binary

# Download and modify requirements.txt to exclude python-ldap
echo "Preparing Odoo requirements (excluding python-ldap)..."
cd /tmp
wget -q https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt -O requirements_original.txt

# Remove python-ldap from requirements to avoid compilation
grep -v "python-ldap" requirements_original.txt > requirements_modified.txt

# Install modified requirements
echo "Installing Odoo requirements (python-ldap excluded)..."
sudo pip3 install --break-system-packages -r requirements_modified.txt

# Cleanup
rm -f requirements_original.txt requirements_modified.txt

# Verify python-ldap works
echo "Verifying python-ldap installation..."
python3 -c "import ldap; print('✓ python-ldap installed successfully from system packages')" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️ Warning: python-ldap verification failed, but installation will continue"
    echo "LDAP authentication may not work properly"
fi

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
    echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO ----"
    
    # Try to install from Debian repositories first
    sudo apt-get install wkhtmltopdf -y
    
    # If the above doesn't work, install from GitHub releases
    if ! command -v wkhtmltopdf &> /dev/null; then
        echo -e "---- Installing wkhtmltopdf from GitHub releases ----"
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
    echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Installing Enterprise version"
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

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo pip3 install --break-system-packages num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
fi

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir -p $OE_HOME/custom"
sudo su $OE_USER -c "mkdir -p $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"

if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Create systemd service file (recommended for Debian 12)
#--------------------------------------------------
echo -e "* Create systemd service file"
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

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Enable and start Odoo service"
sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}.service

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
    echo -e "\n---- Installing and setting up Nginx ----"
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
    echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$WEBSITE_NAME"
else
    echo "Nginx isn't installed due to choice of the user!"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ] && [ $WEBSITE_NAME != "_" ]; then
    echo -e "\n---- Installing SSL certificate with Certbot ----"
    sudo apt-get update -y
    sudo apt-get install snapd -y
    sudo snap install core; sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
    sudo systemctl reload nginx
    echo "SSL/HTTPS is enabled!"
else
    echo "SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration!"
    if [ "$ADMIN_EMAIL" = "odoo@example.com" ]; then 
        echo "Certbot does not support registering odoo@example.com. You should use real e-mail address."
    fi
    if [ "$WEBSITE_NAME" = "_" ]; then
        echo "Website name is set as _. Cannot obtain SSL Certificate for _. You should use real website address."
    fi
fi

echo -e "* Starting Odoo Service"
sudo systemctl start ${OE_CONFIG}.service

echo "-----------------------------------------------------------"
echo "🎉 INSTALLATION VERIFICATION 🎉"
echo "-----------------------------------------------------------"

# Verify critical components
echo "Verifying installation components:"

echo -n "✓ Git: "
if command -v git &> /dev/null; then
    echo "$(git --version)"
else
    echo "❌ NOT FOUND"
fi

echo -n "✓ PostgreSQL: "
if command -v psql &> /dev/null; then
    echo "$(sudo -u postgres psql --version)"
else
    echo "❌ NOT FOUND"
fi

echo -n "✓ Python: "
if command -v python3 &> /dev/null; then
    echo "$(python3 --version)"
else
    echo "❌ NOT FOUND"
fi

echo -n "✓ Node.js: "
if command -v node &> /dev/null; then
    echo "$(node --version)"
else
    echo "❌ NOT FOUND"
fi

echo -n "✓ Odoo binary: "
if [ -f "$OE_HOME_EXT/odoo-bin" ]; then
    echo "EXISTS at $OE_HOME_EXT/odoo-bin"
else
    echo "❌ NOT FOUND at $OE_HOME_EXT/odoo-bin"
fi

echo -n "✓ Odoo config: "
if [ -f "/etc/${OE_CONFIG}.conf" ]; then
    echo "EXISTS at /etc/${OE_CONFIG}.conf"
else
    echo "❌ NOT FOUND"
fi

echo -n "✓ Odoo service: "
if sudo systemctl is-enabled ${OE_CONFIG}.service &> /dev/null; then
    if sudo systemctl is-active --quiet ${OE_CONFIG}.service; then
        echo "ENABLED and RUNNING"
    else
        echo "ENABLED but NOT RUNNING"
    fi
else
    echo "❌ NOT ENABLED"
fi

echo -n "✓ Odoo addons: "
if [ -d "$OE_HOME_EXT/addons" ]; then
    addon_count=$(ls -1 "$OE_HOME_EXT/addons" | wc -l)
    echo "$addon_count modules found"
else
    echo "❌ ADDONS DIRECTORY NOT FOUND"
fi

echo "-----------------------------------------------------------"
echo "📋 INSTALLATION SUMMARY 📋"
echo "-----------------------------------------------------------"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "Configuration file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_HOME_EXT"
echo "Addons folder: $OE_HOME_EXT/addons/"
echo "Custom addons folder: $OE_HOME/custom/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo ""
echo "🚀 SERVICE COMMANDS:"
echo "Start Odoo service: sudo systemctl start $OE_CONFIG"
echo "Stop Odoo service: sudo systemctl stop $OE_CONFIG"
echo "Restart Odoo service: sudo systemctl restart $OE_CONFIG"
echo "View Odoo service status: sudo systemctl status $OE_CONFIG"
echo "View Odoo logs: sudo journalctl -u $OE_CONFIG -f"
echo ""
if [ $INSTALL_NGINX = "True" ]; then
    echo "🌐 NGINX:"
    echo "Nginx configuration file: /etc/nginx/sites-available/$WEBSITE_NAME"
    echo "Website: http://$WEBSITE_NAME"
fi
echo ""
echo "🌐 ACCESS:"
echo "Odoo is accessible at: http://localhost:$OE_PORT"
echo "Database management: http://localhost:$OE_PORT/web/database/manager"
echo "-----------------------------------------------------------"
