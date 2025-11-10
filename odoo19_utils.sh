#!/bin/bash
################################################################################
# Script de Utilidades para Gestión de Odoo 19 (Principal)
# Facilita tareas comunes de administración
################################################################################

OE_USER="odoo19"
OE_HOME="/opt/odoo19"
OE_CONFIG="odoo19"
VENV_PATH="$OE_HOME/venv"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar el menú
show_menu() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     Utilidades de Gestión - Odoo 19 (Principal)  ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  SERVICIOS"
    echo "  1)  Iniciar Odoo 19"
    echo "  2)  Detener Odoo 19"
    echo "  3)  Reiniciar Odoo 19"
    echo "  4)  Estado del servicio"
    echo "  5)  Ver logs en tiempo real"
    echo ""
    echo "  BASE DE DATOS"
    echo "  6)  Listar bases de datos"
    echo "  7)  Crear backup de base de datos"
    echo "  8)  Restaurar backup"
    echo "  9)  Eliminar base de datos"
    echo "  10) Listar backups disponibles"
    echo "  11) Backup de todas las bases de datos"
    echo ""
    echo "  MÓDULOS"
    echo "  12) Actualizar lista de módulos"
    echo "  13) Actualizar módulo específico"
    echo "  14) Instalar módulo"
    echo "  15) Desinstalar módulo"
    echo ""
    echo "  MANTENIMIENTO"
    echo "  16) Ver uso de recursos"
    echo "  17) Limpiar logs antiguos"
    echo "  18) Ver configuración actual"
    echo "  19) Editar configuración"
    echo "  20) Verificar salud del sistema"
    echo "  21) Ver estadísticas de PostgreSQL"
    echo ""
    echo "  AVANZADO"
    echo "  22) Shell de Odoo"
    echo "  23) Actualizar Odoo 19 (usar script update.sh)"
    echo "  24) Instalar módulo Python"
    echo "  25) Ver contraseñas guardadas"
    echo "  26) Comparar con Odoo 16"
    echo ""
    echo "  MIGRACIÓN Y TESTING"
    echo "  27) Crear base de datos de prueba"
    echo "  28) Ejecutar tests"
    echo "  29) Scaffold nuevo módulo"
    echo ""
    echo "  0)  Salir"
    echo ""
    echo -n "  Seleccione una opción: "
}

# Función para pausar
pause() {
    echo ""
    read -p "Presione Enter para continuar..."
}

# 1. Iniciar Odoo
start_odoo() {
    echo -e "${BLUE}Iniciando Odoo 19...${NC}"
    sudo systemctl start $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 2. Detener Odoo
stop_odoo() {
    echo -e "${YELLOW}Deteniendo Odoo 19...${NC}"
    sudo systemctl stop $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 3. Reiniciar Odoo
restart_odoo() {
    echo -e "${YELLOW}Reiniciando Odoo 19...${NC}"
    sudo systemctl restart $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 4. Estado del servicio
status_odoo() {
    echo -e "${BLUE}Estado de Odoo 19:${NC}"
    sudo systemctl status $OE_CONFIG --no-pager -l
    echo ""
    echo -e "${BLUE}Procesos activos:${NC}"
    ps aux | grep -i odoo19 | grep -v grep
    echo ""
    echo -e "${BLUE}Workers activos:${NC}"
    ps aux | grep odoo19 | grep odoo-bin | grep -v grep | wc -l
    echo ""
    echo -e "${BLUE}Puertos en uso:${NC}"
    sudo ss -tlnp | grep python3
    echo ""
    echo -e "${BLUE}Uso de memoria:${NC}"
    ps aux | grep odoo19 | grep -v grep | awk '{sum+=$6} END {print "Total: " sum/1024 " MB"}'
    pause
}

# 5. Ver logs
view_logs() {
    echo -e "${BLUE}Logs de Odoo 19 (Ctrl+C para salir):${NC}"
    echo ""
    echo "1) Ver logs systemd (journalctl)"
    echo "2) Ver archivo de log"
    echo "3) Ver solo errores"
    echo ""
    echo -n "Seleccione opción: "
    read LOG_OPTION
    
    case $LOG_OPTION in
        1) sudo journalctl -u $OE_CONFIG -f ;;
        2) sudo tail -f /var/log/$OE_USER/${OE_CONFIG}.log ;;
        3) sudo journalctl -u $OE_CONFIG -p err -f ;;
        *) echo "Opción inválida" ;;
    esac
}

