#!/usr/bin/bash

###################################################################

#                    CONFIGURATION SECTION                        #

###################################################################

# destination of backup directory
BACKUP_DEST="/root/backups"

# list of source files for 
SOURCE_FILES="/root/.backup-config.yaml"

# create archive filename.
NOW=$(date +'%F_%H-%M-%S')
HOSTNAME=$(hostname -s)
ARCHIVE_FILENAME="${HOSTNAME}_${NOW}.tar.gz"

# log files
LOG_FILENAME="$HOME/$HOSTNAME-backup.log"

# set maximum backups per period
MAX_BACKUPS=3

# periods to keep
readonly -a PERIODS=(daily weekly monthly yearly)

# how many backup to keep for each period
readonly -A PERIOD_KEEPS=([daily]=7 [weekly]=4 [monthly]=12 [yearly]=1)

# time of period in seconds
readonly -A PERIOD_TIMES=([daily]=86400 [weekly]=604800 [monthly]=2419200 [yearly]=31536000)

# pattern of the archive filename
readonly -A PERIOD_PATTERNS=([weekly]=+%Y-%m-%d_??-??-?? [monthly]=+%Y-%m-??_??-??-?? [yearly]=+%Y-??-??_??-??-??)

# display help
display_help() {
	echo -e "\nUsage:
	backup.sh [options] [commands] 
	backup.sh backup 
	backup.sh rotate
	
	Backup or rotate files backups.
	
	Commands
	  backup      		backup the files, directory or database from the given config file 
	  rotate		rotate all backup files (daily, weekly, monthly, yearly)
	
	Option:
	  -h, --help		display this help
	  "
}

rotate_process() {
	# Iterate through backup directories
	for dir in $BACKUP_DEST; do
		# loop over names of periods (daily,weekly,monthly,yearly)
		idx_period=1
	        for period in "${PERIODS[@]}"; do
			max_age=$((${PERIOD_KEEPS[$period]} * ${PERIOD_TIMES[$period]}))
			next_period=${PERIODS[$idx_period]}

			# loop over files
			for file in `ls -Art "${dir}/${period}"`; do
				timestamp_file=`date +%s -r "${dir}/${period}/${file}"`
				age=$(($(date +%s) - $timestamp_file))

				if [[ $age -gt $max_age ]]; then
					if [[ "${next_period}" != "" ]]; then
						pattern=$(date -d @$timestamp_file ${PERIOD_PATTERNS[$next_period]})
						
						if ! compgen -G "${dir}/${next_period}/*.$pattern.*" > /dev/null; then
							count_file_target=$(ls -A "$dir/$next_period" | wc -l)
							old_file_target=$(ls -tr "$dir/$next_period" | head -1)

							if [ $count_file_target -eq ${MAX_BACKUPS} ]; then
								rm ${dir}/${next_period}/$old_file_target

								mv ${dir}/${period}/${file} ${dir}/${next_period}/
							else
								mv ${dir}/${period}/${file} ${dir}/${next_period}/
							fi

						else 
							rm ${dir}/${period}/$file
						fi	
					else
						rm ${dir}/${period}/$file
					fi
				fi
			done
			let idx_periode++
	        done
	done
}

# display help to list options allowed
short_opts=h
long_opts=help

set +e
OPTS=$(getopt -a -n backup.sh -o $short_opts -l $long_opts -- "$@")
if [ $? -ne 0 ]; then
  display_help
  exit 1
fi
set -e

###################################################################

#                          log()	                          #

###################################################################

# send output process to log file
log() {
	local status=$1
	local msg=$2
	local datetime=$(date +'%F %T')

	[[ ! -f "$LOG_FILENAME" ]] && touch "$LOG_FILENAME"

	case "$status" in
		"success") echo -e "[$datetime] SUCCESS: $msg" >> $LOG_FILENAME
		;;
		"error") echo -e "[$datetime] ERROR: $msg" >> $LOG_FILENAME
		;;	
		"warning") echo -e "[$datetime] WARNING: $msg" >> $LOG_FILENAME
		;;	
		"info") echo -e "[$datetime] INFO: $msg" >> $LOG_FILENAME
		;;	
	esac
}

###################################################################

#                          am_i_root()                         	  #

###################################################################

# is script run as root
am_i_root() {
	if [[ `id -u` -ne 0 ]]; then
		echo "Please run this script as root!" >&2
		log "error" "Please run this script as root!"
		exit 1
	fi
}

