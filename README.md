# Synology Data Scrub Status
<a href="https://github.com/wallacebrf/Synology_Data_Scrub_Status/releases"><img src="https://img.shields.io/github/v/release/wallacebrf/Synology_Data_Scrub_Status.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fwallacebrf%2FSynology_Data_Scrub_Status&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false"/></a>

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
    This project is comprised of a shell script that is configured in Synology Task Scheduler to run once per hour. The script performs commands to determine the RAID syncing status and BTRFS file system scrubbing status. If the status is active an email is sent with that current status. The script will also send email notifications if other RAID activity is occurring such as resyncing during RAID rebuilds, RAID changes (SHR1 to SHR migrations for example), or RAID array creations. 
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

The script searches for all mdRAID devices and all BTRFS devices on a Synology system. It will then loop through all of those devices to determine if any are actively scrubbing. If active scrubbing is found (during scheduled scrubs, RAID rebuilds, or RAID type conversions), all of the pertinent data is extracted and presented to the user in an email. 

An email with the status of scrubbing is only sent if scrubbing is active. The email will contain the following information:

1.) Total scrub time elapsed between all devices

2.) Total scrub percentage between all devices

3.) What devices have completed scrubbing

4.) Scrub percentage for the device actively scrubbing

5.) details from the RAID or BTRFS scrubbing status commands


NOTE: per Synology ```Data scrubbing is only supported on BTRFS volumes or storage pools of the following RAID types: SHR (consisting of three or more drives), RAID 5, RAID 6, or RAID F1.``` 
Article here: https://kb.synology.com/en-id/DSM/help/DSM/StorageManager/storage_pool_data_scrubbing?version=7

Here is what the Scrubbing Schedule window shows for example
<img src="https://raw.githubusercontent.com/wallacebrf/Synology_Data_Scrub_Status/main/images/raid_unsupported.png" alt="Logo">

