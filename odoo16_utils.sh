#!/bin/bash
################################################################################
# Script de Utilidades para Gestión de Odoo 16
# Facilita tareas comunes de administración
################################################################################

OE_USER="odoo16"
OE_HOME="/opt/odoo16"
OE_CONFIG="odoo16"
VENV_PATH="$OE_HOME/venv"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar el menú
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Utilidades de Gestión - Odoo 16              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  SERVICIOS"
    echo "  1)  Iniciar Odoo 16"
    echo "  2)  Detener Odoo 16"
    echo "  3)  Reiniciar Odoo 16"
    echo "  4)  Estado del servicio"
    echo "  5)  Ver logs en tiempo real"
    echo ""
    echo "  BASE DE DATOS"
    echo "  6)  Listar bases de datos"
    echo "  7)  Crear backup de base de datos"
    echo "  8)  Restaurar backup"
    echo "  9)  Eliminar base de datos"
    echo "  10) Listar backups disponibles"
    echo ""
    echo "  MÓDULOS"
    echo "  11) Actualizar lista de módulos"
    echo "  12) Actualizar módulo específico"
    echo "  13) Instalar módulo"
    echo ""
    echo "  MANTENIMIENTO"
    echo "  14) Ver uso de recursos"
    echo "  15) Limpiar logs antiguos"
    echo "  16) Ver configuración actual"
    echo "  17) Editar configuración"
    echo "  18) Verificar salud del sistema"
    echo ""
    echo "  AVANZADO"
    echo "  19) Shell de Odoo"
    echo "  20) Actualizar Odoo 16"
    echo "  21) Instalar módulo Python"
    echo "  22) Ver contraseñas guardadas"
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
    echo -e "${BLUE}Iniciando Odoo 16...${NC}"
    sudo systemctl start $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 2. Detener Odoo