###################################################################

#                          check_config_file()                    #

###################################################################

# checking config file
check_config_file() {
	if [[ ! -f "$SOURCE_FILES" ]]; then
  		echo "$SOURCE_FILES DOES NOT EXIST!!" >&2
		log "error" "$SOURCE_FILES DOES NOT EXIST!!"
  		exit 1
	fi
}

###################################################################

#                          check_dest_dir()                       #

###################################################################

# checking backup destination dir
check_dest_dir() {
	if [[ ! -d $BACKUP_DEST ]]; then
		echo "Directory destination $BACKUP_DEST DOES NOT EXIST!!"
		log "info" "Directory destination $BACKUP_DEST NOT EXISTS!!"

		echo "Creating directory $BACKUP_DEST..."
		log "info" "Creating directory $BACKUP_DEST"
		mkdir $BACKUP_DEST
		sleep 2

		echo "Creating directory ${BACKUP_DEST}/daily"
		log "info" "Creating directory ${BACKUP_DEST}/daily"
		sleep 1
		echo "Creating directory ${BACKUP_DEST}/weekly"
		log "info" "Creating directory ${BACKUP_DEST}/weekly"
		sleep 1
		echo "Creating directory ${BACKUP_DEST}monthly"
		log "info" "Creating directory ${BACKUP_DEST}/monthly"
		sleep 1
		echo "Creating directory ${BACKUP_DEST}/yearly"
		log "info" "Creating directory ${BACKUP_DEST}/yearly"
		mkdir $BACKUP_DEST/{daily,weekly,monthly,yearly}
	fi
}

###################################################################

#                          checking()                         	  #

###################################################################

# checking before backup process
checking() {
	check_config_file
	check_dest_dir
}

###################################################################

#                          backup_process()                       #

###################################################################

