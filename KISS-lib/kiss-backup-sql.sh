#!/usr/bin/env bash
#
cron-backup-sql() {
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

backup-sql() {
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

restore-sql() {
	if [ -z "${*}" ]; then
        	msg "${RED}ERROR${NOFORMAT} No valid input detected. Please provide full path to a backup location. ${YELLOW}Execute bash -x \$yourscriptfilename.sh for debugging.${NOFORMAT}"
		exit 1
	fi
	verify-backup-sql "$@"
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
	# dirty workaround. TODO: check for mariadb container healthcheck
	msg "Waiting 10 seconds for MySQL docker container"
	sleep 10
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

verify-backup-sql() {
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
