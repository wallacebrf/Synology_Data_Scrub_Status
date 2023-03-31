<div id="top"></div>
<!--
*** comments....
-->



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/wallacebrf/Synology_Data_Scrub_Status">
    <img src="https://raw.githubusercontent.com/wallacebrf/Synology_Data_Scrub_Status/main/images/scrubby_tout.png" alt="Logo" width="180" height="207">
  </a>

<h3 align="center">Synology Data Scrubbing (Raid Sync and BTRFS Scrubbing) + Email Notifications on Status</h3>

  <p align="center">
    This project is comprised of a shell script that is configured in Synology Task Scheduler to run once per hour. The script performs commands to determine the RAID syncing status and BTRFS file system scrubbing status. If the status is active an email is sent with that current status
    <br />
    <a href="https://github.com/wallacebrf/Synology_Data_Scrub_Status"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/wallacebrf/Synology_Data_Scrub_Status/issues">Report Bug</a>
    ·
    <a href="https://github.com/wallacebrf/Synology_Data_Scrub_Status/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#About_the_project_Details">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Road map</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
### About_the_project_Details

The script searches for all mdRAID devices and all BTRFS devices on a Synology system. It will then loop through all of those devices to determine if any are actively scrubbing. If active scrubbing is found, all of the pertinent data is extracted and presented to the user. 

An email with the status of scrubbing is only sent if scrubbing is active. The email will contain the following information:

1.) Total scrub time between all devices

2.) Total scrub percentage between all devices

3.) What devices have completed scrubbing

4.) Scrub percentage for the device actively scrubbing

5.) details from the RAID or BTRFS scrubbing status commands


```
########################################
#EXAMPLE SCRIPT OUTPUTS
########################################


#########################################
#	No Active Scrubbing
#	one storage pool, RAID5, with one volume
########################################
	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" is not performing RAID scrubbing


	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	/volume1 is not performing BTRFS scrubbing


#########################################
#	BTRFS scrubbing before performing MD RAID scrubbing. 
#	one storage pool, RAID5, with one volume
########################################
	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" is not performing RAID scrubbing


	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume1" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Fri Mar 31 2023, 08:21:04
	BTRFS Scrubbing Duration:  00:21:49
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_0
	BTRFS Scrubbing Data Scrubbed [Bytes]:  652282064896
	BTRFS Scrubbing Volume Size [Bytes]:  15980499566592
	BTRFS Scrubbing Percent Complete:  4.00%
	BTRFS Scrubbing Errors: 0


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices: 1
	Number of BTRFS Devices: 1
	Total Scrubbing Tasks Required: 2
	Scrub Processes Complete: 0
	Devices Completed: NONE

	Overall Scrub Percent: [----------------------------------------] 2%
	Total Scrubbing Runtime: 22 minutes and 39 seconds
#########################################
#	MD RAID scrubbing after completing BTRFS scrubbing. 
#	one storage pool, RAID5, with one volume
########################################
	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------
	
	md2 RAID scrubbing Active.


	RAID Scrubbing Progress: [===============>.....] 76.2%
	RAID Scrubbing Blocks Processed: (5951230848/7803302208)
	RAID Scrubbing Estimated Time Remaining: 181.1min
	RAID Scrubbing Processing Speed: 170439K/sec


	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	/volume1 is not performing BTRFS scrubbing


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices: 1
	Number of BTRFS Devices: 1
	Total Scrubbing Tasks Required: 2
	Scrub Processes Complete: 1
	Devices Completed: /volume1

	Overall Scrub Percent: [###################################-----] 88%
	Total Scrubbing Runtime: 11 hours 1 minutes and 4 seconds

```

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

This project is written around a Synology NAS, however the BTRFS and RAID commands can work on other systems. 

### Prerequisites

For email notifications:

This project requires EITHER  Synology Mail Plus Server to be installed and running

OR

This project requires that Synology's ```Control Panel --> Notifications``` SMTP server settings are properly configured. 

The user can choose which email notification service is preferred. It is recommended to use Mail Plus server. Mail Plus server performs a queue if the email fails to send, it will try again later, where the ```Control Panel --> Notifications``` option will not unless the script executes again. You also get a benefit in Mail Plus Server that you can see a history of all the emails sent if you wish to see any of those logs.

### Installation

The script can be downloaded and placed in any shared folder desired on the Synology NAS

the script has the following configuration parameters

```
to_email_address="email@email.com"
from_email_address="email@email.com"
subject="NAS Name - Disk Scrubbing Status"
use_mail_plus=0
log_file_location="/volume1/web/logging/notifications"
log_file_name="disk_scrubbing_log.txt"
email_content_file_name="disk_scrubbing_email.txt"
enable_email_notifications=1
```

The first three lines control to whom the notification email will be sent, who the email is sent from, and what the email's title will be. 

The next line ```use_mail_plus``` controls if MailPlus server will be used. Set to "1" to use Mail Plus server. If set to "0" the Synology System Level SMTP server will be used instead. 

The next line ```log_file_location``` is a directory where log files and temp files will be stored while the script is running while ```log_file_name``` will be the name of the log file. 

The next line ```email_content_file_name``` is file name for the contents which will be emailed out. 

The final line ```enable_email_notifications``` allows to disable email notifications entirely. This is not recommended as the status script will not be able to notify you. This can be useful in testing and debugging however. 



Once the script is on the NAS, go to Control Panel --> Task Scheduler

Click on Create --> Scheduled Task --> User-defined_script

In the new window, name the script something useful like "Data Scrubbing Status" and set user to root

Go to the schedule tab, and at the bottom, change the "Frequency" to "every hour" and change the "first time run" to "00:01" and "last time run" to "23:01". Note: The extra minute waiting time is required as the scheduled scrubbing task starts at "00:00" this will ensure the scrubbing has already started before the script is executed. 

Go to the "Task Settings" tab. in the "user defined script" area at the bottom enter ```bash %PATH_TO_SCRIPT%/datascrubbing.sh``` for example. Ensure the path is the path to where the file was placed on the NAS. 

Click OK. 

To verify the script works, selecting the scheduled task and hitting "Run" will force the script to operate. If debugging is needed, adding an email address to the "Task Settings" tab can allow Task Scheduler to send an email with the results of the script execution. 




<!-- CONTRIBUTING -->
## Contributing

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- LICENSE -->
## License

This is free to use code, use as you wish

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Your Name - Brian Wallace - wallacebrf@hotmail.com

Project Link: [https://github.com/wallacebrf/Synology_Data_Scrub_Status)

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

credit for the floating point math here: https://phoenixnap.com/kb/bash-math

credit for progress bar: Author : Teddy Skarin #https://github.com/fearside/ProgressBar/blob/master/progressbar.sh

credit for the function to display total time in a nice format: user: Stéphane Gimenez  https://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds


<p align="right">(<a href="#top">back to top</a>)</p>
