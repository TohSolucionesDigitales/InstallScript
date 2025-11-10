# Guía de Instalación Conjunta: Odoo 16 + Odoo 19

## 🎯 Objetivo

Instalar **Odoo 19 como instancia principal** y **Odoo 16 como instancia secundaria** en el mismo servidor, cada una en su propio ambiente virtual, compartiendo PostgreSQL de forma segura y eficiente.

---

## 📊 Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    Ubuntu Server 24.04                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │           PostgreSQL 16 (Compartido)               │   │
│  │  ┌──────────────────┐    ┌──────────────────┐     │   │
│  │  │ Usuario: odoo16  │    │ Usuario: odoo19  │     │   │
│  │  │ (para Odoo 16)   │    │ (para Odoo 19)   │     │   │
│  │  └──────────────────┘    └──────────────────┘     │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────┐     │
│  │   Odoo 16            │    │   Odoo 19            │     │
│  │   (Secundario)       │    │   (Principal)        │     │
│  ├──────────────────────┤    ├──────────────────────┤     │
│  │ Puerto: 8016         │    │ Puerto: 8069         │     │
│  │ Longpolling: 8116    │    │ Longpolling: 8072    │     │
│  │ Workers: 9           │    │ Workers: 13          │     │
│  │ Mem/Worker: 2GB      │    │ Mem/Worker: 2.5GB    │     │
│  │ Venv: /opt/odoo16    │    │ Venv: /opt/odoo19    │     │
│  │ User: odoo16         │    │ User: odoo19         │     │
│  └──────────────────────┘    └──────────────────────┘     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │              Nginx (Opcional)                      │   │
│  │  odoo16.tudominio.com → :8016                      │   │
│  │  odoo.tudominio.com → :8069                        │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Orden de Instalación

### Opción A: Instalar Odoo 16 Primero (Recomendado)
**Ventajas:**
- PostgreSQL ya optimizado cuando instales Odoo 19
- Puedes migrar datos de 16 a 19 más fácilmente
- Menos ajustes manuales

**Pasos:**
1. Ejecutar `odoo16_install_improved.sh`
2. Verificar que funciona correctamente
3. Ejecutar `odoo19_install_improved.sh`
4. Verificar coexistencia

### Opción B: Instalar Odoo 19 Primero
**Cuando usar:**
- Es un servidor nuevo
- Odoo 19 es más crítico para tu negocio

**Pasos:**
1. Ejecutar `odoo19_install_improved.sh`
2. Verificar que funciona correctamente
3. Ejecutar `odoo16_install_improved.sh`
4. Verificar coexistencia

---

## 🚀 Procedimiento de Instalación Detallado

### Paso 0: Preparación del Servidor

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar herramientas básicas
sudo apt install -y git wget curl nano htop

# Verificar recursos del servidor
free -h
nproc
df -h

# Verificar versión de Ubuntu
lsb_release -a
```

**Requisitos mínimos recomendados:**
- **RAM:** 16GB (8GB Odoo 19 + 4GB Odoo 16 + 4GB sistema/PostgreSQL)
- **CPU:** 8 cores
- **Disco:** 100GB SSD (mínimo)
- **OS:** Ubuntu 22.04 o 24.04 LTS

### Paso 1: Instalar Odoo 16

```bash
# Descargar script
wget https://tu-servidor/odoo16_install_improved.sh

# Dar permisos de ejecución
chmod +x odoo16_install_improved.sh

# IMPORTANTE: Editar variables antes de ejecutar
nano odoo16_install_improved.sh
```

**Variables a revisar en Odoo 16:**
```bash
WORKERS="9"                     # Ajustar según cores (CPU*2+1) / 2
WORKER_LIMIT_MEMORY="2147483648"  # 2GB
DB_MAXCONN="128"
INSTALL_NGINX="False"           # Configurar después
WEBSITE_NAME="odoo16.tudominio.com"
```

```bash
# Ejecutar instalación
sudo ./odoo16_install_improved.sh

# Esperar a que termine (puede tomar 10-20 minutos)
```

**Verificar instalación de Odoo 16:**
```bash
# Verificar servicio
sudo systemctl status odoo16

# Verificar puerto
sudo ss -tlnp | grep 8016

# Verificar logs
sudo journalctl -u odoo16 -n 50

# Acceder desde navegador
# http://ip-servidor:8016
```

### Paso 2: Instalar Odoo 19

```bash
# Descargar script
wget https://tu-servidor/odoo19_install_improved.sh

# Dar permisos de ejecución
chmod +x odoo19_install_improved.sh

