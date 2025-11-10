# Mejoras Implementadas en el Script de Instalación Odoo 19

## 📋 Resumen de Cambios Principales

### 1. Odoo 19 como Instancia Principal
**Configuración optimizada para ser la versión principal del servidor:**
- Puerto estándar: 8069 (puerto tradicional de Odoo)
- Más workers: 13 por defecto (vs 9 en Odoo 16)
- Más memoria: 2.5GB soft / 3.5GB hard por worker
- Más conexiones DB: 192 (vs 128 en Odoo 16)
- Timeouts más largos: 720s CPU / 1440s real

### 2. Ambiente Virtual de Python
**Antes:** Instalación global de paquetes Python
**Ahora:** Ambiente virtual aislado en `/opt/odoo19/venv`

**Ventajas:**
- ✅ Aislamiento completo entre Odoo 19 y Odoo 16
- ✅ Gestión independiente de dependencias
- ✅ Sin conflictos de versiones de paquetes
- ✅ Python 3 nativo de Ubuntu (compatible con Odoo 19)
- ✅ Facilita actualizaciones y rollbacks
- ✅ Mejor seguridad y estabilidad

### 3. PostgreSQL 16 (Última Versión LTS)
**Mejoras sobre PostgreSQL 14:**
- ✅ Mejor rendimiento en consultas paralelas
- ✅ Soporte para pgvector (funciones de IA en Enterprise)
- ✅ Optimizaciones de índices mejoradas
- ✅ Mejor gestión de vacuum
- ✅ Compatible con Ubuntu 24.04

### 4. Servicio Systemd Moderno
**Antes:** Script init.d antiguo (System V)
**Ahora:** Unidad systemd nativa con características avanzadas

**Mejoras:**
- ✅ Reinicio automático en caso de fallos
- ✅ Mejor gestión de recursos (131k archivos, 16k procesos)
- ✅ Logs integrados con journald
- ✅ Control de timeouts (inicio/parada)
- ✅ Seguridad mejorada (PrivateTmp, NoNewPrivileges)
- ✅ Gestión de dependencias (PostgreSQL)

### 5. Optimización para Alto Volumen

#### a) Configuración de PostgreSQL 16
```ini
shared_buffers = 25% de RAM
effective_cache_size = 50% de RAM
maintenance_work_mem = 512MB
work_mem = 20MB (vs 16MB en Odoo 16)
min_wal_size = 2GB (vs 1GB)
max_wal_size = 8GB (vs 4GB)
max_connections ajustado dinámicamente
```

#### b) Configuración de Odoo 19 (Principal)
```ini
workers = 13 (más que Odoo 16)
limit_memory_soft = 2.5GB (vs 2GB en Odoo 16)
limit_memory_hard = 3.5GB (vs 3GB en Odoo 16)
limit_time_cpu = 720s (vs 600s)
limit_time_real = 1440s (vs 1200s)
db_maxconn = 192 (vs 128 en Odoo 16)
```

### 6. Compatibilidad con Odoo 16
**Configuración para coexistencia perfecta:**
- Usuario del sistema: `odoo19` (diferente de `odoo16`)
- Puerto HTTP: `8069` (principal - vs `8016` de Odoo 16)
- Puerto longpolling: `8072` (principal - vs `8116` de Odoo 16)
- Usuario PostgreSQL: `odoo19` (aislado de `odoo16`)
- Directorio home: `/opt/odoo19` (separado de `/opt/odoo16`)
- Ambiente virtual separado: `/opt/odoo19/venv`

### 7. Características Específicas de Odoo 19
- ✅ Soporte para phonenumbers (incluido por defecto)
- ✅ Compatible con Ubuntu 24.04 LTS
- ✅ Preparado para pgvector (IA en Enterprise)
- ✅ Configuración optimizada para las nuevas funciones de Odoo 19

---

## 🔧 Configuración Recomendada según Hardware

### Servidor Pequeño (4 cores, 8GB RAM)
```bash
WORKERS="5"
WORKER_LIMIT_MEMORY="2147483648"  # 2GB
DB_MAXCONN="96"
```

### Servidor Medio (8 cores, 16GB RAM)
```bash
WORKERS="13"  # (Valor por defecto en el script)
WORKER_LIMIT_MEMORY="2684354560"  # 2.5GB
DB_MAXCONN="192"
```

