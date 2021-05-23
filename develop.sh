#!/usr/bin/env bash
#stolen from https://serversforhackers.com/dockerized-app/compose-separated
#TODO: check if we are in correct directory
#TODO: check if compose files are available
#TODO: eve-universe sql import function

# https://mywiki.wooledge.org/glob
# https://sipb.mit.edu/doc/safe-shell/
set -Eeuo pipefail
shopt -s failglob

# backup location
#BACKUP_LOCATION="/var/backups/"
BACKUP_LOCATION="/tmp/"

# Decide which docker-compose file to use
COMPOSE_FILE="dev"

# KISS-framework related variables 
KISS_DB_CONTAINERNAME="mariadb"
KISS_APP_NAME="seat"

# check if we are root, if not use sudo
SUDO=''
if [ "${EUID}" != "0" ]; then
    SUDO='sudo'
fi

# setup_colors for message function
setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}
setup_colors

# message function
msg() {
	echo >&2 -e "$(date +%H:%M:%S%z) ${1-}"
}

# Create docker-compose command to run
COMPOSE="docker-compose -f docker-compose-${COMPOSE_FILE}.yml --env=.env.${COMPOSE_FILE}"

cron-backup() {
	BACKUP_LOCATION=${BACKUP_LOCATION}$(date +%F_%H-%M-%S)
        msg "Creating backup location at ${BACKUP_LOCATION}"
        if ! mkdir -p "${BACKUP_LOCATION}" ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to create backup location at ${BACKUP_LOCATION}."  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully created backup location at ${BACKUP_LOCATION}"
        msg "Creating MySQL backup"
	if ! ${COMPOSE} exec "${KISS_DB_CONTAINERNAME}" sh -c "exec mysqldump \${MYSQL_DATABASE} -u\${MYSQL_USER} -p\${MYSQL_PASSWORD}" | gzip > "${BACKUP_LOCATION}/backup_database_${KISS_APP_NAME}.sql.gz" ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to create MySQL backup."  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully created MySQL backup"
}

backup() {
	BACKUP_LOCATION=${BACKUP_LOCATION}$(date +%F_%H-%M-%S)
        msg "Creating backup location at ${BACKUP_LOCATION}"
        if ! mkdir -p "${BACKUP_LOCATION}" ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to create backup location at ${BACKUP_LOCATION}. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully created backup location at ${BACKUP_LOCATION}"
        msg "Creating MySQL backup"
	if ! ${COMPOSE} exec "${KISS_DB_CONTAINERNAME}" sh -c "exec mysqldump \${MYSQL_DATABASE} -u\${MYSQL_USER} -p\${MYSQL_PASSWORD}" | gzip > "${BACKUP_LOCATION}/backup_database_${KISS_APP_NAME}.sql.gz" ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to create MySQL backup. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully created MySQL backup"
}

restore() {
	if [ -z "${*}" ]; then
        	msg "${RED}ERROR${NOFORMAT} No valid input detected. Please provide full path to a backup location. ${YELLOW}Execute bash -x \$yourscriptfilename.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	verify_backup "$@"
	RESTORE_TAR_PATH="${*}"
        msg "Stopping docker containers"
	if ! ${COMPOSE} stop >/dev/null 2>&1 ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to stop docker containers. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully stopped docker containers"
        msg "Starting MySQL docker container"
	if ! ${COMPOSE} up -d "${KISS_DB_CONTAINERNAME}" >/dev/null 2>&1 ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to start MySQL docker container. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully started MySQL docker containers"
        msg "Restoring MySQL backup"
	if ! gunzip < "${RESTORE_TAR_PATH}"/backup_database_"${KISS_APP_NAME}".sql.gz | ${COMPOSE} exec -T "${KISS_DB_CONTAINERNAME}" sh -c "exec mysql \${MYSQL_DATABASE} -u\${MYSQL_USER} -p\${MYSQL_PASSWORD}" ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to restore MySQL backup. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully restored MySQL backup"
        msg "Starting docker containers"
	if ! ${COMPOSE} up -d >/dev/null 2>&1 ; then
        	msg "${RED}ERROR${NOFORMAT} Failed to start docker containers. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully started docker containers"
      
}

verify_backup() {
	ARCHIVE_PATH="${1}"
	msg "Verifying backup directory"
	if ! [ -d "${ARCHIVE_PATH}" ]; then
		msg "${RED}ERROR${NOFORMAT} Failed to verify backup directory. ${YELLOW}Execute bash -x \$yourscriptfilename.sh for debugging.${NOFORMAT}"
		exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully verified backup directory"
        msg "Verifying database backup file"
	if ! ${SUDO} gzip -t -v "${ARCHIVE_PATH}"/backup_database_"${KISS_APP_NAME}".sql.gz >/dev/null 2>&1 ; then
              msg "${RED}ERROR${NOFORMAT} Failed to verify backup file of ${i}. ${YELLOW}Execute bash -x \$yourscriptfile.sh for debugging.${NOFORMAT}"  
	      exit 1
	fi
	msg "${GREEN}OK${NOFORMAT} Successfully verified database backup file"
	
}

# If we pass any arguments...
if [ $# -gt 0 ];then
    # "cronbackup" 
    if [ "$1" == "cron-backup" ]; then
	    cron-backup
    # "backup" 
    elif [ "$1" == "backup" ]; then
        #shift 1
	echo -e "This will backup your MySQL database.\nDo you want to continue?"
        select yn in "Yes" "No"; do
            case ${yn} in
                Yes ) backup; break;;
                No ) exit;;
		* ) exit;;
            esac
        done
    elif [ "$1" == "restore" ]; then
        shift 1
	echo -e "This will restore a backup of your MySQL database. In this process ${RED}your containers will be stopped${NOFORMAT} and ${RED}all current data in the database will be lost.${NOFORMAT}\nDo you want to continue?"
        select yn in "Yes" "No"; do
            case ${yn} in
                Yes ) restore "$@"; break;;
                No ) exit;;
		* ) exit;;
            esac
        done
    # Else, pass-thru args to docker-compose
    else
        ${COMPOSE} "$@"
    fi

else
    msg "${RED}ERROR${NOFORMAT} No commands received. Displaying script help and status of docker containers"
    msg "COMMANDS"
    msg "   backup: creates a backup of the mysql database"
    msg "   cron-backup: creates a backup of the mysql database without manual confirmation. For use with cronjobs"
    msg "   restore: restores mysql database from a provided backup"
    msg "   up -d: start docker containers"
    msg "   stop: stop running docker containers"
    msg "   down: stop and remove docker containers"
    msg "   down -v: remove docker containers and volumes including application data. ${RED}Use with care${NOFORMAT}"
    msg "   logs -f: display logs for running containers"
    msg "   ps: display status of docker containers"
    msg "   --help: display docker-compose help\n"
    ${COMPOSE} ps
fi
