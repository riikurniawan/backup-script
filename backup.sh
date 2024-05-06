#!/usr/bin/bash

# destination of backup directory
dest="$HOME/backup"

# list of source files for 
source_files=$HOME/.backup-config.yaml

# create archive filename.
curr_date=$(date +%A)
hostname=$(hostname -s)
archive_filename="$hostname-$curr_date.tgz"


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
  		exit 1
	fi
}

# checking backup destination dir
check_dest_dir() {
	if [[ ! -d $dest ]]; then
		echo "Directory destination $dest DOES NOT EXISTS!!"
		echo "Creating directory $dest ..."
		sleep 2
		mkdir $dest
	fi
}

# checking before backup process
checking() {
	check_config_file
	check_dest_dir
}

# backup process
backup_process() {
	backup_files=( $(yq .files $source_files) )

	for file in $(yq .files $source_files); do
		echo "Processing file: $file"
	done
	exit

	# Print start status message.
	echo "Backing up ...."
	date
	echo
	    
	# Backup the files using tar.
	tar -czf "$dest/$archive_filename" "${backup_files[0]}"
	    
	# Print end status message.
	echo
	echo "Backup completed $dest/$archive_filename"
	date
	    
	# Long listing of files in $dest to check file sizes.
	ls -lh $dest
}


checking
backup_process