### Servidor Grande (16+ cores, 32GB+ RAM)
```bash
WORKERS="25"
WORKER_LIMIT_MEMORY="3221225472"  # 3GB
DB_MAXCONN="384"
```

### Servidor Muy Grande (32+ cores, 64GB+ RAM)
```bash
WORKERS="49"
WORKER_LIMIT_MEMORY="4294967296"  # 4GB
DB_MAXCONN="512"
```

**Fórmula para calcular workers:**
```
workers = (número_de_cores * 2) + 1
```

**Nota:** Odoo 19 como instancia principal debe tener más recursos que Odoo 16.

---

## 📦 Estructura de Directorios

```
/opt/odoo19/
├── venv/                    # Ambiente virtual Python
├── odoo-server/             # Código fuente Odoo 19
├── custom/addons/           # Módulos personalizados
├── enterprise/addons/       # Módulos enterprise (si aplica)
├── data/                    # Datos de sesión y filestore
├── backups/                 # Backups automáticos
├── backup.sh               # Script de respaldo
├── monitor.sh              # Script de monitoreo
└── update.sh               # Script de actualización

/etc/odoo19.conf             # Configuración principal
/var/log/odoo19/             # Logs
/etc/systemd/system/odoo19.service  # Servicio systemd
```

---

## 🔒 Seguridad Mejorada

### 1. Contraseñas Generadas Automáticamente
- Master password de 24 caracteres aleatorios
- Password PostgreSQL de 20 caracteres aleatorios
- Guardadas en variables al final de la instalación

### 2. Permisos del Archivo de Configuración
```bash
Owner: odoo19:odoo19
Permisos: 640 (solo lectura para grupo, sin acceso para otros)
```

### 3. Systemd Security Features
```ini
PrivateTmp=true          # Directorio /tmp privado
NoNewPrivileges=true     # Sin escalada de privilegios
LimitNOFILE=131072       # Más archivos abiertos (vs 65535 en Odoo 16)
LimitNPROC=16384         # Más procesos (vs 8192 en Odoo 16)
```

---

## 📊 Monitoreo y Mantenimiento

### Scripts Incluidos

#### 1. backup.sh
**Funcionalidad:**
- Backup automático de todas las bases de datos de Odoo 19
- Formato comprimido para ahorrar espacio
- Retención de 7 días
- Filtra solo las BDs del usuario odoo19

**Uso:**
```bash
# Manual
sudo -u odoo19 /opt/odoo19/backup.sh

# Automatizado (agregar a cron)
0 3 * * * /opt/odoo19/backup.sh
```

#### 2. monitor.sh
**Funcionalidad:**
- Verifica que el servicio esté corriendo
- Monitorea uso de memoria (alerta si > 10GB)
- Monitorea espacio en disco
- Cuenta workers activos
- Reinicio automático si es necesario
- Ya programado en cron (cada 5 minutos)

**Ver logs de monitoreo:**
```bash
sudo tail -f /var/log/odoo19/monitor.log
```

#### 3. update.sh (NUEVO)
**Funcionalidad:**
- Actualiza Odoo 19 a la última versión de la rama 19.0
- Crea backup del código antes de actualizar
- Actualiza dependencias Python
- Reinicia el servicio automáticamente

**Uso:**
```bash
# Ejecutar como root
sudo /opt/odoo19/update.sh
```

---

## 🌐 Configuración Nginx (Opcional)

### Características Incluidas (Optimizadas para Principal)
- ✅ Redirección automática HTTP → HTTPS
- ✅ Compresión gzip optimizada
- ✅ Cache de archivos estáticos
- ✅ Headers de seguridad
- ✅ Soporte para archivos MUY grandes (1GB vs 512MB en Odoo 16)
- ✅ Timeouts MUY extendidos (30 min vs 12 min en Odoo 16)
- ✅ Buffers más grandes (32x128k vs 16x64k)
- ✅ Configuración lista para SSL/Certbot

### Activar Nginx en el Script
```bash
INSTALL_NGINX="True"
WEBSITE_NAME="odoo.tudominio.com"
ENABLE_SSL="True"
ADMIN_EMAIL="admin@tudominio.com"
```

---

