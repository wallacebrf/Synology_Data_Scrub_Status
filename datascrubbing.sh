#!/bin/bash
#Version 2.0 3/31/2023
#By Brian Wallace
#credit for the floating point math here: https://phoenixnap.com/kb/bash-math
#credit for progress bar: Author : Teddy Skarin #https://github.com/fearside/ProgressBar/blob/master/progressbar.sh
#credit for the function to display total time in a nice format: user: Stéphane Gimenez  https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds


##############################################################
#USER VARIABLES
##############################################################
to_email_address="email@email.com"
from_email_address="email@email.com"
subject="NAS Name - Disk Scrubbing Status"
use_mail_plus=0
log_file_location="/volume1/web/logging/notifications"
log_file_name="disk_scrubbing_log.txt"
email_content_file_name="disk_scrubbing_email.txt"
enable_email_notifications=1


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

scrub_active=0
scrub_complete=0
scrub_percent=0

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
					local now=$(date +"%T")
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

echo "" |& tee "$log_file_location/$log_file_name" #create the file and remove any previous data

###############################################
#getting list of mdraid devices
###############################################
raid_device=$(mdadm --query --detail /dev/md* | grep /dev/md)
raid_device=(`echo $raid_device | sed 's/:/\n/g'`) #make an array of the results delineated by a :


###############################################
#getting list of BTRFS volumes
###############################################
btrfs_volumes=$(btrfs filesystem show | grep /dev*)
	#split the data into an array
	SAVEIFS=$IFS   # Save current IFS (Internal Field Separator)
	IFS=$'\n'      # Change IFS to newline char
	btrfs_volumes=($btrfs_volumes) # split the `names` string into an array by the same name
	IFS=$SAVEIFS   # Restore original IFS


