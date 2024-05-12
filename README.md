# Backup Script

a shell script to create backups such as files, directories, and databases MySQL based on the given configuration.

## Requirement

This script need some tools and services to run properly

- [yq](https://github.com/mikefarah/yq) parse yaml file.
- [tar](https://www.gnu.org/software/tar/) an archiving utility
- [gzip](https://www.gnu.org/software/gzip/) compress & decompress files
- [MySQL](https://www.mysql.com/) (optional) if you want backup database.

## Features

- Backup configuration with yaml file so you can easily read.
- Backup MySQL databases
- Rotate backup files (daily, weekly, monthly, yearly) and keep that file to the amount specified.
- Logging.

## Installation

`Note:` <b>This script must running as root user !</b>

Clone this repo `https://github.com/riikurniawan/backup-script.git`

```bash
git clone https://github.com/riikurniawan/backup-script.git
```

Open directory `backup-script` and then copy file `backup-config.example.yaml` to home directory `root` user `/root/.backup-config.yaml`.

```bash
cd backup-script \
cp backup-config.example.yaml /root/.backup-config.yaml
```

and then edit configuration file `/root/.backup-config.yaml`.

Here is example configuration you `Must Specified!`

```yaml
files:
  - "/etc/ssh/sshd_config"
  - ...
directories:
  - "/var/log"
  - ...
databases:
  sekolahdb: #required
    type: mysql #required (for now it just only mysql)
    username: root #required
    password: root #required
    port: 3307 #optional (if you use a non-standard mysql service port)
```

## Help

Run `./backup.sh -h | --help` it will show the help

```
Usage:
	backup.sh [options] [commands]
	backup.sh backup
	backup.sh rotate

	Backup or rotate files backups.

	Commands
	  backup      		backup the files, directory or database from the given config file
	  rotate		rotate all backup files (daily, weekly, monthly, yearly)

	Options:
	  -h, --help		display this help

```

## Usage

Create backup you just type command

```bash
./backup.sh backup
```

After backup process done, the backup files will create directory `backups` at `/root/backups` and four subdirectories `daily weekly monthly yearly`.

The filename format is `<hostname>_<y-m-d>_<h-m-s>.tar.gz`.
<br>For example: `workstation_2024-04-21_14-30-00.tar.gz`.

Rotate backup files just type like this

```
./backup.sh rotate
```

The backup files will rotate if the file has been saved for some time.

The rotation like this.

```
Example current date: 2024-05-12

File created: workstation_2024-04-21_14-30-00.tar.gz # this file has been create 21 days ago.

When you running ./backup.sh rotate.

That file will rotate from daily directory to weekly directory.

daily/ -> weekly/workstation_2024-04-21_14-30-00.tar.gz
```

> So when backup files will rotate if i runing this command ?

| Period  | Time period at seconds       | Time will rotate |
| ------- | ---------------------------- | ---------------- |
| Daily   | 86400 (60 \* 60 \* 24)       | 14 day           |
| Weekly  | 604800 (7 \* 60 \* 60 \* 24) | 4 week           |
| Monthly | 2419200 (28 \* 60 \* 24)     | 12 month         |
| Yearly  | 31536000 (365 \* 60 \* 24)   | 1 year           |

## Logfile

If you want to check what going on this scriptwhile running. log file it's stored at `/root/<hostname>-backup.log`.

# Thanks to

- [Ubuntu: How to backup using shell scripts](https://ubuntu.com/server/docs/how-to-back-up-using-shell-scripts)
- [Ubuntu: Archive rotation shell script](https://ubuntu.com/server/docs/archive-rotation-shell-script)
- [gzachos: Backup Script](https://github.com/gzachos/backup-script/)
- [mitosch: Bashcup - A backup bash script](https://github.com/mitosch/bashcup)
- [Tony Teaches Tech: Easy rsync Backup with tar and cron (daily, weekly, monthly)](https://www.youtube.com/watch?v=z35ZPELo5_Y&t=1187s)
