# Mejoras Implementadas en el Script de Instalación Odoo 16

## 📋 Resumen de Cambios Principales

### 1. Ambiente Virtual de Python
**Antes:** Instalación global de paquetes Python
**Ahora:** Ambiente virtual aislado en `/opt/odoo16/venv`

**Ventajas:**
- ✅ Aislamiento completo entre Odoo 16 y Odoo 19
- ✅ Gestión independiente de dependencias
- ✅ Sin conflictos de versiones de paquetes
- ✅ Facilita actualizaciones y rollbacks
- ✅ Mejor seguridad y estabilidad

### 2. Servicio Systemd Moderno
**Antes:** Script init.d antiguo (System V)
**Ahora:** Unidad systemd nativa

**Mejoras:**
- ✅ Reinicio automático en caso de fallos
- ✅ Mejor gestión de recursos (límites de archivos abiertos, procesos)
- ✅ Logs integrados con journald
- ✅ Control de timeouts (inicio/parada)
- ✅ Seguridad mejorada (PrivateTmp, NoNewPrivileges)
- ✅ Gestión de dependencias (PostgreSQL)

### 3. Optimización para Alto Volumen

#### a) Configuración de PostgreSQL
```ini
shared_buffers = 25% de RAM
effective_cache_size = 50% de RAM
maintenance_work_mem = 512MB
max_connections ajustado dinámicamente
```

#### b) Configuración de Odoo
```ini
workers = 9 (ajustable según cores)
limit_memory_soft = 2GB
limit_memory_hard = 3GB
limit_time_cpu = 600s
limit_time_real = 1200s
db_maxconn = 128
```

### 4. Compatibilidad con Odoo 19
**Configuración para coexistencia:**
- Usuario del sistema: `odoo16` (diferente de `odoo19`)
- Puerto HTTP: `8016` (Odoo 19 usará `8069`)
- Puerto longpolling: `8116` (Odoo 19 usará `8072`)
- Usuario PostgreSQL: `odoo16` (aislado de `odoo19`)
- Directorio home: `/opt/odoo16` (separado de `/opt/odoo19`)

---

## 🔧 Configuración Recomendada según Hardware

### Servidor Pequeño (4 cores, 8GB RAM)
```bash
WORKERS="5"
WORKER_LIMIT_MEMORY="1610612736"  # 1.5GB
DB_MAXCONN="64"
```

### Servidor Medio (8 cores, 16GB RAM)
```bash
WORKERS="9"  # (Valor por defecto en el script)
WORKER_LIMIT_MEMORY="2147483648"  # 2GB
DB_MAXCONN="128"
```

### Servidor Grande (16+ cores, 32GB+ RAM)
```bash
WORKERS="17"
WORKER_LIMIT_MEMORY="3221225472"  # 3GB
DB_MAXCONN="256"
```

**Fórmula para calcular workers:**
```
workers = (número_de_cores * 2) + 1
```

---

## 📦 Estructura de Directorios

```
/opt/odoo16/
├── venv/                    # Ambiente virtual Python
├── odoo-server/             # Código fuente Odoo 16
├── custom/addons/           # Módulos personalizados
├── enterprise/addons/       # Módulos enterprise (si aplica)
├── data/                    # Datos de sesión y filestore
├── backups/                 # Backups automáticos
├── backup.sh               # Script de respaldo
└── monitor.sh              # Script de monitoreo

/etc/odoo16.conf             # Configuración principal
/var/log/odoo16/             # Logs
/etc/systemd/system/odoo16.service  # Servicio systemd
```

---

## 🔒 Seguridad Mejorada

### 1. Contraseñas Generadas Automáticamente
- Master password de 24 caracteres aleatorios
- Password PostgreSQL de 20 caracteres aleatorios
- Guardadas en variables al final de la instalación

### 2. Permisos del Archivo de Configuración
```bash
Owner: odoo16:odoo16
Permisos: 640 (solo lectura para grupo, sin acceso para otros)
```