# IMPORTANTE: Editar variables antes de ejecutar
nano odoo19_install_improved.sh
```

**Variables a revisar en Odoo 19:**
```bash
WORKERS="13"                    # Ajustar según cores (CPU*2+1) / 2
WORKER_LIMIT_MEMORY="2684354560"  # 2.5GB
DB_MAXCONN="192"
INSTALL_NGINX="False"           # Configurar después
WEBSITE_NAME="odoo.tudominio.com"
```

```bash
# Ejecutar instalación
sudo ./odoo19_install_improved.sh

# Esperar a que termine (puede tomar 10-20 minutos)
```

**Verificar instalación de Odoo 19:**
```bash
# Verificar servicio
sudo systemctl status odoo19

# Verificar puerto
sudo ss -tlnp | grep 8069

# Verificar logs
sudo journalctl -u odoo19 -n 50

# Acceder desde navegador
# http://ip-servidor:8069
```

### Paso 3: Verificar Coexistencia

```bash
# Ver todos los servicios Odoo
systemctl status odoo16 odoo19

# Ver todos los puertos
sudo ss -tlnp | grep python3
# Deberías ver: 8016, 8116, 8069, 8072

# Ver todos los procesos
ps aux | grep odoo | grep -v grep

# Ver uso de memoria por instancia
ps aux | grep odoo16 | awk '{sum+=$6} END {print "Odoo 16: " sum/1024 " MB"}'
ps aux | grep odoo19 | awk '{sum+=$6} END {print "Odoo 19: " sum/1024 " MB"}'

# Ver usuarios PostgreSQL
sudo su - postgres -c "psql -c '\du'"
# Deberías ver: odoo16 y odoo19

# Verificar bases de datos
sudo su - postgres -c "psql -l"
```

### Paso 4: Configurar Nginx (Opcional pero Recomendado)

```bash
# Instalar Nginx si no está instalado
sudo apt install -y nginx

# Crear configuración para múltiples instancias
sudo nano /etc/nginx/sites-available/odoo-multi
```

Contenido del archivo:
```nginx
# Odoo 16
upstream odoo16 {
    server 127.0.0.1:8016;
}
upstream odoo16_longpolling {
    server 127.0.0.1:8116;
}

# Odoo 19
upstream odoo19 {
    server 127.0.0.1:8069;
}
upstream odoo19_longpolling {
    server 127.0.0.1:8072;
}

# Configuración para Odoo 16
server {
    listen 80;
    server_name odoo16.tudominio.com;
    
    client_max_body_size 512M;
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    
    # Logs
    access_log /var/log/nginx/odoo16-access.log;
    error_log /var/log/nginx/odoo16-error.log;
    
    # Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Odoo
    location / {
        proxy_pass http://odoo16;
        proxy_redirect off;
    }
    
    location /longpolling {
        proxy_pass http://odoo16_longpolling;
    }
    
    # Cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 7d;
        proxy_pass http://odoo16;
        add_header Cache-Control "public, no-transform";
    }
}

# Configuración para Odoo 19 (Principal)
server {
    listen 80;
    server_name odoo.tudominio.com www.tudominio.com;
    
    client_max_body_size 1024M;
    proxy_read_timeout 1800s;
    proxy_connect_timeout 1800s;
    proxy_send_timeout 1800s;
    
    # Logs
    access_log /var/log/nginx/odoo19-access.log;
    error_log /var/log/nginx/odoo19-error.log;
    
    # Headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Odoo
    location / {
        proxy_pass http://odoo19;
        proxy_redirect off;
    }
    
    location /longpolling {
        proxy_pass http://odoo19_longpolling;
    }
    
    # Cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 7d;
        proxy_pass http://odoo19;
        add_header Cache-Control "public, no-transform";
    }
}
```

```bash
# Habilitar configuración
sudo ln -s /etc/nginx/sites-available/odoo-multi /etc/nginx/sites-enabled/

# Eliminar default
sudo rm /etc/nginx/sites-enabled/default

# Verificar configuración
sudo nginx -t

# Recargar Nginx
sudo systemctl reload nginx

# Actualizar configuración de Odoo para proxy mode
sudo sed -i 's/proxy_mode = False/proxy_mode = True/' /etc/odoo16.conf
sudo sed -i 's/proxy_mode = False/proxy_mode = True/' /etc/odoo19.conf