###############################################
#process the status of the different RAID devices on the system
###############################################
xx=0
echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
echo -e "RAID SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
for xx in "${!raid_device[@]}"; do
	if [[ ${raid_device[$xx]} != "/dev/md0" && ${raid_device[$xx]} != "/dev/md1" ]]; then
		
		volume_details=$(grep -E -A 2 ${raid_device[$xx]#*/dev/} /proc/mdstat | grep "finish=") #get mdRAID status, and search for the text "finish=" which is only found if a scrub is active
		#returns  "[===============>.....]  resync = 77.8% (6078469488/7803302208) finish=165.8min speed=173334K/sec"
		
		if [[ $volume_details == "" ]]; then #if no scrubbing is active, then the grep commands will return no text
			echo -e "RAID device \"${raid_device[$xx]#*/dev/}\" is not performing RAID scrubbing\n\n" |& tee -a "$log_file_location/$log_file_name"
		else
			scrub_active=1
			
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

			echo -e "${raid_device[$xx]#*/dev/} RAID scrubbing Active.\n\n" |& tee -a "$log_file_location/$log_file_name"
			echo "RAID Scrubbing Progress: $percent_bar $percent" |& tee -a "$log_file_location/$log_file_name"
			echo "RAID Scrubbing Blocks Processed: $blocks)" |& tee -a "$log_file_location/$log_file_name"
			echo "RAID Scrubbing Estimated Time Remaining: $finish" |& tee -a "$log_file_location/$log_file_name"
			echo -e "RAID Scrubbing Processing Speed: $speed\n\n" |& tee -a "$log_file_location/$log_file_name"
			
			
			#calculate the total scrubbing complete process. 
			scrub_percent=$(printf %.0f "$((10**3 * $scrub_complete/$(( ${#btrfs_volumes[@]} + ${#raid_device[@]} -2 ))))e-1") #divide number of devices that have completed scrubbing by total number of devices that require scrubbing
			percent_scrubbed=$(printf %.0f "$((10**3 * ${percent%???}/$(( ${#btrfs_volumes[@]} + ${#raid_device[@]} -2 ))))e-3") #divide the currently scrubbing device's % complete as reported by mdraid and divide by total number of devices that require scrubbing
			percent_scrubbed=$(( $scrub_percent + $percent_scrubbed )) #add two calculations together
			if [ $scrub_complete -eq 0 ];then
				script_percent_tracking=${script_percent_tracking/%${raid_device[$xx]#*/dev/}} #remove the current device from the list as it is still in progress and has not completed. 
			else
				script_percent_tracking=${script_percent_tracking/%,${raid_device[$xx]#*/dev/}} #remove the current device from the list as it is still in progress and has not completed. 
			fi
		fi	
	fi
done


###############################################
#process the status of the different BTRFS devices on the system
###############################################
xx=0
echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
echo -e "BTRFS SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
for xx in "${!btrfs_volumes[@]}"; do
	#need to convert the /dev/mapper/cachedev_x to a volume name
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
	volume_details=$(echo $volume_details | grep -E -A 2 "started at" | grep "running for") #search the BTRFS status for the word "running for" as that is only present if scrubbing is active
	if [[ $volume_details == "" ]]; then
		echo -e "\"$volume_number\" is not performing BTRFS scrubbing\n\n" |& tee -a "$log_file_location/$log_file_name"
	else
		scrub_active=1
		
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
		scrub_complete=$(echo "${script_percent_tracking}" | awk -F"," '{print NF-1}') #count the number of commas minus 1 to see how many devices have previously completed their scrubbing. 
		
			
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
		nocsum_errors=${explode[36]}
		csum_discards=${explode[38]}
		super_errors=${explode[40]}
		malloc_errors=${explode[42]}
		uncorrectable_errors=${explode[44]}
		unverifed_errors=${explode[46]}
		corrected_errors=${explode[48]}
				
		echo -e "\"$volume_number\" BTRFS scrubbing Active.\n\n" |& tee -a "$log_file_location/$log_file_name"
		
		volume_size=$(btrfs filesystem usage -b $volume_number | grep "Device size:" | cut -c 23-) #for the current volume, get BTRFS volume details, and only return the size of the volume
		percent_scrubbed=$(printf %.2f "$((10**3 * $amount_scrubbed/$volume_size))e-1")	
		echo "BTRFS Scrubbing Date Started: $date_started" |& tee -a "$log_file_location/$log_file_name"
		echo "BTRFS Scrubbing Duration:  $run_time" |& tee -a "$log_file_location/$log_file_name"
		echo "BTRFS Scrubbing Device Name:  $device_name" |& tee -a "$log_file_location/$log_file_name"
		echo "BTRFS Scrubbing Data Scrubbed [Bytes]:  $amount_scrubbed" |& tee -a "$log_file_location/$log_file_name"
		echo "BTRFS Scrubbing Volume Size [Bytes]:  $volume_size" |& tee -a "$log_file_location/$log_file_name"
		echo "BTRFS Scrubbing Percent Complete:  $percent_scrubbed%" |& tee -a "$log_file_location/$log_file_name"
						
		#do we have any errors? if there are no errors, show that, if there are errors then print the detailed error information 
		if [ "$read_errors" = 0 ] && [ "$csum_errors" = 0 ] && [ "$verify_errors" = 0 ] && [ "$nocsum_errors" = 0 ] && [ "$csum_discards" = 0 ] && [ "$super_errors" = 0 ] && [ "$malloc_errors" = 0 ] && [ "$uncorrectable_errors" = 0 ] && [ "$unverifed_errors" = 0 ] && [ "$corrected_errors" = 0 ]; then
			echo -e "BTRFS Scrubbing Errors: 0\n\n" |& tee -a "$log_file_location/$log_file_name"
		else
			echo "One or more errors have occurred during scrubbing, see details below:" |& tee -a "$log_file_location/$log_file_name"
			echo "--> Read Errors: $read_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> cSUM Errors: $csum_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> Verify Errors: $verify_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> nocSUM Errors: $nocsum_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> cSUM Discards: $csum_discards" |& tee -a "$log_file_location/$log_file_name"
			echo "--> Super Errors: $super_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> Malloc Errors: $malloc_errors" |& tee -a "$log_file_location/$log_file_name"
			echo "--> Un-correctable Errors: $uncorrectable_errors" |& tee -a "$log_file_location/$log_file_name"
			echo -e "--> Corrected Errors: $corrected_errors\n\n" |& tee -a "$log_file_location/$log_file_name"
		fi
		
		#calculate the total scrubbing complete process.
		scrub_percent=$(printf %.0f "$((10**3 * $scrub_complete/$(( ${#btrfs_volumes[@]} + ${#raid_device[@]} -2 ))))e-1")
		percent_scrubbed=$(printf %.0f "$((10**3 * ${percent_scrubbed%???}/$(( ${#btrfs_volumes[@]} + ${#raid_device[@]} -2 ))))e-3")
		percent_scrubbed=$(( $percent_scrubbed + $scrub_percent ))
		if [ $scrub_complete -eq 0 ];then
			script_percent_tracking=${script_percent_tracking/%$volume_number}
		else
			script_percent_tracking=${script_percent_tracking/%,$volume_number}
		fi
	fi
done

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

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:
# 1.2.1.1 Progress : [########################################] 100%
printf "\r\nOverall Scrub Percent: [${_done// /#}${_left// /-}] ${_progress}%%"

}

if [ $scrub_active -eq 1 ]; then
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
		echo "Scrubbing has been running for $runtime" |& tee -a "$log_file_location/$log_file_name"
	fi
	
	echo -e "---------------------------------" |& tee -a "$log_file_location/$log_file_name"
	echo -e "OVERALL SCRUBBING DETAILS" |& tee -a "$log_file_location/$log_file_name"
	echo -e "---------------------------------\n" |& tee -a "$log_file_location/$log_file_name"
	echo "Number of RAID Devices: $(( ${#raid_device[@]} -2 ))" |& tee -a "$log_file_location/$log_file_name"
	echo "Number of BTRFS Devices: ${#btrfs_volumes[@]}" |& tee -a "$log_file_location/$log_file_name"
	echo "Total Scrubbing Tasks Required: $(( ${#btrfs_volumes[@]} + ${#raid_device[@]} -2 ))" |& tee -a "$log_file_location/$log_file_name"
	echo "Scrub Processes Complete: $scrub_complete"  |& tee -a "$log_file_location/$log_file_name"
	if [[ "$script_percent_tracking" == "" ]]; then
		echo "Devices Completed: NONE"
	else
		echo "Devices Completed: $script_percent_tracking" |& tee -a "$log_file_location/$log_file_name"
	fi
	
	ProgressBar ${percent_scrubbed} 100
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


########################################
#EXAMPLE SCRIPT OUTPUTS
########################################
#
#
#########################################
#	No Active Scrubbing
#	one storage pool, RAID5, with one volume
########################################
#	---------------------------------
#	RAID SCRUBBING DETAILS
#	---------------------------------
#
#	RAID device "md2" is not performing RAID scrubbing
#
#
#	---------------------------------
#	BTRFS SCRUBBING DETAILS
#	---------------------------------
#
#	/volume1 is not performing BTRFS scrubbing
#
#
#########################################
#	BTRFS scrubbing before performing MD RAID scrubbing. 
#	one storage pool, RAID5, with one volume
########################################
#	---------------------------------
#	RAID SCRUBBING DETAILS
#	---------------------------------
#
#	RAID device "md2" is not performing RAID scrubbing
#
#
#	---------------------------------
#	BTRFS SCRUBBING DETAILS
#	---------------------------------
#
#	"/volume1" BTRFS scrubbing Active.
#
#
#	BTRFS Scrubbing Date Started: Fri Mar 31 2023, 08:21:04
#	BTRFS Scrubbing Duration:  00:21:49
#	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_0
#	BTRFS Scrubbing Data Scrubbed [Bytes]:  652282064896
#	BTRFS Scrubbing Volume Size [Bytes]:  15980499566592
#	BTRFS Scrubbing Percent Complete:  4.00%
#	BTRFS Scrubbing Errors: 0
#
#
#	---------------------------------
#	OVERALL SCRUBBING DETAILS
#	---------------------------------
#
#	Number of RAID Devices: 1
#	Number of BTRFS Devices: 1
#	Total Scrubbing Tasks Required: 2
#	Scrub Processes Complete: 0
#	Devices Completed: NONE
#
#	Overall Scrub Percent: [----------------------------------------] 2%
#	Total Scrubbing Runtime: 22 minutes and 39 seconds
#########################################
#	MD RAID scrubbing after completing BTRFS scrubbing. 
#	one storage pool, RAID5, with one volume
########################################
#		---------------------------------
#		RAID SCRUBBING DETAILS
#		---------------------------------
#	
#		md2 RAID scrubbing Active.
#
#
#		RAID Scrubbing Progress: [===============>.....] 76.2%
#		RAID Scrubbing Blocks Processed: (5951230848/7803302208)
#		RAID Scrubbing Estimated Time Remaining: 181.1min
#		RAID Scrubbing Processing Speed: 170439K/sec
#
#
#		---------------------------------
#		BTRFS SCRUBBING DETAILS
#		---------------------------------
#
#		/volume1 is not performing BTRFS scrubbing
#
#
#		---------------------------------
#		OVERALL SCRUBBING DETAILS
#		---------------------------------
#
#		Number of RAID Devices: 1
#		Number of BTRFS Devices: 1
#		Total Scrubbing Tasks Required: 2
#		Scrub Processes Complete: 1
#		Devices Completed: /volume1
#
#		Overall Scrub Percent: [###################################-----] 88%
#		Total Scrubbing Runtime: 11 hours 1 minutes and 4 seconds