## 🚀 Comandos Útiles

### Gestión del Servicio
```bash
# Iniciar
sudo systemctl start odoo19

# Detener
sudo systemctl stop odoo19

# Reiniciar
sudo systemctl restart odoo19

# Estado
sudo systemctl status odoo19

# Habilitar inicio automático
sudo systemctl enable odoo19

# Deshabilitar inicio automático
sudo systemctl disable odoo19
```

### Ver Logs
```bash
# Logs en tiempo real (systemd)
sudo journalctl -u odoo19 -f

# Logs en tiempo real (archivo)
sudo tail -f /var/log/odoo19/odoo19.log

# Ver últimas 200 líneas
sudo journalctl -u odoo19 -n 200

# Logs de un período específico
sudo journalctl -u odoo19 --since "2024-01-01" --until "2024-01-31"

# Ver solo errores
sudo journalctl -u odoo19 -p err -f
```

### Gestión del Ambiente Virtual
```bash
# Activar ambiente virtual
sudo su - odoo19
source /opt/odoo19/venv/bin/activate

# Instalar paquete adicional
/opt/odoo19/venv/bin/pip install nombre-paquete

# Listar paquetes instalados
/opt/odoo19/venv/bin/pip list

# Actualizar paquete
/opt/odoo19/venv/bin/pip install --upgrade nombre-paquete

# Ver versión de Odoo
/opt/odoo19/venv/bin/python3 /opt/odoo19/odoo-server/odoo-bin --version
```

### PostgreSQL
```bash
# Conectar a PostgreSQL como usuario odoo19
sudo su - postgres
psql -U odoo19 -d nombre_base_datos

# Listar bases de datos de odoo19
psql -U odoo19 -l

# Crear backup manual
pg_dump -U odoo19 -F c -b -v -f /tmp/backup.dump nombre_bd

# Restaurar backup
createdb -U odoo19 -O odoo19 nueva_bd
pg_restore -U odoo19 -d nueva_bd /tmp/backup.dump
```

---

## ⚙️ Ajustes Post-Instalación

### 1. Configurar Filtro de Bases de Datos
Editar `/etc/odoo19.conf`:
```ini
# Permitir solo BDs que empiecen con "prod_"
dbfilter = ^prod_.*$

# O usar el nombre del dominio
dbfilter = ^%d$

# Para múltiples dominios
dbfilter = ^(prod_.*|test_.*)$
```

### 2. Optimizar Workers según Carga Real
```bash
# Monitorear uso de recursos
htop
# o
top -u odoo19

# Ver workers activos
ps aux | grep odoo19 | grep odoo-bin

# Ajustar workers en /etc/odoo19.conf
workers = X

# Reiniciar servicio
sudo systemctl restart odoo19
```

### 3. Configurar Logrotate
Ya incluido en el script. Verifica con:
```bash
cat /etc/logrotate.d/odoo19
```

### 4. Firewall (si aplica)
```bash
# UFW
sudo ufw allow 8069/tcp
sudo ufw allow 8072/tcp

# Firewalld
sudo firewall-cmd --permanent --add-port=8069/tcp
sudo firewall-cmd --permanent --add-port=8072/tcp
sudo firewall-cmd --reload
```

### 5. Configurar Backups Automáticos
```bash
# Editar crontab
sudo crontab -e

# Agregar línea para backup diario a las 3 AM
0 3 * * * /opt/odoo19/backup.sh >> /var/log/odoo19/backup.log 2>&1

# Backup semanal completo (domingos a las 2 AM)
0 2 * * 0 /opt/odoo19/backup.sh && rsync -av /opt/odoo19/backups/ /mnt/backup-remoto/
```

---

## 🔄 Convivencia con Odoo 16

### Arquitectura del Sistema
```
Sistema Ubuntu 24.04
├── PostgreSQL 16 (compartido)
│   ├── Usuario: odoo16 (para Odoo 16)
│   └── Usuario: odoo19 (para Odoo 19)
├── Odoo 16 (Secundario)
│   ├── Puerto: 8016
│   ├── Longpolling: 8116
│   ├── Workers: 9
│   └── Venv: /opt/odoo16/venv
└── Odoo 19 (Principal)
    ├── Puerto: 8069
    ├── Longpolling: 8072
    ├── Workers: 13
    └── Venv: /opt/odoo19/venv
```

