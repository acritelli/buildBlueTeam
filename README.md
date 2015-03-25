# buildBlueTeam

This is the script that was used to build blue team Asterisk configurations for ISTS 12.

Please be aware that there is basically no error checking. It worked in a very specific environment for a very specific purpose. It is a rough script that got the job done.

This script can be run after installing Asterisk. It should work on most RHEL based distros.

The script does the following (I may have forgotten some things, so be sure to review the code):

* Disables SELinux
* Moves custom sound files for hidden vulnerability menu and custom recorded numerical digits
* Creates a directory (/var/lib/asterisk/ists/scripts) for storing scripts related to the vulnerability menu. It also moves all scripts to this directory
* Sets the IP address in sip.conf using a poorly constructed regex that only works if the interface is eth0
* Sets the IP address of the white team SIP peer in sip.conf
* Creates an evil extension for each team's hidden vulnerability menu
* Creates a unique vulnerability menu for each team. Notably, this accomplishes the following:
  * Anyone calling the extension will be directed to an IVR
  * The IVR options include things like starting a netcat listener or dropping the firewall
  * IVR options are announced as normal, decimal numbers. However, they must be entered in binary and followed by a # key. The script automatically generates unique binary numbers for each IVR option.
* Moves an init script to /etc/init.d for Asterisk that sets AST_USER=root so that commands can be run with root privileges
* Starts Asterisk and chkconfigs it to on
* Adds appropriate firewall rules for VoIP
* Spits out a nice message with information about team extension password, SIP peering password, and hidden vulnerability menu

## Usage

Running the script is easy. There are two required arguments and one optional argument. The first argument is the team number to build. The second argument is the IP address of the hub server (white team server). The third, (optional) argument is the voice to be used in the menu. So, to create an Asterisk configuration for team 6 with a White Team PBX address of 192.168.1.1, the script would be invoked like so:

> ./buildBlueTeam.sh 6 192.168.1.1

## Directory structure

The script assumes the following directory structure. The sound files will have to be provided. Review the script code for more information about what each prompt corresponds to. Also note that the contents of each sound subdirectory have been omitted for brevity, as they are all identical.
```
├── buildBlueTeam.sh
└── templates
    ├── etc
    │   ├── asterisk.conf
    │   ├── asteriskConfig.conf
    │   ├── extensions.conf
    │   └── sip.conf
    ├── init
    │   └── asterisk
    ├── scripts
    │   ├── prompt1.sh
    │   ├── prompt2.sh
    │   ├── prompt3.sh
    │   ├── prompt4.sh
    │   ├── prompt5.sh
    │   └── prompt6.sh
    └── sounds
        ├── 1
        │   ├── base2.gsm
        │   ├── enterSelection.gsm
        │   ├── intro1.gsm
        │   ├── intro2.gsm
        │   ├── prompt1.gsm
        │   ├── prompt2.gsm
        │   ├── prompt3.gsm
        │   ├── prompt4.gsm
        │   ├── prompt5.gsm
        │   └── prompt6.gsm
        ├── 2
        │   OMITTED, same as subdirectory 1
        ├── 3
        │   OMITTED, same as subdirectory 1
        ├── 4
        │   ├OMITTED, same as subdirectory 1
        ├── digits
        │   ├── 0.gsm
        │   ├── 1.gsm
        │   ├── 10.gsm
        │   ├── 11.gsm
        │   ├── 12.gsm
        │   ├── 13.gsm
        │   ├── 14.gsm
        │   ├── 15.gsm
        │   ├── 16.gsm
        │   ├── 17.gsm
        │   ├── 18.gsm
        │   ├── 19.gsm
        │   ├── 2.gsm
        │   ├── 20.gsm
        │   ├── 3.gsm
        │   ├── 30.gsm
        │   ├── 4.gsm
        │   ├── 40.gsm
        │   ├── 5.gsm
        │   ├── 50.gsm
        │   ├── 6.gsm
        │   ├── 60.gsm
        │   ├── 7.gsm
        │   ├── 70.gsm
        │   ├── 8.gsm
        │   ├── 80.gsm
        │   ├── 9.gsm
        │   ├── 90.gsm
        │   ├── billion.gsm
        │   ├── hundred.gsm
        │   ├── million.gsm
        │   └── thousand.gsm
        └── misc
            ├── goodbye.gsm
            ├── invalidSelection.gsm
            └── magicWord.gsm
```