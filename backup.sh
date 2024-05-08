#!/usr/bin/bash

###################################################################

#                    CONFIGURATION SECTION                        #

###################################################################

# destination of backup directory
dest="/root/backup"

# list of source files for 
source_files="/root/.backup-config.yaml"

# create archive filename.
now=$(date +'%F_%H-%M-%S')
hostname=$(hostname -s)
archive_filename="$hostname-$now.tar.gz"

# log files
log_filename="/root/$hostname-backup.log"

###################################################################

#                          log()	                          #

###################################################################

# send output process to log file
log() {
	local status=$1
	local msg=$2
	local datetime=$(date +'%F %T')

	[[ ! -f "$log_filename" ]] && touch "$log_filename"

	case "$status" in
		"success") echo -e "[$datetime] SUCCESS: $msg" >> $log_filename
		;;
		"error") echo -e "[$datetime] ERROR: $msg" >> $log_filename
		;;	
		"warning") echo -e "[$datetime] WARNING: $msg" >> $log_filename
		;;	
		"info") echo -e "[$datetime] INFO: $msg" >> $log_filename
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
	if [[ ! -f "$source_files" ]]; then
  		echo "$source_files DOES NOT EXIST!!" >&2
		log "error" "$source_files DOES NOT EXIST!!"
  		exit 1
	fi
}

###################################################################

#                          check_dest_dir()                       #

###################################################################

# checking backup destination dir
check_dest_dir() {
	if [[ ! -d $dest ]]; then
		echo "Directory destination $dest DOES NOT EXIST!!"
		echo "Creating directory $dest ..."
		log "info" "Directory destination $dest DOES NOT EXISTS!!"
		log "info" "Creating directory $dest"
		sleep 2
		mkdir $dest
	fi
}

###################################################################

#                          checking()                         	  #

###################################################################

# checking before backup process
checking() {
	am_i_root
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

	backup_files=$(yq ".files" $source_files)
	backup_dir=$(yq ".directories" $source_files)
	backup_db=$(yq ".databases | keys | .[]" $source_files)
	
	list_files=""
	list_dirs=""
	list_db=""

	# loop all files then check file is exists
	for file in $(yq .files[] $source_files); do
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
	for dir in $(yq .directories[] $source_files); do
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
		db_type=$(yq ".databases.$db_name.type" $source_files)
		db_user=$(yq ".databases.$db_name.username" $source_files)
    		db_pass=$(yq ".databases.$db_name.password" $source_files)

		# if attr required not filled
		if [ "$db_type" == "null" ] && [ "$db_user" == "null" ] && [ "$db_pass" == "null" ]; then
			echo "Required attributed for database $db_name must filled!"
			echo "Backup for database $db_name will skipped!"
			log "warning" "Required attributed for database $db_name must filled!"
			log "info" "Backup for database $db_name will skipped!"
		fi

		# if optional attr is filled 
	   	if $(yq ".databases.$db_name | has(\"port\")" $source_files); then
			db_port=$(yq ".databases.$db_name.port" $source_files)	
		fi
		
		case $db_type in
		 "mysql") 
			# set output name after dump database
			output_sql="/tmp/${db_name}-${now}.sql.gz"

			# set mysql password to use mysqldump without password
			echo -e "[mysqldump]\npassword=$db_pass" > ~/.mylogin.cnf && chmod 600 ~/.mylogin.cnf

			# save mysql out
			mysql_output=$(mysqldump --defaults-file=~/.mylogin.cnf -u ${db_user} $db_name 2>&1 | gzip -9 > $output_sql)

			# if db_port defined, then add option -P to set the port explicitly			
			if [ "$db_port" != "null" ]; then
			    mysql_output=$(mysqldump --defaults-file=~/.mylogin.cnf -u ${db_user} -P ${db_port} $db_name 2>&1 | gzip -9 > $output_sql)
			else
			    mysql_output=$(mysqldump --defaults-file=~/.mylogin.cnf -u ${db_user} $db_name 2>&1 | gzip -9 > $output_sql)
			fi

			# check if mysqldump error then send to log
                        if [[ $? -ne 0 ]]; then
                        	log "error" "$mysql_output"
                        	log "error" "mysqldump: Exited with errors!"
                        	log "error" "Backup for database $db_name will skipped!"
                                echo "mysqldump: Exited with errors!" >&2
                                echo "Backup for database $db_name will skipped!"
                        fi	

			# append path output file to sql_files
			sql_files+="$output_sql "

			# remove default-file
			rm ~/.mylogin.cnf

			echo "Backup database succeded: $db_name"
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
	
	list_db=$(echo $list_db | xargs)

	# Backup the files using tar.
	tar_output=$(tar -czf $dest/$archive_filename $list_files $list_dirs -C /tmp $list_db  2>&1)

	# Check the exit status of the tar command
	if [[ $? -ne 0 ]]; then
		# Backup failed
		log "error" "$tar_output"

		echo "tar: Exited with errors!" >&2 
		echo "Script will exited!" >&2
		exit 1
	fi

	# Print end status message.
	echo
	if [[ -f $dest/$archive_filename ]]; then
        	log "success" "Backup completed $dest/$archive_filename"

		echo -e "Backup completed $dest/$archive_filename\n"

		# Long listing of files in $dest to check file sizes.
		ls -lh $dest/$archive_filename
	fi

}

checking
backup_process
