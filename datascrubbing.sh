#!/bin/bash
version="2.9 5/15/2023"
#By Brian Wallace

##############################################################
#CREDITS
##############################################################
#credit for the floating point math here: https://phoenixnap.com/kb/bash-math
#credit for progress bar: Author : Teddy Skarin #https://github.com/fearside/ProgressBar/blob/master/progressbar.sh
#credit for the function to display total time in a nice format: user: Stéphane Gimenez  https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
#credit for the date_diff function: https://www.linuxjournal.com/content/doing-date-math-command-line-part-i

##############################################################
#Change History:
##############################################################
#2.9 -  removed "no_csum" BTRFS status. this is not an actual error, but will be non-zero due to 1.) folders or files with checksums NOT enabled, or BTRFS free space cache that is by default no checksumed. 
#2.8 -	added ability to force the script to display resyncing status of "unsupported" arrays like RAID1, RAID0, and RAID10. This is useful if an unsupported array is being created or repaired
#2.71-	corrected typo in minimum RAID array quantity for "no raid devices found" to be triggered
#2.7 -	added handling of no BTRFS volumes or no RAID devices 
#
#2.6 -	small tweaks, added additional code comments, better wording and formatting of output text
#		script now prints out version within the logs and emails
#		corrected BTRFS scrub percentage calculation. was incorrectly using total volume size, when it should have used the "Used" space of the volume
#
#2.5 - 	fixed an error created in version 2.4 that caused percent calculations to not work correctly during BTRFS scrubs
#2.4 -	added ability for script to handle the situation where a BTRFS volume has never performed a scrub process before. this can happen if the volume was just created. 
#		added ability for script to recognize if RAID array does not support scrubbing (raid 0, raid1, or raid10) and act accordingly 
#		added ability for script to recognize if RAID array is repairing, degraded, or recovering and act accordingly 
#		
#2.3 -	corrected issue with the tracking of BTRFS scrubs that complete in less than 1 hour
#
#2.2 -  moved the BTRFS scrubbing code to before the RAID scrubbing so it is printed first as Synology scrubbing always does BTRFS scrubbing before RAID scrubbing
#		added code to the BTRFS section to determine when the last BTRFS scsrub finished if that particular volume is not active
#		calculate the difference in time since that BTRFS volume was scrubbed
#			this is to assist the script in tracking BTRFS scrubs if the volume's scrub took less than 1 hour to complete.
#			if there is little data (less than a TB) or on an SSD, BTRFS scrubbing can finish fairly quickly. 
#			without this, the script's overall scrub process calculation does not work properly since it would otherwise fail to detect the BTRFS volume scrub.
#		for volumes with inactive BTRFS scrubs, details from the previously completed scrub is now displayed as well. 
#		mdraid status will include RAID type
#		mdraid status will include warnings if the raid status is not "clean" for example if the array is degraded, etc
#			example: WARNING, RAID ARRAY "md2" STATUS ERROR - STATUS IS: "clean, degraded"
#		updated the formatting for the overall progress bar
#
# 2.1 - corrected the "overall" progress bar to properly show up in emails as the " |& tee -a "$log_file_location/$log_file_name"" was missed on the progress bar line
#
# 2.0 - complete rewrite of script to make output more user friendly and add BTRFS % complete, overall scrub $ complete, overall scrub run time and more


##############################################################
#USER VARIABLES
##############################################################
to_email_address="email@email.com"
from_email_address="email@email.com"
subject="Nas Name - Disk Scrubbing Status"
use_mail_plus=1
log_file_location="/volume1/web/logging/notifications"
log_file_name="disk_scrubbing_log.txt"
email_content_file_name="disk_scrubbing_email.txt"
enable_email_notifications=1

#if a user is creating a new volume [RAID0, RAID1, RAID10] and wishes to see the resyncing status, enable this setting (to a value of 1) to allow to see the percentage complete
#otherwise this script will not display the status if the array is a RAID0, RAID1, RAID10 etc as those are not part of the normally scheduled data scrubs DSM performs
#ensure that when the array resync and creation process is complete, this value is changed back to the default value of 0 (zero) as BTRFS scrubbing details will not be collected during future scrubs
force_sync_status_display=0


##############################################################
#SCRIPT START
##############################################################

#check that the script is running as root or some of the commands required will not work
if [[ $( whoami ) != "root" ]]; then
	echo -e "ERROR - Script requires ROOT permissions, exiting script" |& tee -a "$log_file_location/$log_file_name" 
	exit 1
fi

#create a lock file to prevent more than one instance of this script from executing  at once
if ! mkdir "$log_file_location/data_scrubbing2.lock"; then
	echo "Failed to acquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf $log_file_location/data_scrubbing2.lock' EXIT #remove the lockdir on exit

RAID_scrub_active=0
BTRFS_scrub_active=0
scrub_complete=0
scrub_percent=0
raid_repairing=0
percent_scrubbed=0
num_btrfs_volumes=0
num_raid_devices=0
unsupported_raid_devices=0