# Reiniciar servicios Odoo
sudo systemctl restart odoo16
sudo systemctl restart odoo19
```

### Paso 5: Configurar SSL con Certbot

```bash
# Instalar Certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Obtener certificados para ambos dominios
sudo certbot --nginx -d odoo16.tudominio.com
sudo certbot --nginx -d odoo.tudominio.com -d www.tudominio.com

# Verificar renovación automática
sudo certbot renew --dry-run
```

---

## ⚙️ Ajuste de Recursos

### Cálculo de Workers

**Fórmula base:** `workers = (CPU_cores * 2) + 1`

**Distribución recomendada:**
- **Odoo 19 (Principal):** 60% de workers totales
- **Odoo 16 (Secundario):** 40% de workers totales

**Ejemplo con servidor de 8 cores:**
```
Workers totales teóricos: (8 * 2) + 1 = 17
Odoo 19: 17 * 0.6 = 10 workers
Odoo 16: 17 * 0.4 = 7 workers
```

### Ajuste Dinámico según Carga

```bash
# Editar configuración de Odoo 19
sudo nano /etc/odoo19.conf
# Cambiar: workers = 13

# Editar configuración de Odoo 16
sudo nano /etc/odoo16.conf
# Cambiar: workers = 9

# Reiniciar servicios
sudo systemctl restart odoo19
sudo systemctl restart odoo16
```

### Monitoreo de Recursos

```bash
# Ver uso en tiempo real
htop

# Ver memoria por instancia
ps aux | grep odoo16 | awk '{sum+=$6} END {print "Odoo 16: " sum/1024 " MB"}'
ps aux | grep odoo19 | awk '{sum+=$6} END {print "Odoo 19: " sum/1024 " MB"}'

# Ver workers activos
ps aux | grep odoo16 | grep odoo-bin | wc -l
ps aux | grep odoo19 | grep odoo-bin | wc -l

# Crear script de monitoreo conjunto
sudo nano /usr/local/bin/monitor_odoo.sh
```

Contenido:
```bash
#!/bin/bash
echo "=== Monitoreo Odoo 16 + 19 ==="
echo ""
echo "Servicios:"
systemctl is-active odoo16 && echo "✓ Odoo 16" || echo "✗ Odoo 16"
systemctl is-active odoo19 && echo "✓ Odoo 19" || echo "✗ Odoo 19"
echo ""
echo "Workers:"
echo "Odoo 16: $(ps aux | grep odoo16 | grep odoo-bin | wc -l)"
echo "Odoo 19: $(ps aux | grep odoo19 | grep odoo-bin | wc -l)"
echo ""
echo "Memoria:"
ps aux | grep odoo16 | awk '{sum+=$6} END {print "Odoo 16: " sum/1024 " MB"}'
ps aux | grep odoo19 | awk '{sum+=$6} END {print "Odoo 19: " sum/1024 " MB"}'
echo ""
echo "Disco:"
df -h / | awk 'NR==2 {print "Usado: " $5}'
```

```bash
sudo chmod +x /usr/local/bin/monitor_odoo.sh

# Ejecutar
/usr/local/bin/monitor_odoo.sh
```

---

## 🔧 Gestión Diaria

### Scripts de Utilidades

```bash
# Utilidades Odoo 16
sudo chmod +x odoo16_utils.sh
sudo ./odoo16_utils.sh

# Utilidades Odoo 19
sudo chmod +x odoo19_utils.sh
sudo ./odoo19_utils.sh
```

### Comandos Rápidos

```bash
# Ver estado de ambos servicios
systemctl status odoo16 odoo19

# Reiniciar ambos servicios
sudo systemctl restart odoo16 odoo19

# Ver logs en tiempo real
# Terminal 1:
sudo journalctl -u odoo16 -f
# Terminal 2:
sudo journalctl -u odoo19 -f

# Backups automáticos programados
sudo crontab -e
# Agregar:
# 0 3 * * * /opt/odoo16/backup.sh >> /var/log/odoo16/backup.log 2>&1
# 0 2 * * * /opt/odoo19/backup.sh >> /var/log/odoo19/backup.log 2>&1
```

---

## 📊 Comparativa de Configuraciones

| Característica | Odoo 16 (Secundario) | Odoo 19 (Principal) |
|---|---|---|
| **Puerto HTTP** | 8016 | 8069 |
| **Puerto Longpolling** | 8116 | 8072 |
| **Workers** | 9 | 13 |
| **Memoria/Worker Soft** | 2GB | 2.5GB |
| **Memoria/Worker Hard** | 3GB | 3.5GB |
| **DB Connections** | 128 | 192 |
| **Time CPU** | 600s | 720s |
| **Time Real** | 1200s | 1440s |
| **Límite Archivos** | 65535 | 131072 |
| **Límite Procesos** | 8192 | 16384 |
| **PostgreSQL** | 14 | 16 |
| **Usuario Sistema** | odoo16 | odoo19 |
| **Usuario PostgreSQL** | odoo16 | odoo19 |
| **Ambiente Virtual** | /opt/odoo16/venv | /opt/odoo19/venv |
| **Prioridad** | Secundaria | Principal |

---

## 🔐 Seguridad

### Contraseñas

```bash
# Ver contraseñas de Odoo 16
sudo grep -E 'admin_passwd|db_password' /etc/odoo16.conf