### Verificación de Coexistencia
```bash
# Ver ambos servicios
systemctl status odoo16
systemctl status odoo19

# Ver puertos en uso
sudo ss -tlnp | grep python3
# Deberías ver: 8016, 8116, 8069, 8072

# Ver procesos
ps aux | grep odoo

# Ver uso de memoria por instancia
ps aux | grep odoo16 | awk '{sum+=$6} END {print "Odoo 16: " sum/1024 " MB"}'
ps aux | grep odoo19 | awk '{sum+=$6} END {print "Odoo 19: " sum/1024 " MB"}'

# Verificar usuarios PostgreSQL
sudo su - postgres -c "psql -c '\du'"
```

### Acceso a Cada Instancia
```bash
# Odoo 16 (Secundario)
http://tu-servidor:8016

# Odoo 19 (Principal)
http://tu-servidor:8069
# o si configuraste dominio
https://odoo.tudominio.com
```

### Nginx para Múltiples Instancias
Si quieres configurar Nginx para ambas instancias con subdominios:

```nginx
# /etc/nginx/sites-available/odoo-multi

# Odoo 16
server {
    listen 80;
    server_name odoo16.tudominio.com;
    
    location / {
        proxy_pass http://127.0.0.1:8016;
        # ... resto de configuración
    }
    
    location /longpolling {
        proxy_pass http://127.0.0.1:8116;
    }
}

# Odoo 19 (Principal)
server {
    listen 80;
    server_name odoo.tudominio.com;
    
    location / {
        proxy_pass http://127.0.0.1:8069;
        # ... resto de configuración
    }
    
    location /longpolling {
        proxy_pass http://127.0.0.1:8072;
    }
}
```

---

## 📝 Checklist Pre-Producción

### Odoo 19 (Principal)
- [ ] Cambiar password admin (master password)
- [ ] Configurar dbfilter apropiado
- [ ] Ajustar workers según hardware real (mínimo 13 recomendado)
- [ ] Configurar backups automáticos con cron
- [ ] Probar recuperación desde backup
- [ ] Configurar Nginx + SSL
- [ ] Configurar firewall
- [ ] Monitorear logs por 24-48 horas
- [ ] Documentar contraseñas en gestor seguro
- [ ] Configurar alertas de monitoreo
- [ ] Probar reinicio del servidor
- [ ] Verificar inicio automático del servicio
- [ ] Migrar bases de datos de producción
- [ ] Actualizar módulos a versión 19
- [ ] Probar funcionalidad crítica

### Verificación de Coexistencia
- [ ] Verificar que ambos servicios inician sin conflictos
- [ ] Probar acceso a cada instancia por sus puertos
- [ ] Verificar que no hay conflictos de usuarios PostgreSQL
- [ ] Monitorear uso de recursos con ambas instancias activas
- [ ] Verificar que los backups se crean correctamente para cada instancia

---

## 🐛 Troubleshooting

### Servicio no inicia
```bash
# Ver logs detallados
sudo journalctl -u odoo19 -xe

# Verificar configuración
sudo -u odoo19 /opt/odoo19/venv/bin/python3 /opt/odoo19/odoo-server/odoo-bin \
  -c /etc/odoo19.conf --test-enable --log-level=debug

# Verificar permisos
ls -la /opt/odoo19
ls -la /var/log/odoo19

# Verificar puerto en uso
sudo ss -tlnp | grep :8069
```

### Error de memoria
```bash
# Ver uso actual
ps aux | grep odoo19 | awk '{sum+=$6} END {print sum/1024 " MB"}'

# Reducir workers temporalmente
# Editar /etc/odoo19.conf
workers = 9
limit_memory_soft = 2147483648  # 2GB

# Reiniciar
sudo systemctl restart odoo19
```

### Base de datos no conecta
```bash
# Verificar PostgreSQL
sudo systemctl status postgresql

# Probar conexión
psql -U odoo19 -h localhost -d postgres

# Ver configuración
grep db_ /etc/odoo19.conf

# Ver usuarios PostgreSQL
sudo su - postgres -c "psql -c '\du'"
```