#FUNCTION TO SEND EMAILS. If Synology Mail Plus Server is not installed or used, ensure the variable "use_mail_plus" is set to "0" to use the ssmtp command. 
#the ssmtp command uses the same email server settings as the Synology System Notification settings.
#NOTE: the ssmtp command requires the Synology system Notification settings to use "custom SMTP server" settings and does not work properly with gmail. It may work, but may have errors. 
#I personally recommend using SMTP2GO which has a free level that can send 1,000 emails per month. 
function send_email(){
	#to_email_address=${1}
	#from_email_address=${2}
	#log_file_location=${3}
	#log_file_name=${4}
	#subject=${5}
	#mail_body_file_location=${6}
	#use_ssmtp (value =0) or use mail plus server (value =1) ${7}

	if [ -r "${6}" ]; then
		#file is available and readable, read in the email body contents saved from the rest of the script
		mail_body=""
		while IFS= read -r line; do 
			mail_body=$mail_body"$line\n"
		done < ${6}
	else
		echo "cannot read in mailbody file \"${6}\", cannot send emails" |& tee -a "$log_file_location/$log_file_name"
		exit 1
	fi

	if [[ "${3}" == "" || "${4}" == "" || "${7}" == "" ]];then
		echo "Incorrect data was passed to the \"send_email\" function, cannot send email" |& tee -a "$log_file_location/$log_file_name"
		exit 1
	else
		if [ -d "${3}" ]; then #make sure directory exists
			if [ -w "${3}" ]; then #make sure directory is writable 
				if [ -r "${3}" ]; then #make sure directory is readable 
					local now=$(date +"%c")
					echo "To: ${1} " > ${3}/${4}
					echo "From: ${2} " >> ${3}/${4}
					echo "Subject: ${5}" >> ${3}/${4}
					#echo "" >> ${3}/${4}
					echo -e "\n$now\n$mail_body\n" >> ${3}/${4}
													
					if [[ "${1}" == "" || "${2}" == "" || "${5}" == "" ]];then
						echo -e "\n\nOne or more email address parameters [to, from, subject, mail_body] was not supplied, Cannot send an email" |& tee -a "$log_file_location/$log_file_name"
						exit 1
					else
						if [ ${7} -eq 1 ]; then #use Synology Mail Plus server "sendmail" command
						
							#verify MailPlus Server package is installed and running as the "sendmail" command is not installed in synology by default. the MailPlus Server package is required
							local install_check=$(/usr/syno/bin/synopkg list | grep MailPlus-Server)

							if [ "$install_check" = "" ];then
								echo "WARNING!  ----   MailPlus Server NOT is installed, cannot send email notifications" |& tee -a "$log_file_location/$log_file_name"
								exit 1
							else
								local status=$(/usr/syno/bin/synopkg is_onoff "MailPlus-Server")
								if [ "$status" = "package MailPlus-Server is turned on" ]; then
									local email_response=$(sendmail -t < ${3}/${4}  2>&1)
									if [[ "$email_response" == "" ]]; then
										echo -e "\nEmail Sent Successfully" |& tee -a ${3}/${4}
									else
										echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee ${3}/${4}
										exit 1
									fi					
								else
									echo "WARNING!  ----   MailPlus Server NOT is running, cannot send email notifications" |& tee -a "$log_file_location/$log_file_name"
									exit 1
								fi
							fi
						elif [ ${7} -eq 0 ]; then #use "ssmtp" command
							if ! command -v ssmtp &> /dev/null #verify the ssmtp command is available 
							then
								echo "Cannot Send Email as command \"ssmtp\" was not found" |& tee -a "$log_file_location/$log_file_name"
								exit 1
							else
								local email_response=$(ssmtp ${1} < ${3}/${4}  2>&1)
								if [[ "$email_response" == "" ]]; then
									echo -e "\nEmail Sent Successfully" |& tee -a ${3}/${4}
								else
									echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee ${3}/${4}
									exit 1
								fi	
							fi
						else 
							echo "Incorrect parameters supplied, cannot send email" |& tee ${3}/${4}
							exit 1
						fi
					fi
				else
					echo "cannot send email as directory \"${3}\" does not have READ permissions" |& tee -a "$log_file_location/$log_file_name"
					exit 1
				fi
			else
				echo "cannot send email as directory \"${3}\" does not have WRITE permissions" |& tee -a "$log_file_location/$log_file_name"
				exit 1
			fi
		else
			echo "cannot send email as directory \"${3}\" does not exist" |& tee -a "$log_file_location/$log_file_name"
			exit 1
		fi
	fi
}

function date_diff(){
	#credit: https://www.linuxjournal.com/content/doing-date-math-command-line-part-i
	local start_date=${1}
	local end_date=${2}
	local sdate=$(date --date="$start_date" '+%s')
	local edate=$(date --date="$end_date"   '+%s')
	local days=$(( (edate - sdate) / 86400 ))
	echo "$days"
}