# Ver contraseñas de Odoo 19
sudo grep -E 'admin_passwd|db_password' /etc/odoo19.conf

# IMPORTANTE: Guardar en gestor de contraseñas seguro
```

### Firewall

```bash
# Configurar UFW
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8016/tcp  # Odoo 16 (si acceso directo)
sudo ufw allow 8069/tcp  # Odoo 19 (si acceso directo)

# Ver reglas
sudo ufw status verbose
```

### Filtro de Bases de Datos

```bash
# Odoo 16
sudo nano /etc/odoo16.conf
# Agregar: dbfilter = ^legacy_.*$

# Odoo 19
sudo nano /etc/odoo19.conf
# Agregar: dbfilter = ^prod_.*$

# Reiniciar
sudo systemctl restart odoo16 odoo19
```

---

## 🔄 Migración de Odoo 16 a Odoo 19

### Proceso Recomendado

1. **Crear backup en Odoo 16:**
```bash
sudo /opt/odoo16/backup.sh
```

2. **Restaurar en Odoo 19 para testing:**
```bash
# Copiar backup
sudo cp /opt/odoo16/backups/mi_bd_*.backup /opt/odoo19/backups/

# Restaurar en Odoo 19
sudo su - postgres
createdb -U odoo19 -O odoo19 -E UTF8 test_mi_bd
pg_restore -U odoo19 -d test_mi_bd /opt/odoo19/backups/mi_bd_*.backup
```

3. **Actualizar base de datos a Odoo 19:**
```bash
sudo -u odoo19 /opt/odoo19/venv/bin/python3 /opt/odoo19/odoo-server/odoo-bin \
  -c /etc/odoo19.conf -d test_mi_bd -u all --stop-after-init
```

4. **Probar funcionalidad**

5. **Si todo OK, migrar producción**

---

## 🐛 Troubleshooting

### Conflicto de Puertos

```bash
# Ver qué usa cada puerto
sudo lsof -i :8016
sudo lsof -i :8069

# Si hay conflicto, cambiar puertos
sudo nano /etc/odoo16.conf  # Cambiar http_port
sudo systemctl restart odoo16
```

### Alto Uso de Memoria

```bash
# Reducir workers temporalmente
sudo nano /etc/odoo19.conf
# workers = 9
sudo systemctl restart odoo19
```

### PostgreSQL Lento

```bash
# Ver queries lentas
sudo su - postgres
psql
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds';

# Vacuum en bases de datos grandes
vacuumdb -U odoo19 -d nombre_bd -v -z
```

---

## 📚 Checklist Final

- [ ] Ambos servicios iniciados y habilitados
- [ ] Puertos correctos (8016, 8116, 8069, 8072)
- [ ] Nginx configurado (si aplica)
- [ ] SSL configurado (si aplica)
- [ ] Backups automáticos programados
- [ ] Monitoreo funcionando
- [ ] Contraseñas guardadas de forma segura
- [ ] dbfilter configurado en producción
- [ ] Firewall configurado
- [ ] Scripts de utilidades instalados
- [ ] Documentación de la instalación guardada
- [ ] Plan de migración definido (si aplica)

---

## 🎉 ¡Instalación Completa!

Ahora tienes:
- ✅ Odoo 19 como instancia principal en puerto 8069
- ✅ Odoo 16 como instancia secundaria en puerto 8016
- ✅ Ambas en ambientes virtuales separados
- ✅ PostgreSQL 16 compartido de forma segura
- ✅ Configuración optimizada para alto volumen
- ✅ Scripts de gestión y monitoreo
- ✅ Backups automáticos

**Accesos:**
- Odoo 19: `https://odoo.tudominio.com` o `http://ip-servidor:8069`
- Odoo 16: `https://odoo16.tudominio.com` o `http://ip-servidor:8016`

**¡Disfruta de tu instalación dual de Odoo!** 🚀