### 3. Systemd Security Features
```ini
PrivateTmp=true          # Directorio /tmp privado
NoNewPrivileges=true     # Sin escalada de privilegios
```

---

## 📊 Monitoreo y Mantenimiento

### Scripts Incluidos

#### 1. backup.sh
**Funcionalidad:**
- Backup automático de todas las bases de datos
- Formato comprimido para ahorrar espacio
- Retención de 7 días
- Se puede programar con cron

**Uso:**
```bash
# Manual
sudo -u odoo16 /opt/odoo16/backup.sh

# Automatizado (agregar a cron)
0 2 * * * /opt/odoo16/backup.sh
```

#### 2. monitor.sh
**Funcionalidad:**
- Verifica que el servicio esté corriendo
- Monitorea uso de memoria
- Monitorea espacio en disco
- Reinicio automático si es necesario
- Ya programado en cron (cada 5 minutos)

**Ver logs de monitoreo:**
```bash
sudo tail -f /var/log/odoo16/monitor.log
```

---

## 🌐 Configuración Nginx (Opcional)

### Características Incluidas
- ✅ Redirección automática HTTP → HTTPS
- ✅ Compresión gzip optimizada
- ✅ Cache de archivos estáticos
- ✅ Headers de seguridad
- ✅ Soporte para archivos grandes (512MB)
- ✅ Timeouts extendidos para operaciones pesadas
- ✅ Configuración lista para SSL/Certbot

### Activar Nginx en el Script
```bash
INSTALL_NGINX="True"
WEBSITE_NAME="odoo16.tudominio.com"
ENABLE_SSL="True"
ADMIN_EMAIL="admin@tudominio.com"
```

---

## 🚀 Comandos Útiles

### Gestión del Servicio
```bash
# Iniciar
sudo systemctl start odoo16

# Detener
sudo systemctl stop odoo16

# Reiniciar
sudo systemctl restart odoo16

# Estado
sudo systemctl status odoo16

# Habilitar inicio automático
sudo systemctl enable odoo16

# Deshabilitar inicio automático
sudo systemctl disable odoo16
```

### Ver Logs
```bash
# Logs en tiempo real (systemd)
sudo journalctl -u odoo16 -f

# Logs en tiempo real (archivo)
sudo tail -f /var/log/odoo16/odoo16.log

# Ver últimas 100 líneas
sudo journalctl -u odoo16 -n 100

# Logs de un período específico
sudo journalctl -u odoo16 --since "2024-01-01" --until "2024-01-31"
```

### Gestión del Ambiente Virtual
```bash
# Activar ambiente virtual
sudo su - odoo16
source /opt/odoo16/venv/bin/activate

# Instalar paquete adicional
/opt/odoo16/venv/bin/pip install nombre-paquete

# Listar paquetes instalados
/opt/odoo16/venv/bin/pip list

# Actualizar paquete
/opt/odoo16/venv/bin/pip install --upgrade nombre-paquete
```

### PostgreSQL
```bash
# Conectar a PostgreSQL como usuario odoo16
sudo su - postgres
psql -U odoo16 -d nombre_base_datos

# Listar bases de datos
psql -U odoo16 -l

# Crear backup manual
pg_dump -U odoo16 -F c -b -v -f /tmp/backup.dump nombre_bd
```

---

## ⚙️ Ajustes Post-Instalación

### 1. Configurar Filtro de Bases de Datos
Editar `/etc/odoo16.conf`:
```ini
# Permitir solo BDs que empiecen con "cliente_"
dbfilter = ^cliente_.*$

# O usar el nombre del dominio
dbfilter = ^%d$
```

### 2. Optimizar Workers según Carga Real
```bash
# Monitorear uso de recursos
htop

# Ajustar workers en /etc/odoo16.conf
workers = X

# Reiniciar servicio
sudo systemctl restart odoo16
```