Due to this, even though many RAID configurations are available on Synology (https://kb.synology.com/en-id/DSM/help/DSM/StorageManager/storage_pool_what_is_raid?version=7), several types like RAID0, RAID1, RAID10, JOB, and finally Basic, do not support scrubbing and so will be skipped by DSM's scheduled scrubs. This script takes this into account and will mark a RAID device as unsupported, for example ```RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing```

however if a user who is utilizing RAID0 or RAID1 arrays and is either creating the array, or repairing the array, the script can be used and the configurationparamter ```force_sync_status_display=0``` can be set to a value of 1. This forces the script to send emails on the MDADM status of the arrays, but will make it ignore BTRFS scrubbing as BTRFS scrubs do not occur during array repair. 

Also note when using SHR or SHR2: Depending on the size of the different disks used in SHR, DSM will automatically create RAID5/6 (depending on SHR level) and will  create RAID1 or RAID10 elements [depending on SHR level]. For example, in a test system I have been developing this script on, I had 7.3, 10.9, and 16.4 TB drives in a 18.2 TB SHR array. DSM created this by making a RAID5 array using 7.3TB from each drive giving me 14.6TB of space. The remainder of the 18.2TB array was made by creating a RAID1 [Mirror] array using 3.6TB on the 10.9TB drive and 3.6TB on the 16.4TB drive. This resulted in a 14.6 + 3.6 = 18.2TB array. Due to this, when running this script on this particular SHR array, the script will find both the RAID5 and RAID1 arrays, but will mark the RAID1 array as unsupported due to DSM skipping it as part of scheduled scrubs. 


```
########################################
#EXAMPLE SCRIPT EMAIL NOTIFICATIONS
########################################
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
NO scrubbing
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Tue Apr  4 14:45:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" is not performing BTRFS scrubbing --> last scrub has never been performed.


	"/volume3" is not performing BTRFS scrubbing --> last scrub has never been performed.


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid5 ] is not performing RAID scrubbing


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
one volume=BTRFS
BTRFS scrubbing ACTIVE
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Tue Apr  4 14:45:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume1" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Tue Apr 4 2023, 14:33:04
	BTRFS Scrubbing Duration:  00:11:58
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_0
	BTRFS Scrubbing Data Scrubbed [Bytes]:  359718273024
	BTRFS Scrubbing Volume Used Space [Bytes]:  1811692437504
	BTRFS Scrubbing Percent Complete:  19.80%
	BTRFS Scrubbing Errors: 0


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid5 ] is not performing RAID scrubbing


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 1
	Total Scrubbing Tasks Required: 2
	Scrub Processes Complete: 0
	Devices Completed: NONE


	Overall Scrub Percent: [====....................................] 10%
	Total Scrubbing Runtime: 12 minutes and 47 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
one volume=BTRFS
BTRFS scrubbing ACTIVE and errors detected 
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Tue Apr  4 14:45:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume1" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Tue Apr 4 2023, 14:33:04
	BTRFS Scrubbing Duration:  00:11:58
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_0
	BTRFS Scrubbing Data Scrubbed [Bytes]:  359718273024
	BTRFS Scrubbing Volume Used Space [Bytes]:  1811692437504
	BTRFS Scrubbing Percent Complete:  19.80%
	One or more errors have occurred during scrubbing, see details below:
	--> Read Errors: 0
	--> cSUM Errors: 1
	--> Verify Errors: 0
	--> nocSUM Errors: 0
	--> cSUM Discards: 0
	--> Super Errors: 0
	--> Malloc Errors: 0
	--> Un-correctable Errors: 0
	--> Corrected Errors: 0


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid5 ] is not performing RAID scrubbing


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 1
	Total Scrubbing Tasks Required: 2
	Scrub Processes Complete: 0
	Devices Completed: NONE


	Overall Scrub Percent: [====....................................] 10%
	Total Scrubbing Runtime: 12 minutes and 47 seconds

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
BTRFS scrubbing ACTIVE on volume 2
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Wed 05 Apr 2023 05:29:10 AM CDT
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Wed Apr 5 2023, 05:26:18
	BTRFS Scrubbing Duration:  00:02:52
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_1
	BTRFS Scrubbing Data Scrubbed [Bytes]:  71750361088
	BTRFS Scrubbing Volume Used Space [Bytes]:  565816348672
	BTRFS Scrubbing Percent Complete:  12.60%
	BTRFS Scrubbing Errors: 0


	"/volume3" is not performing BTRFS scrubbing --> last scrub has never been performed.


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid5 ] is not performing RAID scrubbing


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 2
	Total Scrubbing Tasks Required: 3
	Scrub Processes Complete: 0
	Devices Completed: NONE


	Overall Scrub Percent: [=.......................................] 4%
	Total Scrubbing Runtime: 3 minutes and 42 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
BTRFS scrubbing ACTIVE on volume3, volume2 just finished
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Wed Apr  5 06:25:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" is not performing BTRFS scrubbing --> last started at Wed Apr  5 05:26:18 2023 and finished after 00:21:28 --> Errors: 0



	"/volume3" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Wed Apr 5 2023, 05:47:46
	BTRFS Scrubbing Duration:  00:37:16
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_2
	BTRFS Scrubbing Data Scrubbed [Bytes]:  519851212800
	BTRFS Scrubbing Volume Used Space [Bytes]:  565893648384
	BTRFS Scrubbing Percent Complete:  91.80%
	BTRFS Scrubbing Errors: 0


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid5 ] is not performing RAID scrubbing


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 2
	Total Scrubbing Tasks Required: 3
	Scrub Processes Complete: 1
	Devices Completed: /volume2


	Overall Scrub Percent: [=========================...............] 63%
	Total Scrubbing Runtime: 59 minutes and 34 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
RAID scrubbing ACTIVE on Mmd2, volume2 and volume3 finished BTRFS scrubbing
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Wed Apr  5 08:45:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" is not performing BTRFS scrubbing --> last started at Wed Apr  5 05:26:18 2023 and finished after 00:21:28 --> Errors: 0



	"/volume3" is not performing BTRFS scrubbing --> last started at Wed Apr  5 05:47:46 2023 and finished after 00:40:30 --> Errors: 0



	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	md2 [ Raid Type: raid5 ] scrubbing Active.


	RAID Scrubbing Progress: [====>................] 24.8%
	RAID Scrubbing Blocks Processed: (1942471808/7803299584)
	RAID Scrubbing Estimated Time Remaining: 412.8min
	RAID Scrubbing Processing Speed: 236581K/sec


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 2
	Total Scrubbing Tasks Required: 3
	Scrub Processes Complete: 2
	Devices Completed: /volume2,/volume3


	Overall Scrub Percent: [==============================..........] 75%
	Total Scrubbing Runtime: 3 hours 19 minutes and 33 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
RAID scrubbing ACTIVE on Mmd2, volume2 and volume3 finished BTRFS scrubbing. errors were found during BTRFS scrubbing
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Wed Apr  5 08:45:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" is not performing BTRFS scrubbing --> last started at Wed Apr  5 05:26:18 2023 and finished after 00:21:28 --> One or more errors have occurred during scrubbing, see details below:
	 --> Read Errors: 0
	 --> cSUM Errors: 0
	 --> Verify Errors: 0
	 --> Super Errors: 0
	 --> Malloc Errors: 0
	 --> Un-correctable Errors: 0
	 --> Unverified Errors: 0
	 --> Corrected Errors: 0



	"/volume3" is not performing BTRFS scrubbing --> last started at Wed Apr  5 05:47:46 2023 and finished after 00:40:30 --> Errors: 0



	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	md2 [ Raid Type: raid5 ] scrubbing Active.


	RAID Scrubbing Progress: [====>................] 24.8%
	RAID Scrubbing Blocks Processed: (1942471808/7803299584)
	RAID Scrubbing Estimated Time Remaining: 412.8min
	RAID Scrubbing Processing Speed: 236581K/sec


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 1
	Number of BTRFS Devices [Requiring Scrubbing]: 2
	Total Scrubbing Tasks Required: 3
	Scrub Processes Complete: 2
	Devices Completed: /volume2,/volume3


	Overall Scrub Percent: [==============================..........] 75%
	Total Scrubbing Runtime: 3 hours 19 minutes and 33 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SHR array, 3x drives
one storage pool
three volumes
	volume1=EXT4
	volume2=BTRFS
	volume3=BTRFS
RAID array repairing after drive replacement 
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Thu Apr  6 16:00:02 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume2" is not performing BTRFS scrubbing --> last started at Wed Apr  5 14:01:30 2023 and finished after 00:21:23 --> Errors: 0



	"/volume3" is not performing BTRFS scrubbing --> last started at Wed Apr  5 14:22:53 2023 and finished after 00:40:20 --> Errors: 0



	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	WARNING, RAID ARRAY "md2" STATUS IS: "CLEAN, DEGRADED, RECOVERING "


	md2 [ Raid Type: raid5 ] scrubbing Active.


	RAID Scrubbing Progress: [======>..............] 34.8%
	RAID Scrubbing Blocks Processed: (2716621056/7803299584)
	RAID Scrubbing Estimated Time Remaining: 417.6min
	RAID Scrubbing Processing Speed: 202993K/sec


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	RAID is either recovering or repairing. Until this is complete normal scrubbing cannot occur and BTRFS scrubbing will be skipped


	Overall Scrub Percent: [=============...........................] 34%
	Total Scrubbing Runtime: 3 hours 1 minutes and 0 seconds
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
3x drives, BASIC
three storage pool
five volumes
	volume1=BTRFS
	volume2=BTRFS
	volume3=EXT4
	volume4=BTRFS
	volume5=BTRFS
BTRFS scrubbing ACTIVE on volume1
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	Fri Apr  7 14:54:16 2023
	Script Version: 2.6 4/4/2023
	---------------------------------
	BTRFS SCRUBBING DETAILS
	---------------------------------

	"/volume1" BTRFS scrubbing Active.


	BTRFS Scrubbing Date Started: Fri Apr 7 2023, 14:41:25
	BTRFS Scrubbing Duration:  00:12:51
	BTRFS Scrubbing Device Name:  /dev/mapper/cachedev_0
	BTRFS Scrubbing Data Scrubbed [Bytes]:  211437617152
	BTRFS Scrubbing Volume Used Space [Bytes]:  281871826944
	BTRFS Scrubbing Percent Complete:  75.00%
	BTRFS Scrubbing Errors: 0


	"/volume2" is not performing BTRFS scrubbing --> last scrub has never been performed.


	"/volume4" is not performing BTRFS scrubbing --> last scrub has never been performed.


	"/volume5" is not performing BTRFS scrubbing --> last scrub has never been performed.


	---------------------------------
	RAID SCRUBBING DETAILS
	---------------------------------

	RAID device "md2" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	RAID device "md3" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	RAID device "md4" [ Raid Type: raid1 ] does not support RAID scrubbing and will be skipped.


	---------------------------------
	OVERALL SCRUBBING DETAILS
	---------------------------------

	Number of RAID Devices [Supporting Scrubbing]: 0
	Number of BTRFS Devices [Requiring Scrubbing]: 4
	Total Scrubbing Tasks Required: 4
	Scrub Processes Complete: 0
	Devices Completed: NONE


	Overall Scrub Percent: [=======.................................] 19%
	Total Scrubbing Runtime: 1 minutes and 0 seconds

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
force_sync_status_display=0
```

The first three lines control to whom the notification email will be sent, who the email is sent from, and what the email's title will be. 

The next line ```use_mail_plus``` controls if MailPlus server will be used. Set to "1" to use Mail Plus server. If set to "0" the Synology System Level SMTP server will be used instead. 

The next line ```log_file_location``` is a directory where log files and temp files will be stored while the script is running while ```log_file_name``` will be the name of the log file. 

The next line ```email_content_file_name``` is file name for the contents which will be emailed out. 

The next line ```enable_email_notifications``` allows to disable email notifications entirely. This is not recommended as the status script will not be able to notify you. This can be useful in testing and debugging however. 

the final line ```force_sync_status_display``` allows the script to send RAID srubbing statis if a RAID1 or RAID0 array is eigther being created or repaired. 



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