stop_odoo() {
    echo -e "${YELLOW}Deteniendo Odoo 16...${NC}"
    sudo systemctl stop $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 3. Reiniciar Odoo
restart_odoo() {
    echo -e "${YELLOW}Reiniciando Odoo 16...${NC}"
    sudo systemctl restart $OE_CONFIG
    sleep 2
    sudo systemctl status $OE_CONFIG --no-pager
    pause
}

# 4. Estado del servicio
status_odoo() {
    echo -e "${BLUE}Estado de Odoo 16:${NC}"
    sudo systemctl status $OE_CONFIG --no-pager -l
    echo ""
    echo -e "${BLUE}Procesos activos:${NC}"
    ps aux | grep -i odoo | grep -v grep
    echo ""
    echo -e "${BLUE}Puertos en uso:${NC}"
    sudo netstat -tlnp | grep python3
    pause
}

# 5. Ver logs
view_logs() {
    echo -e "${BLUE}Logs de Odoo 16 (Ctrl+C para salir):${NC}"
    echo ""
    sudo journalctl -u $OE_CONFIG -f
}

# 6. Listar bases de datos
list_databases() {
    echo -e "${BLUE}Bases de datos de Odoo 16:${NC}"
    sudo su - postgres -c "psql -l" | grep $OE_USER
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
    ls -lh $OE_HOME/backups/*.backup 2>/dev/null | awk '{print $9}' | nl
    echo ""
    echo -n "Ruta completa del archivo de backup: "
    read BACKUP_FILE
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Archivo no encontrado${NC}"
        pause
        return
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
    if ls $OE_HOME/backups/*.backup 1> /dev/null 2>&1; then
        ls -lh $OE_HOME/backups/*.backup
    else
        echo "No hay backups disponibles"
    fi
    pause
}

# 11. Actualizar lista de módulos
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

# 12. Actualizar módulo específico
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

# 13. Instalar módulo
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

# 14. Ver uso de recursos
view_resources() {
    echo -e "${BLUE}Uso de recursos del sistema:${NC}"
    echo ""
    echo -e "${BLUE}=== Memoria ===${NC}"
    free -h
    echo ""
    echo -e "${BLUE}=== CPU ===${NC}"
    top -b -n 1 | head -20
    echo ""
    echo -e "${BLUE}=== Disco ===${NC}"
    df -h
    echo ""
    echo -e "${BLUE}=== Procesos Odoo ===${NC}"
    ps aux | grep odoo | grep -v grep
    pause
}

# 15. Limpiar logs antiguos
clean_logs() {
    echo -e "${YELLOW}Limpiando logs antiguos...${NC}"
    echo ""
    echo "Espacio antes:"
    du -sh /var/log/$OE_USER
    
    echo -n "¿Eliminar logs de más de cuántos días? (default: 30): "
    read DAYS
    DAYS=${DAYS:-30}
    
    find /var/log/$OE_USER -name "*.log.*" -mtime +$DAYS -delete
    
    echo ""
    echo "Espacio después:"
    du -sh /var/log/$OE_USER
    pause
}

# 16. Ver configuración
view_config() {
    echo -e "${BLUE}Configuración actual de Odoo 16:${NC}"
    echo ""
    sudo cat /etc/${OE_CONFIG}.conf
    pause
}

# 17. Editar configuración
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

# 18. Verificar salud del sistema
check_health() {
    echo -e "${BLUE}Verificando salud del sistema Odoo 16...${NC}"
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
    if sudo netstat -tlnp | grep -q :8016; then
        echo -e "${GREEN}✓ Puerto 8016 en uso${NC}"
    else
        echo -e "${RED}✗ Puerto 8016 no está en uso${NC}"
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
    if [ $MEM_AVAILABLE -gt 500 ]; then
        echo -e "${GREEN}✓ Memoria disponible: ${MEM_AVAILABLE}MB${NC}"
    else
        echo -e "${YELLOW}⚠ Poca memoria disponible: ${MEM_AVAILABLE}MB${NC}"
    fi
    
    # Verificar logs recientes de errores
    echo -e "${BLUE}6. Errores recientes:${NC}"
    ERROR_COUNT=$(sudo journalctl -u $OE_CONFIG --since "1 hour ago" | grep -i error | wc -l)
    if [ $ERROR_COUNT -eq 0 ]; then
        echo -e "${GREEN}✓ Sin errores en la última hora${NC}"
    else
        echo -e "${YELLOW}⚠ $ERROR_COUNT errores en la última hora${NC}"
    fi
    
    pause
}

# 19. Shell de Odoo
odoo_shell() {
    echo -e "${BLUE}Shell de Odoo${NC}"
    echo -n "Nombre de la base de datos: "
    read DB_NAME
    
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Debe especificar un nombre de base de datos${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Iniciando shell de Odoo...${NC}"
    echo "Ejemplo de uso: env['res.partner'].search([])"
    echo ""
    sudo su - $OE_USER -c "$VENV_PATH/bin/python3 $OE_HOME/odoo-server/odoo-bin \
        shell -c /etc/${OE_CONFIG}.conf -d $DB_NAME"
}

# 20. Actualizar Odoo
update_odoo() {
    echo -e "${YELLOW}ADVERTENCIA: Esto actualizará el código de Odoo 16${NC}"
    echo -n "¿Continuar? (s/n): "
    read CONFIRM
    
    if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
        echo "Operación cancelada"
        pause
        return
    fi
    
    echo -e "${YELLOW}Deteniendo servicio...${NC}"
    sudo systemctl stop $OE_CONFIG
    
    echo -e "${YELLOW}Actualizando código...${NC}"
    cd $OE_HOME/odoo-server
    sudo -u $OE_USER git pull origin 16.0
    
    echo -e "${YELLOW}Actualizando dependencias...${NC}"
    sudo -u $OE_USER $VENV_PATH/bin/pip install -U -r $OE_HOME/odoo-server/requirements.txt
    
    echo -e "${YELLOW}Reiniciando servicio...${NC}"
    sudo systemctl start $OE_CONFIG
    
    echo -e "${GREEN}✓ Actualización completada${NC}"
    pause
}

# 21. Instalar módulo Python
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

# 22. Ver contraseñas guardadas
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
        11) update_module_list ;;
        12) update_module ;;
        13) install_module ;;
        14) view_resources ;;
        15) clean_logs ;;
        16) view_config ;;
        17) edit_config ;;
        18) check_health ;;
        19) odoo_shell ;;
        20) update_odoo ;;
        21) install_python_module ;;
        22) show_passwords ;;
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
