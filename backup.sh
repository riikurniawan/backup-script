#!/usr/bin/bash

###################################################################

#                    CONFIGURATION SECTION                        #

###################################################################

# destination of backup directory
dest="/root/backup"

# list of source files for 
source_files="/root/.backup-config.yaml"

# create archive filename.
curr_date=$(date +'%F_%H-%M-%S')
hostname=$(hostname -s)
archive_filename="$hostname-$curr_date.tar.gz"

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

#                          databases_dump()                       #

###################################################################

# database dump process
databases_dump() {
	local type=$1
	local username=$2
	local password=$3
	local db=$4
	local dbport=$5
}


###################################################################

#                          backup_process()                       #

###################################################################

# backup process
backup_process() {
	backup_files=$(yq .files $source_files)
	backup_dir=$(yq .directories $source_files)
	backup_dir=$(yq .databases $source_files)
	
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

	# Print start status message.
	echo -e "\nBacking up ...."
	date
	echo

	# Backup the files using tar.
	tar_output=$(tar -czf $dest/$archive_filename $list_files $list_dirs 2>&1)

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
