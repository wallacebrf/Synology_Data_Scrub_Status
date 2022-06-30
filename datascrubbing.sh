#!/bin/bash

email_address="email@domain.com"
from_email_address="from@domain.com"
email_subject="Server Data Scrubbing Status"
counter=0
lock_file="/volume1/web/logging/notifications/data_scrubbing.lock"
log_file="/volume1/web/logging/notifications/file_scrubbing_status.txt"
number_installed_BTRFS_volumes=2

#create a lock file in the ramdisk directory to prevent more than one instance of this script from executing  at once
if ! mkdir $lock_file; then
	echo "Failed to acquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf $lock_file' EXIT #remove the lockdir on exit


#setup email notification details in beginning of file (from, to, and subject lines) so we can send the results of the script to an email address 
echo "from: $from_email_address " > $log_file
echo "to: $email_address " >> $log_file
echo "subject: $email_subject " >> $log_file
echo "" >> $log_file

#verify MailPlus Server package is installed and running as the "sendmail" command is not installed in synology by default. the MailPlus Server package is required
install_check=$(/usr/syno/bin/synopkg list | grep MailPlus-Server)

if [ "$install_check" = "" ];then
	echo "WARNING!  ----   MailPlus Server NOT is installed, cannot send email notifications"  >> $log_file
	exit
else
	#echo "MailPlus Server is installed, verify it is running and not stopped"
	status=$(/usr/syno/bin/synopkg is_onoff "MailPlus-Server")
	if [ "$status" = "package MailPlus-Server is turned on" ]; then
		echo "MailPlus Server is installed and running"  >> $log_file
		echo "" >> $log_file
		echo "" >> $log_file
	else
		echo "WARNING!  ----   MailPlus Server NOT is running, cannot send email notifications" >> $log_file
		exit
	fi
fi


for (( c=1; c<=$number_installed_BTRFS_volumes; c++ ))
do 
   OUTPUT=$(btrfs scrub status -d /volume$c)
	SUB='running'

	if [[ "$OUTPUT" == *"$SUB"* ]]; then
	  let counter=counter+1
	  echo "BTRFS Scrubbing Status of /Volume$c: " >> $log_file
	  echo "" >> $log_file
	  echo "${OUTPUT}" >> $log_file
	  echo "______________________________________________" >> $log_file
	  echo "" >> $log_file
	else
		echo "No BTRFS Data Scrubbing Currently In Progress on /Volume$c" >> $log_file
		echo "" >> $log_file
		echo "${OUTPUT}" >> $log_file
		echo "______________________________________________" >> $log_file
		echo "" >> $log_file
	fi
done



OUTPUT=$(cat /proc/mdstat)
SUB='resync'

if [[ "$OUTPUT" == *"$SUB"* ]]; then
  let counter=counter+1
  echo "RAID Scrubbing is active on one or more volumes" >> $log_file
  echo "RAID Scrubbing Status is: " >> $log_file
  echo "" >> $log_file
  echo "${OUTPUT}" >> $log_file
  echo "______________________________________________" >> $log_file
  echo "" >> $log_file
else
	echo "No RAID Data Scrubbing Currently In Progress" >> $log_file
	echo "" >> $log_file
	echo "${OUTPUT}" >> $log_file
	echo "______________________________________________" >> $log_file
	echo "" >> $log_file
fi

if [ $counter -ne 0 ]
then
	#send an email with the results of the script 
	cat $log_file | sendmail -t
fi