function time_diff(){
	local old=${1}
	local new=${2}
	local old_hour=0
	local old_min=0
	local old_sec=0
	local hour=0
	local min=0
	local sec=0

	IFS=: read old_hour old_min old_sec <<< "$old"
	IFS=: read hour min sec <<< "$new"

	# convert the date "1970-01-01 hour:min:00" in seconds from Unix EPOCH time
	local sec_old=$(date -d "1970-01-01 $old_hour:$old_min:00" +%s)
	local sec_new=$(date -d "1970-01-01 $hour:$min:00" +%s)

	echo "$(( (sec_new - sec_old) / 60))"
}

echo "Script Version: $version" |& tee "$log_file_location/$log_file_name" #create the file and remove any previous data

###############################################
#getting list of mdraid devices
###############################################
raid_device=$(mdadm --query --detail /dev/md* | grep /dev/md)
raid_device=(`echo $raid_device | sed 's/:/\n/g'`) #make an array of the results delineated by a :
num_raid_devices=${#raid_device[@]}


###############################################
#getting list of BTRFS volumes
###############################################
btrfs_volumes=$(btrfs filesystem show | grep /dev*)
	#split the data into an array
	SAVEIFS=$IFS   # Save current IFS (Internal Field Separator)
	IFS=$'\n'      # Change IFS to newline char
	btrfs_volumes=($btrfs_volumes) # split the `names` string into an array by the same name
	IFS=$SAVEIFS   # Restore original IFS

num_btrfs_volumes=${#btrfs_volumes[@]}

###############################################
#process the status of the different BTRFS devices on the system
###############################################
xx=0
echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
echo -e "BTRFS SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
if [ $force_sync_status_display -eq 1 ]; then
	echo -e "The option to force Sync Status Display has been chosen, this is used if an array has just been created and email status is desired.\nNote BTRFS scrubbing is not performed during this time.\n" |& tee -a "$log_file_location/$log_file_name"
else
	if [ $num_btrfs_volumes -lt 1 ]; then
		echo -e "No BTRFS Volumes found, BTRFS scrubbing will be skipped \n" |& tee -a "$log_file_location/$log_file_name"
	else
		for xx in "${!btrfs_volumes[@]}"; do

			no_stats_available=0 #initialize variable. if the BTRFS volume has never previously undergone a SCRUB, then the results from the "btrfs scrub status" command will be different. we need to capture this so the script can act accordingly. 

			#need to convert the "/dev/mapper/cachedev_x" device name to a volume name like "/volume1"
			volume_number=$(df | grep ${btrfs_volumes[$xx]#*path })
			#returns: /dev/mapper/cachedev_0   14981718344  5599142460  9382575884  38% /volume1
			volume_number=${volume_number#*% } #only keep everything after the "% " to keep only volume number
			
				
			volume_details=$(btrfs scrub status -d -R ${btrfs_volumes[$xx]#*path }) #get BTRFS status details
			#returns
			#	scrub status for f5a143bd-194e-47c7-83e5-df58e039f5b3
			#	scrub device /dev/mapper/cachedev_0 (id 1) history
			#	scrub started at Sat Mar 25 09:33:05 2023 running for 03:20:03
			#	data_extents_scrubbed: 87493561
			#	tree_extents_scrubbed: 715450
			#	data_bytes_scrubbed: 5733378027520
			#	tree_bytes_scrubbed: 11721932800
			#	read_errors: 0
			#	csum_errors: 0
			#	verify_errors: 0
			#	no_csum: 0
			#	csum_discards: 0
			#	super_errors: 0
			#	malloc_errors: 0
			#	uncorrectable_errors: 0
			#	unverified_errors: 0
			#	corrected_errors: 0
			#	last_physical: 5764018077696
			
			volume_check=$(echo $volume_details | grep "no stats available") #if the volume has just been made and has not performed a scrub yet, then "no stats available" will be displayed
			if [[ $volume_check != "" ]]; then
				no_stats_available=1
			fi
			volume_details=$(echo $volume_details | grep -E -A 2 "started at" | grep "running for") #search the BTRFS status for the word "running for" as that is only present if scrubbing is active
			if [[ $volume_details == "" ]]; then
			
				echo -n "\"$volume_number\" is not performing BTRFS scrubbing --> last " |& tee -a "$log_file_location/$log_file_name"
				
				#let's extract when the scrub started if it has already finished or aborted. if the volume is on an SSD or has little data on it, the BTRFS scrub might finish in less than 1 hour
				#we need to see if that occurred, so we can add the completed BTRFS volume to our overall scrub complete percentage tracker since the script is meant to run once per hour
				volume_details=$(btrfs scrub status -d -R $volume_number | grep "after") 
				#returns: scrub started at Fri Mar 31 16:27:25 2023 and finished after 00:12:57
				#or
				#returns  scrub started at Fri Mar 31 16:27:25 2023 and aborted after 00:12:57
				if [ $no_stats_available -eq 1 ]; then
					echo -e "scrub has never been performed.\n\n" |& tee -a "$log_file_location/$log_file_name"
					#let num_btrfs_volumes=num_btrfs_volumes-1
				else
					echo -n "${volume_details#*scrub }"  |& tee -a "$log_file_location/$log_file_name"
					explode=(`echo $volume_details | sed 's/ /\n/g'`) #explode on white space
					#returns 
					#	0: scrub
					#	1: started
					#	2: at
					#	3: Fri
					#	4: Mar
					#	5: 31
					#	6: 16:40:22
					#	7: 2023
					#	8: and
					#	9: finished / aborted
					#	10: after
					#	11: 00:17:25
					
					date_diff_value=$(date_diff "${explode[4]} ${explode[5]} ${explode[7]}" "$(date "+%b") $(date "+%d") $(date "+%Y")") #calculate the number of days between the current date and when the volume finished
					time_diff_value=$(time_diff "${explode[6]}" "$(date "+%T")") #calculate the number of minuets between the current date and when the volume finished
							
					volume_details=$(btrfs scrub status -d -R $volume_number | grep "error")
					explode=(`echo $volume_details | sed 's/ /\n/g'`) #explode on white space
					#returns the following array
					#	0: read_errors: 
					#	1: 0
					#	2: csum_errors: 
					#	3: 0
					#	4: verify_errors: 
					#	5: 0
					#	6: super_errors: 
					#	7: 0
					#	8: malloc_errors: 
					#	9: 0
					#	10: uncorrectable_errors: 
					#	11: 0
					#	12: unverified_errors: 
					#	13: 0
					#	14: corrected_errors: 
					#	15: 0
					
					if [ "${explode[1]}" = 0 ] && [ "${explode[3]}" = 0 ] && [ "${explode[5]}" = 0 ] && [ "${explode[7]}" = 0 ] && [ "${explode[9]}" = 0 ] && [ "${explode[11]}" = 0 ] && [ "${explode[13]}" = 0 ] && [ "${explode[15]}" = 0 ]; then
						echo -e " --> Errors: 0\n\n\n" |& tee -a "$log_file_location/$log_file_name"
					else
						echo "     --> One or more errors occurred during the last scrubbing, see details below:" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Read Errors: ${explode[1]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> cSUM Errors: ${explode[3]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Verify Errors: ${explode[5]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Super Errors: ${explode[7]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Malloc Errors: ${explode[9]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Un-correctable Errors: ${explode[11]}" |& tee -a "$log_file_location/$log_file_name"
						echo "     --> Unverified Errors: ${explode[13]}" |& tee -a "$log_file_location/$log_file_name"
						echo -e "     --> Corrected Errors: ${explode[15]}\n\n\n" |& tee -a "$log_file_location/$log_file_name"
					fi

					if [ $date_diff_value -le 1 ]; then #make sure the last scrub was was done less than or equal to 1 day (1 rather than 0 in case the day rolls over at midnight)
						
						if [ $time_diff_value -le 61 ]; then #if the volume finished 61 or fewer minuets ago. since script is run every hour this will catch any scrubs that finished really fast between executions of this script every hour
							
							#to keep track of number of previously completed scrub tasks completed, we will track the device names that have already been seen by the script
							#check if the tracking file exists, if it does read in the contents, otherwise set a default state and create the file
							if [ -r "$log_file_location/script_percent_tracking.txt" ]; then  #the file will only exist if a scrub is still active
								read script_percent_tracking < "$log_file_location/script_percent_tracking.txt"

								#determine if the current scrubbing device has already been detected in a previous execution of the script
								if [[ "$script_percent_tracking" != *"$volume_number"* ]]; then
									#if the current scrubbing device is not in the log, add it. the comma at the end will be used to count the number of completed items later. 
									echo -n ",$volume_number" >> "$log_file_location/script_percent_tracking.txt"
									script_percent_tracking=$script_percent_tracking",$volume_number"
								fi
							else
								echo -n "$volume_number" > "$log_file_location/script_percent_tracking.txt"
								script_percent_tracking=$script_percent_tracking"$volume_number"
							fi
						fi
					fi
				fi
				
			else
				BTRFS_scrub_active=1
				
				#to keep track of number of previously completed scrub tasks completed, we will track the device names that have already been seen by the script
				#check if the tracking file exists, if it does read in the contents, otherwise set a default state and create the file
				if [ -r "$log_file_location/script_percent_tracking.txt" ]; then 
					read script_percent_tracking < "$log_file_location/script_percent_tracking.txt"
				else
					echo -n "$volume_number" > "$log_file_location/script_percent_tracking.txt"
					script_percent_tracking="$volume_number"
				fi
				
				
				#determine if the current scrubbing device has already been detected in a previous execution of the script
				if [[ "$script_percent_tracking" != *"$volume_number"* ]]; then
					#if the current scrubbing device is not in the log, add it. the comma at the end will be used to count the number of completed items later. 
					echo -n ",$volume_number" >> "$log_file_location/script_percent_tracking.txt"
					script_percent_tracking=$script_percent_tracking",$volume_number"
				fi
				scrub_complete=$(echo "${script_percent_tracking}" | awk -F"," '{print NF-1}') #count the number of commas minus 1 to see how many devices have previously completed their scrubbing. since the current device is not yet complete, we will subtract its presence in the log. 
				
					
				explode=(`echo $volume_details | sed 's/ /\n/g'`) #explode the scrubbing status on white spaces and creates an array with the following items
				#returns
				#	0.) scrub
				#	1.) status
				#	2.) for
				#	3.) f5a143bd-194e-47c7-83e5-df58e039f5b3
				#	4.) scrub
				#	5.) device
				#	6.) /dev/mapper/cachedev_0
				#	7.) (id
				#	8.) 1)
				#	9.) history
				#	10.) scrub
				#	11.) started
				#	12.) at
				#	13.) Sat
				#	14.) Mar
				#	15.) 25
				#	16.) 09:33:05
				#	17.) 2023
				#	18.) running 
				#	19.) for 
				#	20.) 03:20:03
				#	21.) data_extents_scrubbed:
				#	22.) 87493561
				#	23.) tree_extents_scrubbed:
				#	24.) 715450
				#	25.) data_bytes_scrubbed:
				#	26.) 5733378027520
				#	27.) tree_bytes_scrubbed:
				#	28.) 11721932800
				#	29.) read_errors:
				#	30.) 0
				#	31.) csum_errors:
				#	32.) 0
				#	33.) verify_errors:
				#	34.) 0
				#	35.) no_csum:
				#	36.) 0
				#	37.) csum_discards:
				#	38.) 0
				#	39.) super_errors:
				#	40.) 0
				#	41.) malloc_errors:
				#	42.) 0
				#	43.) uncorrectable_errors:
				#	44.) 0
				#	45.) unverified_errors:
				#	46.) 0
				#	47.) corrected_errors:
				#	48.) 0
				#	49.) last_physical:
				#	50.) 5764018077696
							
				date_started="${explode[13]} ${explode[14]} ${explode[15]} ${explode[17]} ${explode[16]}"
				run_time=${explode[20]}
				amount_scrubbed=${explode[26]}
				device_name=${explode[6]}
				read_errors=${explode[30]}
				csum_errors=${explode[32]}
				verify_errors=${explode[34]}
				#nocsum_errors=${explode[36]}
				csum_discards=${explode[38]}
				super_errors=${explode[40]}
				malloc_errors=${explode[42]}
				uncorrectable_errors=${explode[44]}
				unverifed_errors=${explode[46]}
				corrected_errors=${explode[48]}
						
				echo -e "\"$volume_number\" BTRFS scrubbing Active.\n\n" |& tee -a "$log_file_location/$log_file_name"
				
				volume_size=$(btrfs filesystem usage -b $volume_number | grep -m1 "Used:" | xargs) #for the current volume, get BTRFS volume details, and only return the used space of the volume
				#returns "Used: 29338076205056" for example
				volume_size=${volume_size#*Used: } #remove the "Used: " beginning text so we have just the number
				percent_scrubbed=$(printf %.2f "$((10**3 * $amount_scrubbed/$volume_size))e-1")	

				echo "BTRFS Scrubbing Date Started: $date_started" |& tee -a "$log_file_location/$log_file_name"
				echo "BTRFS Scrubbing Duration:  $run_time" |& tee -a "$log_file_location/$log_file_name"
				echo "BTRFS Scrubbing Device Name:  $device_name" |& tee -a "$log_file_location/$log_file_name"
				echo "BTRFS Scrubbing Data Scrubbed [Bytes]:  $amount_scrubbed" |& tee -a "$log_file_location/$log_file_name"
				echo "BTRFS Scrubbing Volume Used Space [Bytes]:  $volume_size" |& tee -a "$log_file_location/$log_file_name"
				echo "BTRFS Scrubbing Percent Complete:  $percent_scrubbed%" |& tee -a "$log_file_location/$log_file_name"
								
				#do we have any errors? if there are no errors, show that, if there are errors then print the detailed error information 
				if [ "$read_errors" = 0 ] && [ "$csum_errors" = 0 ] && [ "$verify_errors" = 0 ] && [ "$csum_discards" = 0 ] && [ "$super_errors" = 0 ] && [ "$malloc_errors" = 0 ] && [ "$uncorrectable_errors" = 0 ] && [ "$unverifed_errors" = 0 ] && [ "$corrected_errors" = 0 ]; then
					echo -e "BTRFS Scrubbing Errors: 0\n\n" |& tee -a "$log_file_location/$log_file_name"
				else
					echo "One or more errors have occurred during scrubbing, see details below:" |& tee -a "$log_file_location/$log_file_name"
					echo "--> Read Errors: $read_errors" |& tee -a "$log_file_location/$log_file_name"
					echo "--> cSUM Errors: $csum_errors" |& tee -a "$log_file_location/$log_file_name"
					echo "--> Verify Errors: $verify_errors" |& tee -a "$log_file_location/$log_file_name"
					#echo "--> nocSUM Errors: $nocsum_errors" |& tee -a "$log_file_location/$log_file_name"
					echo "--> cSUM Discards: $csum_discards" |& tee -a "$log_file_location/$log_file_name"
					echo "--> Super Errors: $super_errors" |& tee -a "$log_file_location/$log_file_name"
					echo "--> Malloc Errors: $malloc_errors" |& tee -a "$log_file_location/$log_file_name"
					echo "--> Un-correctable Errors: $uncorrectable_errors" |& tee -a "$log_file_location/$log_file_name"
					echo -e "--> Corrected Errors: $corrected_errors\n\n" |& tee -a "$log_file_location/$log_file_name"
				fi
				
				if [ $scrub_complete -eq 0 ];then
					script_percent_tracking=${script_percent_tracking/%$volume_number}
				else
					script_percent_tracking=${script_percent_tracking/%,$volume_number}
				fi
			fi
		done
	fi
fi


###############################################
#process the status of the different RAID devices on the system
###############################################
xx=0
echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
echo -e "RAID SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
if [ $num_raid_devices -lt 3 ]; then
	echo -e "No RAID devices found, RAID scrubbing will be skipped \n" |& tee -a "$log_file_location/$log_file_name"
else
	for xx in "${!raid_device[@]}"; do
		if [[ ${raid_device[$xx]} != "/dev/md0" && ${raid_device[$xx]} != "/dev/md1" ]]; then #on a Synology system, these are system level partitions for DSM and cache, they are not part of data scrubbing and so will be skipped. 
			
			skip_device=0
			raid_type=$(mdadm --detail ${raid_device[$xx]} | grep "Raid Level")
			#returns for example: "Raid Level : raid5"
			
			if [ $force_sync_status_display -eq 1 ]; then #if a user is creating a new volume and wishes to see the resyncing status, enable this setting to allow to see the percentage complete
				skip_device=0
			else
				if [[ ${raid_type#*Raid Level : } == "raid1" || ${raid_type#*Raid Level : } == "raid0" || ${raid_type#*Raid Level : } == "raid10" ]]; then
					echo -e "RAID device \"${raid_device[$xx]#*/dev/}\" [ Raid Type: ${raid_type#*Raid Level : } ] does not support RAID scrubbing and will be skipped.\n\n" |& tee -a "$log_file_location/$log_file_name"
					let unsupported_raid_devices=unsupported_raid_devices+1 #remove the device from the number of RAID devices that will be scrubbed to ensure the percentage calculation is correct. 
					skip_device=1
				fi
			fi
			
			if [ $skip_device -eq 0 ]; then
				
				#Synology only support scrubbing of RAID5 and RAID6 and RAIDF1 partitions. Even when using SHR1/SHR2, the system behind the scenes uses combinations of RAID5/6 and RAID0/1 to make the most use of the available disk space. The RAID0/1 partitions are not processed when DSM scrubs an SHR1/SHR2 volume, only the RAID5/6 parts are. 
				
				raid_state=$(mdadm --detail ${raid_device[$xx]} | grep "State :") #get the state because if the state is degraded or recovering, then BTRFS scrubbing is not going to occur, and so we can skip BTRFS details when calculating overall progress percentage at the end of this script. 
				#returns for example: "State : clean"
				raid_state=${raid_state#*State : } #removes everything but the actual status
				
				if [[ $(echo "$raid_state" | grep "degraded") != "" || $(echo "$raid_state" | grep "recovering") != "" || $(echo "$raid_state" | grep "crashed") != "" ]]; then
					raid_repairing=1 #if we are degraded/recovering, this is not a normal scrub it is probably due to array just being made or the array rebuilding, so the system will not be focusing on BTRFS, so lets skip BTRFS volumes
					echo -n "${raid_device[$xx]#*/dev/}" > "$log_file_location/script_percent_tracking.txt"
					script_percent_tracking="${raid_device[$xx]#*/dev/}"
					echo -e "WARNING, RAID ARRAY \"${raid_device[$xx]#*/dev/}\" STATUS IS: \"${raid_state^^}\"\n\n" |& tee -a "$log_file_location/$log_file_name"
				fi
				
				volume_details=$(grep -E -A 2 ${raid_device[$xx]#*/dev/} /proc/mdstat | grep "finish=") #get mdRAID status, and search for the text "finish=" which is only found if a scrub is active
				#returns  "[===============>.....]  resync = 77.8% (6078469488/7803302208) finish=165.8min speed=173334K/sec"
				
				if [[ $volume_details == "" ]]; then #if no scrubbing is active, then the grep commands will return no text
					echo -e "RAID device \"${raid_device[$xx]#*/dev/}\" [ Raid Type: ${raid_type#*Raid Level : } ] is not performing RAID scrubbing\n\n" |& tee -a "$log_file_location/$log_file_name"
				else
					RAID_scrub_active=1
					
					#to keep track of number of previously completed scrub tasks completed, we will track the device names that have already been seen by the script
					#check if the tracking file exists, if it does read in the contents, otherwise set a default state and create the file
					if [ -r "$log_file_location/script_percent_tracking.txt" ]; then 
						read script_percent_tracking < "$log_file_location/script_percent_tracking.txt"
					else
						echo -n "${raid_device[$xx]#*/dev/}" > "$log_file_location/script_percent_tracking.txt"
						script_percent_tracking="${raid_device[$xx]#*/dev/}"
					fi
					
					
					#determine if the current scrubbing device has already been detected in a previous execution of the script
					if [[ "$script_percent_tracking" != *"${raid_device[$xx]#*/dev/}"* ]]; then
						#if the current scrubbing device is not in the log, add it. the comma at the end will be used to count the number of completed items later. 
						echo -n ",${raid_device[$xx]#*/dev/}" >> "$log_file_location/script_percent_tracking.txt"
						script_percent_tracking=$script_percent_tracking",${raid_device[$xx]#*/dev/}"
					fi
					
					scrub_complete=$(echo "${script_percent_tracking}" | awk -F"," '{print NF-1}') #count the number of commas minus 1 to see how many devices have previously completed their scrubbing. 
					
					
					explode=(`echo $volume_details | sed 's/)/\n/g'`) #explode on the string
					#returns 7x items in an array
					#	0.)"[===============>.....]"
					#	1.)"resync"
					#	2.)"=" 
					#	3.)"78.3%"
					#	4.)"(6117200640/7803302208"
					#	5.)"finish=168.5min"
					#	6.)"speed=166748K/sec"
					explode2=(`echo ${explode[5]} | sed 's/=/\n/g'`) #take smaller portion of the exploded string "finish=168.5min" and explode on "=" to extract the "finish" time
					#returns two items in an array
					#	0.)"finish"
					#	1.)"168.5min"
					explode3=(`echo ${explode[6]} | sed 's/=/\n/g'`) #take smaller portion of the exploded string "speed=166748K/sec" and explode on "=" to extract the "speed"
					#returns two items in an array
					#	0.)"speed"
					#	1.)"166748K/sec"
					
					percent_bar=${explode[0]}
					percent=${explode[3]}
					blocks=${explode[4]}
					finish=${explode2[1]}
					speed=${explode3[1]}

					if [ $force_sync_status_display -eq 1 ];then
					echo -e "RAID device \"${raid_device[$xx]#*/dev/}\" [ Raid Type: ${raid_type#*Raid Level : } ] Re-Syncing Active. NOTE: This is not a normal scrub but is an unsupported [RAID0, RAID1, or RAID10] array either being created or repaired\n\n" |& tee -a "$log_file_location/$log_file_name"
					else
						echo -e "RAID device \"${raid_device[$xx]#*/dev/}\" [ Raid Type: ${raid_type#*Raid Level : } ] scrubbing Active.\n\n" |& tee -a "$log_file_location/$log_file_name"
					fi
					echo "RAID Scrubbing Progress: $percent_bar $percent" |& tee -a "$log_file_location/$log_file_name"
					echo "RAID Scrubbing Blocks Processed: $blocks)" |& tee -a "$log_file_location/$log_file_name"
					echo "RAID Scrubbing Estimated Time Remaining: $finish" |& tee -a "$log_file_location/$log_file_name"
					echo -e "RAID Scrubbing Processing Speed: $speed\n\n" |& tee -a "$log_file_location/$log_file_name"
					
					if [ $scrub_complete -eq 0 ];then
						script_percent_tracking=${script_percent_tracking/%${raid_device[$xx]#*/dev/}} #remove the current device from the list as it is still in progress and has not completed. 
					else
						script_percent_tracking=${script_percent_tracking/%,${raid_device[$xx]#*/dev/}} #remove the current device from the list as it is still in progress and has not completed. 
					fi
				fi	
			fi
			
		fi
	done
fi

function displaytime {
#credit: https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
#user: Stéphane Gimenez
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

function ProgressBar {
#function Author : Teddy Skarin
#https://github.com/fearside/ProgressBar/blob/master/progressbar.sh
# Process data
	let _progress=(${1}*100/${2}*100)/100
	let _done=(${_progress}*4)/10
	let _left=40-$_done
# Build progressbar string lengths
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")

printf "\r\nOverall Scrub Percent: [${_done// /=}${_left// /.}] ${_progress}%%"

}

if [[ $RAID_scrub_active == 1 || $BTRFS_scrub_active == 1 ]]; then
	
	if [ -r "$log_file_location/data_scrubbing_start_time.txt" ]; then
	
		#read in the unit time stamp from when the script first detected scrubbing was active. 
		#the scheduled task to run this script needs to be run 1 minuet later than the start time of the scrubbing for accurate timing
		current_time=$( date +%s )
		read input_read < "$log_file_location/data_scrubbing_start_time.txt"
		input_read=$(( $current_time - $input_read ))
		let input_read=input_read+60 #the scheduled task to run this script needs to be run 1 minuet later than the start time of the scrubbing for accurate timing
		
		runtime=$(displaytime $input_read) #use the "displaytime" function 
	else	
		current_time=$( date +%s )
		echo -n "$current_time" > $log_file_location/data_scrubbing_start_time.txt
		runtime=$(displaytime 60) #the scheduled task to run this script needs to be run 1 minuet later than the start time of the scrubbing for accurate timing
	fi
	
	echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
	echo -e "OVERALL SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
	echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
	
	if [ $raid_repairing -eq 0 ]; then #if we are not degraded or repairing the storage pool, then lets calculate the BTRFS and RAID scrubbing percentage
	
		if [[ $RAID_scrub_active == 1 ]]; then
			#calculate the total scrubbing complete process. 
			scrub_percent=$(printf %.0f "$((10**3 * $scrub_complete/$(( $num_btrfs_volumes + $num_raid_devices - 2 - $unsupported_raid_devices ))))e-1") #divide number of devices that have completed scrubbing by total number of devices that require scrubbing
			percent_scrubbed=$(printf %.0f "$((10**3 * ${percent%???}/$(( $num_btrfs_volumes + $num_raid_devices - 2 - $unsupported_raid_devices ))))e-3") #divide the currently scrubbing device's % complete as reported by mdraid and divide by total number of devices that require scrubbing
			percent_scrubbed=$(( $scrub_percent + $percent_scrubbed )) #add two calculations together
		elif [[ $BTRFS_scrub_active == 1 ]]; then
			#calculate the total scrubbing complete process.
			scrub_percent=$(printf %.0f "$((10**3 * $scrub_complete/$(( $num_btrfs_volumes + $num_raid_devices - 2 - $unsupported_raid_devices ))))e-1")
			percent_scrubbed=$(printf %.0f "$((10**3 * ${percent_scrubbed%???}/$(( $num_btrfs_volumes + $num_raid_devices - 2 - $unsupported_raid_devices ))))e-3")
			percent_scrubbed=$(( $percent_scrubbed + $scrub_percent ))
		fi	
	
		if [ $force_sync_status_display -eq 0 ]; then
			echo "Number of RAID Devices [Supporting Scrubbing]: $(( $num_raid_devices - 2 - $unsupported_raid_devices ))" |& tee -a "$log_file_location/$log_file_name"
			echo "Number of BTRFS Devices [Requiring Scrubbing]: $num_btrfs_volumes" |& tee -a "$log_file_location/$log_file_name"
			echo "Total Scrubbing Tasks Required: $(( $num_btrfs_volumes + $num_raid_devices - 2 - $unsupported_raid_devices ))" |& tee -a "$log_file_location/$log_file_name"
			echo "Scrub Processes Complete: $scrub_complete"  |& tee -a "$log_file_location/$log_file_name"
			if [[ "$script_percent_tracking" == "" ]]; then
				echo "Devices Completed: NONE" |& tee -a "$log_file_location/$log_file_name"
			else
				echo "Devices Completed: $script_percent_tracking" |& tee -a "$log_file_location/$log_file_name"
			fi
			
			ProgressBar ${percent_scrubbed} 100 |& tee -a "$log_file_location/$log_file_name"
		else
			echo -e "The option to force Sync Status Display has been chosen, this is used if an array has just been created and email status is desired.\nNote BTRFS scrubbing is not performed during this time." |& tee -a "$log_file_location/$log_file_name"
			ProgressBar ${percent%???} 100 |& tee -a "$log_file_location/$log_file_name"
		fi
	else
		#if we are degraded or repairing, no BTRFS scrubbing will occur, so we only need to calculate the percentage of completion for the item being repair. 
		echo "RAID is either recovering or repairing. Until this is complete normal scrubbing cannot occur and BTRFS scrubbing will be skipped" |& tee -a "$log_file_location/$log_file_name"
		ProgressBar ${percent%???} 100 |& tee -a "$log_file_location/$log_file_name"
	fi
	echo -e "\nTotal Scrubbing Runtime: $runtime" |& tee -a "$log_file_location/$log_file_name"

	if [ $enable_email_notifications -eq 1 ]; then
		send_email "$to_email_address" "$from_email_address" "$log_file_location" "$email_content_file_name" "$subject" "$log_file_location/$log_file_name" $use_mail_plus
	fi
else
	if [ -f "$log_file_location/data_scrubbing_start_time.txt" ]; then
		rm "$log_file_location/data_scrubbing_start_time.txt"
	fi
	if [ -f "$log_file_location/script_percent_tracking.txt" ]; then
		rm "$log_file_location/script_percent_tracking.txt"
	fi
fi