# 6. Listar bases de datos
list_databases() {
    echo -e "${BLUE}Bases de datos de Odoo 19:${NC}"
    echo ""
    sudo su - postgres -c "psql -c \"SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datdba = (SELECT oid FROM pg_roles WHERE rolname = '$OE_USER') ORDER BY pg_database_size(datname) DESC;\""
    pause
}

# 7. Backup de base de datos
backup_database() {
    echo -e "${BLUE}Crear backup de base de datos${NC}"
    echo ""
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre de base de datos${NC}"
        pause
        return
    fi
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$OE_HOME/backups/${DB_NAME}_${TIMESTAMP}.backup"
    
    echo -e "${YELLOW}Creando backup...${NC}"
    sudo su - postgres -c "pg_dump -U $OE_USER -F c -b -v -f $BACKUP_FILE $DB_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup creado exitosamente: $BACKUP_FILE${NC}"
        ls -lh $BACKUP_FILE
        
        # Comprimir backup
        echo -e "${YELLOW}Comprimiendo backup...${NC}"
        gzip $BACKUP_FILE
        echo -e "${GREEN}✓ Backup comprimido: ${BACKUP_FILE}.gz${NC}"
        ls -lh ${BACKUP_FILE}.gz
    else
        echo -e "${RED}✗ Error al crear backup${NC}"
    fi
    pause
}