### 3. Configurar Logrotate
Ya incluido en el script. Verifica con:
```bash
cat /etc/logrotate.d/odoo16
```

### 4. Firewall (si aplica)
```bash
# UFW
sudo ufw allow 8016/tcp
sudo ufw allow 8116/tcp

# Firewalld
sudo firewall-cmd --permanent --add-port=8016/tcp
sudo firewall-cmd --permanent --add-port=8116/tcp
sudo firewall-cmd --reload
```

---

## 🔄 Instalación de Odoo 19 en Paralelo

### Script para Odoo 19
Crear un script similar con estos cambios:

```bash
OE_USER="odoo19"
OE_HOME="/opt/odoo19"
OE_VERSION="19.0"
OE_PORT="8069"
LONGPOLLING_PORT="8072"
DB_USER="odoo19"
```

### Verificación de Coexistencia
```bash
# Ver ambos servicios
systemctl status odoo16
systemctl status odoo19

# Ver puertos en uso
sudo netstat -tlnp | grep python3

# Ver procesos
ps aux | grep odoo
```

---

## 📝 Checklist Pre-Producción

- [ ] Cambiar password admin (master password)
- [ ] Configurar dbfilter apropiado
- [ ] Ajustar workers según hardware real
- [ ] Configurar backups automáticos con cron
- [ ] Probar recuperación desde backup
- [ ] Configurar Nginx + SSL si es producción
- [ ] Configurar firewall
- [ ] Monitorear logs por 24-48 horas
- [ ] Documentar contraseñas en gestor seguro
- [ ] Configurar alertas de monitoreo
- [ ] Probar reinicio del servidor
- [ ] Verificar inicio automático del servicio

---

## 🐛 Troubleshooting

### Servicio no inicia
```bash
# Ver logs detallados
sudo journalctl -u odoo16 -xe

# Verificar configuración
sudo -u odoo16 /opt/odoo16/venv/bin/python3 /opt/odoo16/odoo-server/odoo-bin \
  -c /etc/odoo16.conf --test-enable --log-level=debug

# Verificar permisos
ls -la /opt/odoo16
ls -la /var/log/odoo16
```

### Error de memoria
```bash
# Reducir workers
# Editar /etc/odoo16.conf
workers = 4
limit_memory_soft = 1073741824  # 1GB

# Reiniciar
sudo systemctl restart odoo16
```

### Base de datos no conecta
```bash
# Verificar PostgreSQL
sudo systemctl status postgresql

# Probar conexión
psql -U odoo16 -h localhost -d postgres

# Ver configuración
grep db_ /etc/odoo16.conf
```

### Puerto en uso
```bash
# Ver qué está usando el puerto
sudo lsof -i :8016

# Cambiar puerto en configuración
# Editar /etc/odoo16.conf
http_port = 8017
```

---

## 📚 Referencias

- [Documentación Oficial Odoo 16](https://www.odoo.com/documentation/16.0/)
- [Guía de Deploy Odoo](https://www.odoo.com/documentation/16.0/administration/install/deploy.html)
- [PostgreSQL Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [Systemd Service Manual](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

---

## ✅ Ventajas del Nuevo Script

1. **Aislamiento Total**: Cada versión de Odoo en su propio ambiente
2. **Modernización**: Systemd en lugar de init.d obsoleto
3. **Optimización**: Configuración para alto volumen desde el inicio
4. **Mantenibilidad**: Scripts de backup y monitoreo incluidos
5. **Seguridad**: Contraseñas fuertes, permisos correctos, features de systemd
6. **Escalabilidad**: Fácil ajuste de workers y recursos
7. **Producción Ready**: Nginx, SSL, logrotate, todo incluido
8. **Coexistencia**: Diseñado para convivir con Odoo 19

---

**Nota Final:** Este script está optimizado para servidores de producción con grandes volúmenes de datos. Ajusta los parámetros según tus necesidades específicas y recursos disponibles.