### Puerto en uso
```bash
# Ver qué está usando el puerto
sudo lsof -i :8069

# Si hay conflicto, verificar que Odoo 16 no esté en 8069
ps aux | grep odoo

# Cambiar puerto en configuración si es necesario
# Editar /etc/odoo19.conf
http_port = 8070
```

### Conflicto con Odoo 16
```bash
# Verificar puertos
sudo ss -tlnp | grep python3

# Verificar servicios
systemctl status odoo16
systemctl status odoo19

# Verificar usuarios
ps aux | grep odoo | grep -v grep

# Si hay conflicto, revisar configuración de cada instancia
cat /etc/odoo16.conf | grep -E 'http_port|longpolling_port|db_user'
cat /etc/odoo19.conf | grep -E 'http_port|longpolling_port|db_user'
```

### Rendimiento bajo
```bash
# Verificar workers activos
ps aux | grep odoo19 | grep odoo-bin | wc -l

# Monitorear en tiempo real
htop -u odoo19

# Ver queries lentas en PostgreSQL
sudo su - postgres
psql -d nombre_bd_odoo19
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds';

# Ajustar workers
# Fórmula: (cores * 2) + 1
# Editar /etc/odoo19.conf y reiniciar
```

---

## 🆕 Novedades de Odoo 19

### Mejoras de Rendimiento
- Motor de búsqueda mejorado
- Carga de vistas más rápida
- Mejor gestión de memoria
- Optimización de ORM

### Nuevas Funcionalidades
- Interfaz de usuario mejorada
- Nuevos módulos y apps
- Mejor integración con IA (si es Enterprise)
- Mejoras en reportes

### Compatibilidad
- Python 3.10+ (Ubuntu 24.04 usa Python 3.12)
- PostgreSQL 12+ (recomendado 16)
- Navegadores modernos

---

## 📚 Referencias

- [Documentación Oficial Odoo 19](https://www.odoo.com/documentation/19.0/)
- [Guía de Deploy Odoo](https://www.odoo.com/documentation/19.0/administration/install/deploy.html)
- [PostgreSQL 16 Release Notes](https://www.postgresql.org/docs/16/release-16.html)
- [Systemd Service Manual](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Nginx Performance Tuning](https://nginx.org/en/docs/)

---

## ✅ Ventajas del Nuevo Script para Odoo 19

1. **Instancia Principal Optimizada**: Más recursos y mejor configuración
2. **PostgreSQL 16**: Última versión LTS con mejor rendimiento
3. **Aislamiento Total**: Ambiente virtual separado de Odoo 16
4. **Modernización**: Systemd avanzado con más límites de recursos
5. **Optimización**: Configuración para alto volumen desde el inicio
6. **Mantenibilidad**: Scripts de backup, monitoreo y actualización
7. **Seguridad**: Contraseñas fuertes, permisos correctos, features de systemd
8. **Escalabilidad**: Fácil ajuste de workers y recursos para instancia principal
9. **Producción Ready**: Nginx, SSL, logrotate, todo incluido y optimizado
10. **Coexistencia**: Diseñado para convivir perfectamente con Odoo 16
11. **Preparado para Futuro**: Compatible con Ubuntu 24.04 y funciones de IA

---

## 💡 Recomendaciones Finales

### Distribución de Carga Recomendada

**Odoo 19 (Principal - 70% de recursos):**
- Operaciones diarias de producción
- Usuarios principales
- Módulos críticos del negocio
- Nuevos desarrollos

**Odoo 16 (Secundario - 30% de recursos):**
- Datos históricos
- Módulos legacy
- Testing
- Migración gradual a Odoo 19

### Migración de Odoo 16 a 19
1. Instalar ambas versiones con estos scripts
2. Crear base de datos de prueba en Odoo 19
3. Migrar módulos personalizados
4. Probar funcionalidad
5. Migrar bases de datos de producción gradualmente
6. Mantener Odoo 16 como respaldo temporal

### Monitoreo Continuo
- Revisar logs diariamente
- Monitorear uso de recursos
- Ajustar workers según necesidad
- Mantener backups actualizados
- Actualizar módulos regularmente

---

**Nota Final:** Este script está específicamente optimizado para Odoo 19 como instancia principal en un servidor de producción con grandes volúmenes de datos, diseñado para convivir armoniosamente con Odoo 16 en el mismo servidor.
