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

<h3 align="center">Synology Data Srubbing (Raid Sync and BTRFS Scrubbing) + Email Notifications on Status</h3>

  <p align="center">
    This project is comprised of a simple shell script that is configured in Synology Task Scheduler to run once per hour. The script performs commands to determine the RAID syncing status and BTRFS file system scrubbing status. If the status is active an email is sent with that current status
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

the script performs the following command to get the BTRFS status on a particular volume ```btrfs scrub status -d /volumexxxx``` where xxx indicates the volume number (Volume1 or Volume2 etc). The scrip then searches the resulting output for the string "running". If the string is found, then the BTRFS scrubbing is active. 

the script also performs the command ```cat /proc/mdstat``` to get the current RAID status. if the string "resync" is found, then the RAID sync activity is in progress

An email with the status of scrubbing is only sent if scrubbing is active. 

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

This project is written around a Synology NAS, however the BTRFS and RAID commands can work on other systems. 

### Prerequisites

This project requires Synology Mail Plus Server to be installed. This script uses the command "sendmail" which is not available on Synology DSM unless Mail Plus Server is installed and properly configured to relay messages. 

### Installation

The script can be downloaded and placed in any shared folder desired on the Synology NAS

the script has the folllowing configuration paramters

```
email_address="email@domain.com"
from_email_address="from@domain.com"
email_subject="Server Data Scrubbing Status"
lock_file="/volume1/web/logging/notifications/data_scrubbing.lock"
log_file="/volume1/web/logging/notifications/file_scrubbing_status.txt"
number_installed_BTRFS_volumes=2
```

The first three lines control to whom the notification email will be sent, who the email is sent from, and what the email's title will be. 

The next line ```lock_file```. This file is used to prevent more than one instance of the script from running at once. ensure the path and file name are correct for where you wish the file to be temporally stored. 

The next line ```log_file``` is where the .txt log file generated by the script will be saved. This file also contains the information that will be emailed if scrubbing is active.

the final line ```number_installed_BTRFS_volumes``` is the number of volumes configured for BTRFS file systems so the script can loop through all of the volumes

Once the script is on the NAS, go to Control Panel --> Task Scheduler

Click on Create --> Scheduled Task --> User-defined_script

In the new window, name the script something useful like "Data Scrubbing Status" and set user to either root, or a user with administrative rights as DSM will otherwise not allow the commands to run

Go to the schedule tab, and at the bottom, change the "Frequency" to "every hour" and change the "last time run" to "23:00"

Go to the "Task Settings" tab. in the "user defined script" area at the bottom enter ```bash /volume1/web/logging/datascrubbing.sh``` for example. Ensure the path is the path to where the file was placed on the NAS. 

Click OK. 

To verify the script works, selecting the scheduled task and hitting "Run" will force the script to operate. If Synology Mail Plus server is configured correctly to forward emails, an email will be received. If debugging is needed, adding an email address to the "Task Settings" tab can allow Task Scheduler to send an email with the results of the script execution. 



<!-- USAGE EXAMPLES -->
## Usage

The output of the script will look as follows

```
from: from@domain.com 
to: email@domain.com
subject: Server Data Scrubbing Status 

MailPlus Server is installed and running


No BTRFS Data Scrubbing Currently In Progress on /Volume1

scrub status for 1bab8567-2ba3-468e-a36c-be71fe78f0a5
scrub device /dev/mapper/cachedev_1 (id 1) history
	scrub started at Sun May 15 01:00:07 2022 and finished after 16:12:46
	total bytes scrubbed: 26.19TiB with 0 errors
______________________________________________

No BTRFS Data Scrubbing Currently In Progress on /Volume2

scrub status for 666796d0-417c-4be1-b016-7d2c069d113b
scrub device /dev/mapper/cachedev_0 (id 1) history
	scrub started at Tue May 17 02:21:21 2022 and finished after 16:50:54
	total bytes scrubbed: 26.09TiB with 0 errors
______________________________________________

No RAID Data Scrubbing Currently In Progress

Personalities : [raid1] [raid6] [raid5] [raid4] [raidF1] 
md2 : active raid5 sata3p3[0] sata2p3[3] sata1p3[2] sata4p3[1]
      35142190080 blocks super 1.2 level 5, 64k chunk, algorithm 2 [4/4] [UUUU]
      
md3 : active raid5 sata5p3[0] sata9p3[4] sata8p3[3] sata7p3[2] sata6p3[1]
      46856253440 blocks super 1.2 level 5, 64k chunk, algorithm 2 [5/5] [UUUUU]
      
md1 : active raid1 sata1p2[0] sata4p2[3] sata3p2[2] sata2p2[1]
      2097088 blocks [4/4] [UUUU]
      
md0 : active raid1 sata3p1[0] sata2p1[3] sata1p1[2] sata4p1[1]
      2490176 blocks [4/4] [UUUU]
      
unused devices: <none>
______________________________________________


```


<p align="right">(<a href="#top">back to top</a>)</p>



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


<p align="right">(<a href="#top">back to top</a>)</p>