# backup process
backup_process() {
	# Print start status message.
	echo -e "\nBacking up ...."
	date
	echo

	backup_files=$(yq ".files[]" $SOURCE_FILES)
	backup_dirs=$(yq ".directories[]" $SOURCE_FILES)
	backup_db=$(yq ".databases | keys | .[]" $SOURCE_FILES)
	
	list_files=""
	list_dirs=""
	list_db=""

	# loop all files then check file is exists
	for file in $backup_files; do
		echo "Checking file: $file"
		sleep 1
		
		# if file not found send error to log 
		if [[ ! -f "$file" ]]; then 
			echo "File Not Found!!"
			log "info" "File: $file NOT FOUND!!"
		else
			list_files+="$file "
		fi 
	done

	# loop all dirs then check dir is exists
	for dir in $backup_dirs; do
		echo "Checking directory: $dir"
		sleep 1
		
		# if directory not found send error to log
		if [[ ! -d "$dir" ]]; then 
			echo "Directory Not Found!!"
			log "info" "Directory: $dir NOT FOUND!!"
		else
			list_dirs+="$dir/ "
		fi
	done


	# loop all database name
	sql_files=""
	for db_name in $backup_db; do
		echo "Backing up database: $db_name"
		# get attr then store to variable
		db_type=$(yq ".databases.$db_name.type" $SOURCE_FILES)
		db_user=$(yq ".databases.$db_name.username" $SOURCE_FILES)
    		db_pass=$(yq ".databases.$db_name.password" $SOURCE_FILES)

		# if attr required not filled
		if [ "$db_type" == "null" ] && [ "$db_user" == "null" ] && [ "$db_pass" == "null" ]; then
			echo "Required attributed for database $db_name must filled!"
			echo "Backup for database $db_name will skipped!"
			log "warning" "Required attributed for database $db_name must filled!"
			log "info" "Backup for database $db_name will skipped!"
		fi

		# if optional attr is filled 
	   	if $(yq ".databases.$db_name | has(\"port\")" $SOURCE_FILES); then
			db_port=$(yq ".databases.$db_name.port" $SOURCE_FILES)	
		fi
		
		case $db_type in
		 "mysql") 
			# set output name after dump database
			output_sql="/tmp/${db_name}-${NOW}.sql.gz"

			# set mysql password to use mysqldump without password
			echo -e "[mysqldump]\npassword=$db_pass" > ~/.mylogin.cnf && chmod 600 ~/.mylogin.cnf

			# save mysql out
			mysql_exit_code=0
			# if db_port defined, then add option -P to set the port explicitly			
			if [ "$db_port" != "null" ]; then
				mysql_output=$(mysqldump --defaults-file=~/.mylogin.cnf -u ${db_user} -P ${db_port} $db_name 2> ~/.my-backup.err | gzip -9 > $output_sql)
			else
				mysql_output=$(mysqldump --defaults-file=~/.mylogin.cnf -u ${db_user} $db_name 2> ~/.my-backup.err | gzip -9 > $output_sql)
			fi
			
			errors=$(cat ~/.my-backup.err)
			# check if mysqldump error then send to log
                        if [[ $errors != "" ]]; then
                        	log "error" "$errors"
                        	log "error" "mysqldump: Exited with errors!"
                        	log "error" "Backup for database $db_name will skipped!"
                                echo "mysqldump: Exited with errors!" >&2
                                echo "Backup for database $db_name will skipped!"

				# remove error log mysqldump
				rm ~/.my-backup.err

				# remove empty mysql backup
				rm $output_sql
			else
				# append path output file to sql_files
				sql_files+="$output_sql "
	
				echo "Backup database succeded: $db_name"
				log "success" "Backup database succeded $db_name"
                        fi	

			# remove default-file
			rm ~/.mylogin.cnf
		;;
		*)
			echo "Database type not matching!"
			echo "Backup for database $db_name will skipped!"
			log "warning" "Database type not matching!"
			log "warning" "Backup for database $db_name will skipped!"
		;;
		esac
	done

	# trim absolute path sql_files just basename
	for sql_file in $sql_files; do
		# after get basename sql file save to list_db
		list_db+=$(basename $sql_file)" "
	done	
	
	# count file at destination
	first_period=${PERIODS[0]}
	count_file_target=$(ls -A "$BACKUP_DEST/$first_period" | wc -l)
	old_file_target=$(ls -tr "$BACKUP_DEST/$first_period" | head -1)

	if [ $count_file_target -eq ${MAX_BACKUPS} ]; then
        	rm ${BACKUP_DEST}/${first_period}/$old_file_target
        fi


	# Backup the files using tar.
	tar_output=$(tar -czf $BACKUP_DEST/$first_period/$ARCHIVE_FILENAME $list_files $list_dirs -C /tmp $list_db 2>&1)

	# Check the exit status of the tar command
	if [[ $? -ne 0 ]]; then
		# Backup failed
		log "error" "$tar_output"

		echo "tar: Exited with errors!" >&2 
		echo "Script will exited!" >&2
		exit 1
	fi
	
	# remove database dump at /tmp
	rm /tmp/$list_db

	# Print end status message.
	echo
	if [[ -f $BACKUP_DEST/$first_period/$ARCHIVE_FILENAME ]]; then
        	log "success" "Backup completed $BACKUP_DEST/$first_period/$ARCHIVE_FILENAME"

		echo -e "Backup completed $BACKUP_DEST/$first_period/$ARCHIVE_FILENAME\n"

		# Long listing of files in $BACKUP_DEST to check file sizes.
		ls -lh $BACKUP_DEST/$first_period/$ARCHIVE_FILENAME
	fi

}

# Runs the given command
# @param command    Command: backup, rotate
run_command() {
  if [[ "${1}" == "" ]]; then
    log "Can not run empty command"
    exit 1
  fi
  case "$1" in
    'backup')
      backup_process
      ;;
    'rotate')
      rotate_process
      ;;
  esac
}

# Parse given options and set global variables
parse_opts() {
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      '-h'|'--help')
        display_help
        exit 0
        ;;
	'--')
        shift
        break
        ;;
      *)
        echo "Unknown option: $1"
        display_help
        exit 1
        ;;
     esac
  done

  # remaining args, check for command
  ARGC=$#
  if [ $ARGC -lt 1 ]; then
    echo "Command missing (backup, rotate)"
    display_help
    exit 1
  fi

  COMMAND=$1
  case "$COMMAND" in
	'backup')
	# none checking
	;;
        'rotate')
	# none checking
      	;;
    	*)
	      	echo "Unknown command: $COMMAND"
	      	display_help
	      	exit 1
      	;;
  esac
}

main() {
	am_i_root
	parse_opts 

	checking
	run_command ${COMMAND}
}

main
