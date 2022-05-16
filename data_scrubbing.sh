#!/bin/bash

#create a lock file in the ramdisk directory to prevent more than one instance of this script from executing  at once
if ! mkdir /volume1/web/logging/notifications/data_scrubbing.lock; then
	echo "Failed to aquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf /volume1/web/logging/notifications/data_scrubbing.lock' EXIT #remove the lockdir on exit

email_address="email@email.com.com"
from_email_address="email@email.com.com"
counter=0

#setup email notification details in beginning of file (from, to, and subject lines) so we can send the results of the script to an email address 
echo "from: $from_email_address " > /volume1/web/logging/notifications/file_scrubbing_status.txt
echo "to: $email_address " >> /volume1/web/logging/notifications/file_scrubbing_status.txt
echo "subject: Server2 Data Scrubbing Status " >> /volume1/web/logging/notifications/file_scrubbing_status.txt
echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt


OUTPUT=$(btrfs scrub status -d /volume2)
SUB='running'

if [[ "$OUTPUT" == *"$SUB"* ]]; then
  let counter=counter+1
  echo "BTRFS Scrubbing Status of /Volume2: " >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
else
	echo "No BTRFS Data Scrubbing Currently In Progress on /Volume2" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
fi


OUTPUT=$(btrfs scrub status -d /volume1)
SUB='running'

if [[ "$OUTPUT" == *"$SUB"* ]]; then
  let counter=counter+1
  echo "BTRFS Scrubbing Status of /Volume1: " >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
else
	echo "No BTRFS Data Scrubbing Currently In Progress on /Volume1" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
fi

OUTPUT=$(cat /proc/mdstat)
SUB='resync'

if [[ "$OUTPUT" == *"$SUB"* ]]; then
  let counter=counter+1
  echo "RAID Scrubbing is active on one or more volumes" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "RAID Scrubbing Status is: " >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
  echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
else
	echo "No RAID Data Scrubbing Currently In Progress on /Volume1, /Volume2" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "${OUTPUT}" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "______________________________________________" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
	echo "" >> /volume1/web/logging/notifications/file_scrubbing_status.txt
fi

if [ $counter -ne 0 ]
then
	#send an email with the results of the script 
	cat /volume1/web/logging/notifications/file_scrubbing_status.txt | sendmail -t
fi