# 8. Restaurar backup
restore_database() {
    echo -e "${BLUE}Restaurar backup de base de datos${NC}"
    echo ""
    echo "Backups disponibles:"
    ls -lh $OE_HOME/backups/*.backup* 2>/dev/null | awk '{print $9}' | nl
    echo ""
    echo -n "Ruta completa del archivo de backup: "
    read BACKUP_FILE
    
    if [ ! -f "$BACKUP_FILE" ]; then
        # Intentar con .gz
        if [ -f "${BACKUP_FILE}.gz" ]; then
            echo -e "${YELLOW}Descomprimiendo backup...${NC}"
            gunzip -k ${BACKUP_FILE}.gz
            BACKUP_FILE="${BACKUP_FILE}"
        else
            echo -e "${RED}Error: Archivo no encontrado${NC}"
            pause
            return
        fi
    fi
    
    echo -n "Nombre para la nueva base de datos: "
    read NEW_DB_NAME
    
    if [ -z "$NEW_DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Creando base de datos...${NC}"
    sudo su - postgres -c "createdb -U $OE_USER -O $OE_USER -E UTF8 $NEW_DB_NAME"
    
    echo -e "${YELLOW}Restaurando backup...${NC}"
    sudo su - postgres -c "pg_restore -U $OE_USER -d $NEW_DB_NAME $BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup restaurado exitosamente${NC}"
    else
        echo -e "${RED}✗ Error al restaurar backup${NC}"
    fi
    pause
}

# 9. Eliminar base de datos
drop_database() {
    echo -e "${RED}ADVERTENCIA: Esta acción eliminará permanentemente la base de datos${NC}"
    echo ""
    echo -n "Nombre de la base de datos a eliminar: "
    read DB_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre${NC}"
        pause
        return
    fi
    
    echo -n "¿Está seguro? Escriba 'CONFIRMAR' para continuar: "
    read CONFIRM
    
    if [ "$CONFIRM" != "CONFIRMAR" ]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Eliminando base de datos...${NC}"
    sudo su - postgres -c "dropdb -U $OE_USER $DB_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Base de datos eliminada${NC}"
    else
        echo -e "${RED}✗ Error al eliminar base de datos${NC}"
    fi
    pause
}

# 10. Listar backups
list_backups() {
    echo -e "${BLUE}Backups disponibles en $OE_HOME/backups:${NC}"
    echo ""
    if ls $OE_HOME/backups/*.backup* 1> /dev/null 2>&1; then
        ls -lh $OE_HOME/backups/*.backup* | awk '{print $9, "\t", $5}' | sort -k2 -h
        echo ""
        TOTAL_SIZE=$(du -sh $OE_HOME/backups | cut -f1)
        echo -e "${CYAN}Espacio total usado por backups: $TOTAL_SIZE${NC}"
    else
        echo "No hay backups disponibles"
    fi
    pause
}

# 11. Backup de todas las bases de datos
backup_all() {
    echo -e "${BLUE}Crear backup de TODAS las bases de datos de Odoo 19${NC}"
    echo -n "¿Continuar? (s/n): "
    read CONFIRM
    
    if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
        echo "Operación cancelada"
        pause
        return
    fi
    
    echo -e "${YELLOW}Ejecutando script de backup...${NC}"
    sudo $OE_HOME/backup.sh
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup completado${NC}"
    else
        echo -e "${RED}✗ Error en backup${NC}"
    fi
    pause
}

# 12. Actualizar lista de módulos
update_module_list() {
    echo -e "${BLUE}Actualizar lista de módulos${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre de base de datos${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Actualizando lista de módulos...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        -c /etc/${OE_CONFIG}.conf -d $DB_NAME -u base --stop-after-init"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Lista de módulos actualizada${NC}"
    else
        echo -e "${RED}✗ Error al actualizar${NC}"
    fi
    pause
}

# 13. Actualizar módulo específico
update_module() {
    echo -e "${BLUE}Actualizar módulo específico${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    echo -n "Nombre del módulo: "
    read MODULE_NAME
    
    if [ -z "$DB_NAME" ] || [ -z "$MODULE_NAME" ]; then
        echo -e "${RED}Error: Debe especificar base de datos y módulo${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Actualizando módulo $MODULE_NAME...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        -c /etc/${OE_CONFIG}.conf -d $DB_NAME -u $MODULE_NAME --stop-after-init"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Módulo actualizado${NC}"
    else
        echo -e "${RED}✗ Error al actualizar módulo${NC}"
    fi
    pause
}

# 14. Instalar módulo
install_module() {
    echo -e "${BLUE}Instalar módulo${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    echo -n "Nombre del módulo: "
    read MODULE_NAME
    
    if [ -z "$DB_NAME" ] || [ -z "$MODULE_NAME" ]; then
        echo -e "${RED}Error: Debe especificar base de datos y módulo${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Instalando módulo $MODULE_NAME...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        -c /etc/${OE_CONFIG}.conf -d $DB_NAME -i $MODULE_NAME --stop-after-init"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Módulo instalado${NC}"
    else
        echo -e "${RED}✗ Error al instalar módulo${NC}"
    fi
    pause
}

# 15. Desinstalar módulo
uninstall_module() {
    echo -e "${RED}Desinstalar módulo${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    echo -n "Nombre del módulo: "
    read MODULE_NAME
    
    if [ -z "$DB_NAME" ] || [ -z "$MODULE_NAME" ]; then
        echo -e "${RED}Error: Debe especificar base de datos y módulo${NC}"
        pause
        return
    fi
    
    echo -n "¿Está seguro de desinstalar '$MODULE_NAME'? (s/n): "
    read CONFIRM
    
    if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
        echo "Operación cancelada"
        pause
        return
    fi
    
    echo -e "${YELLOW}Desinstalando módulo $MODULE_NAME...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin shell \
        -c /etc/${OE_CONFIG}.conf -d $DB_NAME <<EOF
module = env['ir.module.module'].search([('name', '=', '$MODULE_NAME')])
if module:
    module.button_immediate_uninstall()
    print('Módulo desinstalado')
else:
    print('Módulo no encontrado')
EOF"
    pause
}

# 16. Ver uso de recursos
view_resources() {
    echo -e "${BLUE}Uso de recursos del sistema (Odoo 19):${NC}"
    echo ""
    echo -e "${BLUE}=== Memoria ===${NC}"
    free -h
    echo ""
    echo -e "${BLUE}=== Memoria Odoo 19 ===${NC}"
    ps aux | grep odoo19 | grep -v grep | awk '{sum+=$6} END {print "Total: " sum/1024 " MB"}'
    ps aux | grep odoo19 | grep -v grep | awk '{if($6>max){max=$6; line=$0}} END {print "Worker más pesado: " max/1024 " MB"}'
    echo ""
    echo -e "${BLUE}=== CPU ===${NC}"
    top -b -n 1 | grep odoo19 | head -10
    echo ""
    echo -e "${BLUE}=== Disco ===${NC}"
    df -h
    echo ""
    echo -e "${BLUE}=== PostgreSQL ===${NC}"
    sudo du -sh /var/lib/postgresql
    echo ""
    echo -e "${BLUE}=== Data dir ===${NC}"
    sudo du -sh $OE_HOME/data
    pause
}

# 17. Limpiar logs antiguos
clean_logs() {
    echo -e "${YELLOW}Limpiando logs antiguos...${NC}"
    echo ""
    echo "Espacio antes:"
    du -sh /var/log/$OE_USER
    
    echo -n "¿Eliminar logs de más de cuántos días? (default: 30): "
    read DAYS
    DAYS=${DAYS:-30}
    
    find /var/log/$OE_USER -name "*.log.*" -mtime +$DAYS -delete
    sudo journalctl --vacuum-time=${DAYS}d
    
    echo ""
    echo "Espacio después:"
    du -sh /var/log/$OE_USER
    pause
}

# 18. Ver configuración
view_config() {
    echo -e "${BLUE}Configuración actual de Odoo 19:${NC}"
    echo ""
    sudo cat /etc/${OE_CONFIG}.conf
    pause
}

# 19. Editar configuración
edit_config() {
    echo -e "${YELLOW}Editando configuración...${NC}"
    sudo nano /etc/${OE_CONFIG}.conf
    echo ""
    echo -e "${YELLOW}¿Desea reiniciar Odoo para aplicar cambios? (s/n):${NC}"
    read RESTART
    if [ "$RESTART" = "s" ] || [ "$RESTART" = "S" ]; then
        restart_odoo
    fi
}

# 20. Verificar salud del sistema
check_health() {
    echo -e "${BLUE}Verificando salud del sistema Odoo 19...${NC}"
    echo ""
    
    # Verificar servicio
    echo -e "${BLUE}1. Estado del servicio:${NC}"
    if systemctl is-active --quiet $OE_CONFIG; then
        echo -e "${GREEN}✓ Servicio activo${NC}"
    else
        echo -e "${RED}✗ Servicio inactivo${NC}"
    fi
    
    # Verificar PostgreSQL
    echo -e "${BLUE}2. PostgreSQL:${NC}"
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}✓ PostgreSQL activo${NC}"
    else
        echo -e "${RED}✗ PostgreSQL inactivo${NC}"
    fi
    
    # Verificar puertos
    echo -e "${BLUE}3. Puertos:${NC}"
    if sudo ss -tlnp | grep -q :8069; then
        echo -e "${GREEN}✓ Puerto 8069 en uso${NC}"
    else
        echo -e "${RED}✗ Puerto 8069 no está en uso${NC}"
    fi
    
    if sudo ss -tlnp | grep -q :8072; then
        echo -e "${GREEN}✓ Puerto 8072 (longpolling) en uso${NC}"
    else
        echo -e "${RED}✗ Puerto 8072 no está en uso${NC}"
    fi
    
    # Verificar espacio en disco
    echo -e "${BLUE}4. Espacio en disco:${NC}"
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $DISK_USAGE -lt 85 ]; then
        echo -e "${GREEN}✓ Espacio suficiente (${DISK_USAGE}% usado)${NC}"
    else
        echo -e "${RED}✗ Poco espacio en disco (${DISK_USAGE}% usado)${NC}"
    fi
    
    # Verificar memoria
    echo -e "${BLUE}5. Memoria:${NC}"
    MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
    if [ $MEM_AVAILABLE -gt 1000 ]; then
        echo -e "${GREEN}✓ Memoria disponible: ${MEM_AVAILABLE}MB${NC}"
    else
        echo -e "${YELLOW}⚠ Poca memoria disponible: ${MEM_AVAILABLE}MB${NC}"
    fi
    
    # Verificar workers
    echo -e "${BLUE}6. Workers activos:${NC}"
    WORKER_COUNT=$(ps aux | grep odoo19 | grep odoo-bin | grep -v grep | wc -l)
    EXPECTED_WORKERS=$(grep -oP 'workers = \K\d+' /etc/${OE_CONFIG}.conf)
    if [ $WORKER_COUNT -ge $EXPECTED_WORKERS ]; then
        echo -e "${GREEN}✓ Workers: $WORKER_COUNT/$EXPECTED_WORKERS${NC}"
    else
        echo -e "${YELLOW}⚠ Workers: $WORKER_COUNT/$EXPECTED_WORKERS (menos de lo esperado)${NC}"
    fi
    
    # Verificar logs recientes de errores
    echo -e "${BLUE}7. Errores recientes:${NC}"
    ERROR_COUNT=$(sudo journalctl -u $OE_CONFIG --since "1 hour ago" | grep -i error | wc -l)
    if [ $ERROR_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ Sin errores en la última hora${NC}"
    else
        echo -e "${YELLOW}⚠ $ERROR_COUNT errores en la última hora${NC}"
    fi
    
    # Verificar conexiones a PostgreSQL
    echo -e "${BLUE}8. Conexiones PostgreSQL:${NC}"
    PG_CONN=$(sudo su - postgres -c "psql -t -c \"SELECT count(*) FROM pg_stat_activity WHERE usename='$OE_USER';\"" | xargs)
    echo -e "${CYAN}Conexiones activas: $PG_CONN${NC}"
    
    pause
}

# 21. Ver estadísticas de PostgreSQL
view_pg_stats() {
    echo -e "${BLUE}Estadísticas de PostgreSQL (Odoo 19):${NC}"
    echo ""
    echo "1) Ver conexiones activas"
    echo "2) Ver queries lentas"
    echo "3) Ver tamaño de bases de datos"
    echo "4) Ver índices no utilizados"
    echo "5) Ver tablas más grandes"
    echo ""
    echo -n "Seleccione opción: "
    read PG_OPTION
    
    case $PG_OPTION in
        1)
            sudo su - postgres -c "psql -c \"SELECT datname, usename, application_name, client_addr, state, query FROM pg_stat_activity WHERE usename='$OE_USER';\""
            ;;
        2)
            echo -n "Nombre de la base de datos: "
            read DB_NAME
            sudo su - postgres -c "psql -d $DB_NAME -c \"SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds' AND state = 'active';\""
            ;;
        3)
            sudo su - postgres -c "psql -c \"SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datdba = (SELECT oid FROM pg_roles WHERE rolname = '$OE_USER') ORDER BY pg_database_size(datname) DESC;\""
            ;;
        4)
            echo -n "Nombre de la base de datos: "
            read DB_NAME
            sudo su - postgres -c "psql -d $DB_NAME -c \"SELECT schemaname, tablename, indexname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY idx_scan;\""
            ;;
        5)
            echo -n "Nombre de la base de datos: "
            read DB_NAME
            sudo su - postgres -c "psql -d $DB_NAME -c \"SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 20;\""
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    pause
}

# 22. Shell de Odoo
odoo_shell() {
    echo -e "${BLUE}Shell de Odoo 19${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre de base de datos${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Iniciando shell de Odoo...${NC}"
    echo "Ejemplo de uso: env['res.partner'].search([])"
    echo "Para salir: Ctrl+D"
    echo ""
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        shell -c /etc/${OE_CONFIG}.conf -d $DB_NAME"
}

# 23. Actualizar Odoo
update_odoo() {
    echo -e "${YELLOW}ADVERTENCIA: Esto actualizará el código de Odoo 19${NC}"
    echo -e "${YELLOW}Se recomienda usar el script: $OE_HOME/update.sh${NC}"
    echo ""
    echo -n "¿Ejecutar script de actualización? (s/n): "
    read CONFIRM
    
    if [ "$CONFIRM" = "s" ] || [ "$CONFIRM" = "S" ]; then
        sudo $OE_HOME/update.sh
    else
        echo "Operación cancelada"
    fi
    pause
}

# 24. Instalar módulo Python
install_python_module() {
    echo -e "${BLUE}Instalar módulo Python en el ambiente virtual${NC}"
    echo -n "Nombre del paquete: "
    read PACKAGE_NAME
    
    if [ -z "$PACKAGE_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre de paquete${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Instalando $PACKAGE_NAME...${NC}"
    sudo -u $OE_USER $VENV_PATH/bin/pip install $PACKAGE_NAME
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Paquete instalado${NC}"
        echo -e "${YELLOW}Recuerde reiniciar Odoo para que tome efecto${NC}"
    else
        echo -e "${RED}✗ Error al instalar paquete${NC}"
    fi
    pause
}

# 25. Ver contraseñas guardadas
show_passwords() {
    echo -e "${BLUE}Información de credenciales:${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Estas contraseñas están guardadas en el servidor${NC}"
    echo ""
    
    echo -e "${BLUE}Master Password (admin_passwd):${NC}"
    sudo grep admin_passwd /etc/${OE_CONFIG}.conf | cut -d'=' -f2 | xargs
    
    echo ""
    echo -e "${BLUE}PostgreSQL Password:${NC}"
    sudo grep db_password /etc/${OE_CONFIG}.conf | cut -d'=' -f2 | xargs
    
    echo ""
    echo -e "${YELLOW}Guarde estas contraseñas en un lugar seguro${NC}"
    pause
}

# 26. Comparar con Odoo 16
compare_with_odoo16() {
    echo -e "${CYAN}Comparación Odoo 19 vs Odoo 16:${NC}"
    echo ""
    
    echo -e "${BLUE}=== Servicios ===${NC}"
    echo -n "Odoo 19: "
    systemctl is-active odoo19 && echo -e "${GREEN}Activo${NC}" || echo -e "${RED}Inactivo${NC}"
    echo -n "Odoo 16: "
    systemctl is-active odoo16 && echo -e "${GREEN}Activo${NC}" || echo -e "${RED}Inactivo${NC}"
    
    echo ""
    echo -e "${BLUE}=== Puertos ===${NC}"
    echo "Odoo 19:"
    sudo ss -tlnp | grep python3 | grep -E '8069|8072'
    echo "Odoo 16:"
    sudo ss -tlnp | grep python3 | grep -E '8016|8116'
    
    echo ""
    echo -e "${BLUE}=== Uso de Memoria ===${NC}"
    echo -n "Odoo 19: "
    ps aux | grep odoo19 | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}'
    echo -n "Odoo 16: "
    ps aux | grep odoo16 | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}'
    
    echo ""
    echo -e "${BLUE}=== Workers ===${NC}"
    echo -n "Odoo 19: "
    ps aux | grep odoo19 | grep odoo-bin | grep -v grep | wc -l
    echo -n "Odoo 16: "
    ps aux | grep odoo16 | grep odoo-bin | grep -v grep | wc -l
    
    echo ""
    echo -e "${BLUE}=== Bases de Datos ===${NC}"
    echo "Odoo 19:"
    sudo su - postgres -c "psql -t -c \"SELECT count(*) FROM pg_database WHERE datdba = (SELECT oid FROM pg_roles WHERE rolname = 'odoo19');\"" | xargs
    echo "Odoo 16:"
    sudo su - postgres -c "psql -t -c \"SELECT count(*) FROM pg_database WHERE datdba = (SELECT oid FROM pg_roles WHERE rolname = 'odoo16');\"" | xargs
    
    pause
}

# 27. Crear base de datos de prueba
create_test_db() {
    echo -e "${BLUE}Crear base de datos de prueba${NC}"
    echo -n "Nombre de la base de datos de prueba: "
    read TEST_DB
    
    if [ -z "$TEST_DB" ]; then
        echo -e "${RED}Error: Debe especificar un nombre${NC}"
        pause
        return
    fi
    
    echo -n "¿Instalar datos de demostración? (s/n): "
    read DEMO_DATA
    
    DEMO_FLAG=""
    if [ "$DEMO_DATA" != "s" ] && [ "$DEMO_DATA" != "S" ]; then
        DEMO_FLAG="--without-demo=all"
    fi
    
    echo -e "${YELLOW}Creando base de datos $TEST_DB...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        -c /etc/${OE_CONFIG}.conf -d $TEST_DB -i base $DEMO_FLAG --stop-after-init"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Base de datos creada${NC}"
    else
        echo -e "${RED}✗ Error al crear base de datos${NC}"
    fi
    pause
}

# 28. Ejecutar tests
run_tests() {
    echo -e "${BLUE}Ejecutar tests de Odoo 19${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    echo -n "Módulo a testear (o 'all' para todos): "
    read MODULE_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar una base de datos${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Ejecutando tests...${NC}"
    if [ "$MODULE_NAME" = "all" ]; then
        sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
            -c /etc/${OE_CONFIG}.conf -d $DB_NAME --test-enable --stop-after-init --log-level=test"
    else
        sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
            -c /etc/${OE_CONFIG}.conf -d $DB_NAME -u $MODULE_NAME --test-enable --stop-after-init --log-level=test"
    fi
    
    pause
}

# 29. Scaffold nuevo módulo
scaffold_module() {
    echo -e "${BLUE}Crear estructura de nuevo módulo${NC}"
    echo -n "Nombre del módulo: "
    read MODULE_NAME
    
    if [ -z "$MODULE_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Creando módulo $MODULE_NAME en $OE_HOME/custom/addons...${NC}"
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        scaffold $MODULE_NAME $OE_HOME/custom/addons/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Módulo creado en: $OE_HOME/custom/addons/$MODULE_NAME${NC}"
        echo ""
        echo "Archivos creados:"
        ls -la $OE_HOME/custom/addons/$MODULE_NAME/
    else
        echo -e "${RED}✗ Error al crear módulo${NC}"
    fi
    pause
}

# Loop principal
while true; do
    show_menu
    read OPTION
    
    case $OPTION in
        1) start_odoo ;;
        2) stop_odoo ;;
        3) restart_odoo ;;
        4) status_odoo ;;
        5) view_logs ;;
        6) list_databases ;;
        7) backup_database ;;
        8) restore_database ;;
        9) drop_database ;;
        10) list_backups ;;
        11) backup_all ;;
        12) update_module_list ;;
        13) update_module ;;
        14) install_module ;;
        15) uninstall_module ;;
        16) view_resources ;;
        17) clean_logs ;;
        18) view_config ;;
        19) edit_config ;;
        20) check_health ;;
        21) view_pg_stats ;;
        22) odoo_shell ;;
        23) update_odoo ;;
        24) install_python_module ;;
        25) show_passwords ;;
        26) compare_with_odoo16 ;;
        27) create_test_db ;;
        28) run_tests ;;
        29) scaffold_module ;;
        0) 
            echo -e "${GREEN}¡Hasta luego!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            pause
            ;;
    esac
done
