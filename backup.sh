#!/usr/bin/bash

###################################################################

#                    CONFIGURATION SECTION                        #

###################################################################

# destination of backup directory
backup_dest="/root/backups"

# list of source files for 
source_files="/root/.backup-config.yaml"

# create archive filename.
now=$(date +'%F_%H-%M-%S')
hostname=$(hostname -s)
archive_filename="${hostname}_${now}.tar.gz"

# log files
log_filename="/root/$hostname-backup.log"


rotate_process() {
	# set maximum backups per period
	max_backups=5
	
	# period directory
	daily_dir="${backup_dest}/daily"
	weekly_dir="${backup_dest}/weekly"
	monthly_dir="${backup_dest}/monthly"
	yearly_dir="${backup_dest}/yearly"


	daily_timestamp=86400
	weekly_timestamp=604800
	monthly_timestamp=2678400

	file_timestamp=0
	target_period_dir=""

	for file in "${backup_dest}"/*; do
		if [ -f "${file}" ]; then
			file_timestamp=$(date +%s -r "${file}")
			
			age=$((file_timestamp - $(date +%s)))

			if [ $age -gt $daily_timestamp ]; then
				target_period_dir="${daily_dir}"
		        elif [ $age -gt $weekly_timestamp ]; then
		            	target_period_dir="${weekly_dir}"
		        elif [ $age -gt $monthly_timestamp ]; then
		            	target_period_dir="${monthly_dir}"
		        else
		            	target_period_dir="${yearly_dir}"
		        fi

			if [ -n "${target_period_dir}" ] && [ "${target_period_dir}" != "${backup_dest}" ]; then
				mv "${file}" "${target_period_dir}"
			fi			

		fi
	done 
	
	file_timestamp=0
	target_period_dir=""
	
	# Iterate through backup directories
	for dir in "${daily_dir}" "${weekly_dir}" "${monthly_dir}" "${yearly_dir}"; do
	    if [ -d "${dir}" ]; then
	        # Process each file in the directory
	        for file in "${dir}"/*; do
	            if [ -f "${file}" ]; then
	                # Extract file timestamp from filename
			file_timestamp=$(date +%s -r "${file}")
	
	                # Calculate time delta between file timestamp and last backup time
			age=$((file_timestamp - $(date +%s)))
	
			if [ $age -gt $daily_timestamp ]; then
				target_period_dir="${daily_dir}"
		        elif [ $age -gt $weekly_timestamp ]; then
		            	target_period_dir="${weekly_dir}"
		        elif [ $age -gt $monthly_timestamp ]; then
		            	target_period_dir="${monthly_dir}"
		        else
		            	target_period_dir="${yearly_dir}"
		        fi

			if [ -n "${target_period_dir}" ] && [ "${target_period_dir}" != "${backup_dest}" ]; then
				mv "${file}" "${target_period_dir}"
			fi			


	            fi
	        done
	
	        # Remove old backup files if exceeding maximum limit
	        cd "${dir}"
	        for file in $(ls -t | sort -r); do
	            if [ $(ls -1 | wc -l) -gt ${max_backups} ]; then
	                rm -f "${file}"
	            fi
	        done
	    fi
	done
}
rotate_process
exit

# display help
display_help() {
	echo -e "\nUsage:
	backup.sh [-h]
	backup.sh backup 
	backup.sh rotate
	
	Backup or rotate files backups.
	
	Commands
	  backup      		backup the files, directory or database from the given config file 
	  rotate		rotate all backup files (daily, weekly, monthly)
	
	Option:
	  -h, --help		display this help
	  "
}

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
	if [[ ! -d $backup_dest ]]; then
		echo "Directory destination $backup_dest DOES NOT EXIST!!"
		log "info" "Directory destination $backup_dest DOES NOT EXISTS!!"

		echo "Creating directory $backup_dest ..."
		log "info" "Creating directory $backup_dest"
		mkdir $backup_dest
		sleep 2

		echo "Creating directory ${backup_dest}/daily"
		log "info" "Creating directory ${backup_dest}/daily"
		sleep 1
		echo "Creating directory ${backup_dest}/weekly"
		log "info" "Creating directory ${backup_dest}/weekly"
		sleep 1
		echo "Creating directory ${backup_dest}/monthly"
		log "info" "Creating directory ${backup_dest}/monthly"
		sleep 1
		echo "Creating directory ${backup_dest}/yearly"
		log "info" "Creating directory ${backup_dest}/yearly"
		mkdir $backup_dest/{daily,weekly,monthly,yearly}
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

	backup_files=$(yq ".files[]" $source_files)
	backup_dirs=$(yq ".directories[]" $source_files)
	backup_db=$(yq ".databases | keys | .[]" $source_files)
	
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
	tar_output=$(tar -czf $backup_dest/$archive_filename $list_files $list_dirs -C /tmp $list_db 2>&1)

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
	if [[ -f $backup_dest/$archive_filename ]]; then
        	log "success" "Backup completed $backup_dest/$archive_filename"

		echo -e "Backup completed $backup_dest/$archive_filename\n"

		# Long listing of files in $backup_dest to check file sizes.
		ls -lh $backup_dest/$archive_filename
	fi

}

checking
backup_process
