#!/usr/bin/bash
## Usage: backup.sh [options] ARG1
##
## Options:
##   -h, --help    Display this message.
##   -n            Dry-run; only show what would be done.
##

# destination of backup directory
dest="/root/backup"

# list of source files for 
source_files="/root/.backup-config.yaml"

# create archive filename.
curr_date=$(date +'%F')
hostname=$(hostname -s)
archive_filename="$hostname-$curr_date.tgz"

# log files
log_filename="/root/$hostname-backup.log"

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

# is script run as root
am_i_root() {
	if [[ `id -u` -ne 0 ]]; then
		echo "Please run this script as root or using sudo!" >&2
		exit 1
	fi
}

# checking config file
check_config_file() {
	if [[ ! -f "$source_files" ]]; then
  		echo "$source_files DOES NOT EXIST!!" >&2
		log "error" "$source_files DOES NOT EXIST!!"
  		exit 1
	fi
}

# checking backup destination dir
check_dest_dir() {
	if [[ ! -d $dest ]]; then
		echo "Directory destination $dest DOES NOT EXIST!!"
		echo "Creating directory $dest ..."
		sleep 2
		mkdir $dest
	fi
}

# checking before backup process
checking() {
	am_i_root
	check_config_file
	check_dest_dir
}

# backup process
backup_process() {
	backup_files=$(yq .files $source_files)
	backup_dir=$(yq .directories $source_files)
	
	list_files=""
	list_dirs=""

	# loop all files then check file is exists
	for file in $(yq .files[] $source_files); do
		echo "Checking file: $file"
		sleep 1
		
		# if file not found send error to log 
		if [[ ! -f "$file" ]]; then 
			echo "File Not Found!!"
			log "error" "File: $file NOT FOUND!!"
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
			log "error" "Directory: $dir NOT FOUND!!"
		else
			list_dirs+="$dir/ "
		fi
	done

	# Print start status message.
	echo -e "\nBacking up ...."
	date
	echo
	    
	# Backup the files using tar.
	tar -czfP $dest/$archive_filename $list_files $list_dirs 
	    
	# Print end status message.
	echo
	if [[ -f $dest/$archive_filename ]]; then
		echo -e "Backup completed $dest/$archive_filename\n"

		# Long listing of files in $dest to check file sizes.
		ls -lh $dest/$archive_filename
	fi
}

checking
backup_process
