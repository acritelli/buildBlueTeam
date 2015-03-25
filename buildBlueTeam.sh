#!/bin/bash

##Known issues##
#There really isn't any error checking. This script serves a very specific function under very specific circumstances in a very specific environment, so it wasn't entirely necessary.
#There is some inconsistency in what is defined as a var and what is just hardcoded into the script.
#Basically, I threw this together and it works well enough in the circumstances

#Accept the team number via command line args
if [  $# -lt 2 ]; then
	echo -e "Usage: ./buildBlueTeam.sh <TEAMNUM> <WHITETEAM IP> [Voice]\n\tVoices: Luke[1] Nikko[2] Peter[3] Kirstie[4]"
	exit 1
else
	#If the team num is only one digit, then we append a 0
	TEAMNUM="$(echo $1 | sed "s/\(^[1-9]$\)/0\1/g")"
	WHITETEAM=$2
fi

#Team number without any leading zeros, this is useful in later parts of the script.
TEAMNUMSHORT="$(echo $TEAMNUM | sed "s/^0//")"

#Disable SELinux

sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

#We need bc to perform some decimal to binary conversions later.
yum install -y bc

#Move config file templates
cp templates/etc/* /etc/asterisk/

#Move sound files

#Pick a random voice, it it hasn't been set by a command line arg

if [ "$3" == "" ]; then
	SOUNDNUMBER="$(cat /dev/urandom | tr -dc '1-4' | fold -w 1 | head -n 1)"
else
	SOUNDNUMBER=$3
fi

mkdir /var/lib/asterisk/sounds/en/ists
cp templates/sounds/$SOUNDNUMBER/* /var/lib/asterisk/sounds/en/ists
cp templates/sounds/misc/* /var/lib/asterisk/sounds/en/ists
cp -f templates/sounds/digits/* /var/lib/asterisk/sounds/en/digits

#Move scripts to script directory
SCRIPTDIR=/var/lib/asterisk/ists/

mkdir -p $SCRIPTDIR
cp templates/scripts/* $SCRIPTDIR
chmod +x $SCRIPTDIR/*

##### FILE CONFIGURATION #####


## sip.conf ##

#Grab host IP address using this hideous string of commands and YOLO regexes

IPADDRESS="$(ip addr sh eth0 | grep inet | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/' | tr -d /)"
sed -i "s/udpbindaddr=192.168.1.10/udpbindaddr=$IPADDRESS/" /etc/asterisk/sip.conf

#Set white team PBX peering info. Find and replace placeholders in template configs

TEAM=team #Needed because I'm lazy and it will be concatenated later

#Credit to Hyppy on ServerFault for this solution to generate a pseudorandom string
PEERINGPW="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"

sed -i "s/.*\$PEERHOST.*/\thost=$WHITETEAM/" /etc/asterisk/sip.conf
sed -i "s/.*\$PEERUSER.*/\tdefaultuser=$TEAM$TEAMNUM/" /etc/asterisk/sip.conf
sed -i "s/.*\$PEERSECRET.*/\tsecret=$PEERINGPW/" /etc/asterisk/sip.conf

#Add extensions, removing whitespace after team num variable using tr
EXT01PW="$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1)"
echo "[$TEAMNUM 01](team-phone)" | tr -d ' ' >> /etc/asterisk/sip.conf
echo "	secret=$EXT01PW" >> /etc/asterisk/sip.conf

## extensions.conf ##

#Place team number in this file so that extensions are correct
sed -i "s/^TEAMNUM.*/TEAMNUM=$TEAMNUM/" /etc/asterisk/extensions.conf

#This removes the team's number from being forwarded on the SIP trunk. This prevents an infinite loop for a failed call.

if [ "$TEAMNUMSHORT" -lt "10" ]; then
	PEEREXPRESSION="$(echo 123456789 | sed s/$TEAMNUMSHORT//)"
	sed -i s"/0\[123456789\]/0\[$PEEREXPRESSION\]/" /etc/asterisk/extensions.conf
else

	LASTDIGIT="$(echo $TEAMNUMSHORT | sed s/^.//)"
	PEEREXPRESSION="$(echo 1234567890 | sed s/$LASTDIGIT//)"
	sed -i s"/1\[123456789\]/1\[$PEEREXPRESSION\]/" /etc/asterisk/extensions.conf
fi

#Create evil extension and replace in template file from placeholder
EVILEXTENSION="$(cat /dev/urandom | tr -dc '0-9' | fold -w 2 | head -n 1)"

sed -i "s/.*EVILEXTEN.*/\texten => _$TEAMNUM$EVILEXTENSION,1,Goto(menu,start,1)/" /etc/asterisk/extensions.conf


## ISTS Evil Menu ##
#This basically builds the entire menu, creating random numbers for each team.

SOUNDFOLDER="/var/lib/asterisk/sounds/en/ists"
MENUFILE="/etc/asterisk/istsmenu.conf"



echo "[menu]" > $MENUFILE

##Build the intro

echo "exten => start,1,Answer()" >> $MENUFILE 
echo -e "\t same=> n,Background($SOUNDFOLDER/intro1)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($TEAMNUMSHORT)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/intro2)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/enterSelection)" >> $MENUFILE

##Prompt 1: Drop the firewall

#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT1DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 3 | head -n 1 | sed "s/^0*//")"
PROMPT1BIN="$(echo "obase=2;$PROMPT1DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt1)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT1DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

##Prompt 2: SSH Backdoor

#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT2DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 3 | head -n 1 | sed "s/^0*//")"
PROMPT2BIN="$(echo "obase=2;$PROMPT2DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt2)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT2DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

##Prompt 3: Start Apache
 
#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT3DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1 | sed "s/^0*//")"
PROMPT3BIN="$(echo "obase=2;$PROMPT3DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt3)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT3DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

##Prompt 4: Start Telnet

#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT4DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 6 | head -n 1 | sed "s/^0*//")"
PROMPT4BIN="$(echo "obase=2;$PROMPT4DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt4)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT4DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

##Prompt 5: Backup critical system files

#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT5DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 6 | head -n 1 | sed "s/^0*//")"
PROMPT5BIN="$(echo "obase=2;$PROMPT5DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt5)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT5DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

##Prompt 6: Netcat listener

#Create a decimal and binary equivalent for the prompt and then actual menu entry, respectively.
PROMPT6DEC="$(cat /dev/urandom | tr -dc '0-9' | fold -w 7 | head -n 1 | sed "s/^0*//")"
PROMPT6BIN="$(echo "obase=2;$PROMPT6DEC" | bc)"

echo -e "\t same=> n,Background($SOUNDFOLDER/prompt6)" >> $MENUFILE
echo -e "\t same=> n,SayNumber($PROMPT6DEC)" >> $MENUFILE
echo -e "\t same=> n,Background($SOUNDFOLDER/base2)" >> $MENUFILE

#Wait for user input for 30 secs
echo -e "\t same=> n,WaitExten(30)\n\n" >> $MENUFILE

##Prompt actions
#TODO: actual shell scripts
#Prompt 1 Action
echo -e "exten => _$PROMPT1BIN#,1,System(/var/lib/asterisk/ists/prompt1.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

echo -e "exten => _$PROMPT2BIN#,1,System(/var/lib/asterisk/ists/prompt2.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

echo -e "exten => _$PROMPT3BIN#,1,System(/var/lib/asterisk/ists/prompt3.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

echo -e "exten => _$PROMPT4BIN#,1,System(/var/lib/asterisk/ists/prompt4.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

echo -e "exten => _$PROMPT5BIN#,1,System(/var/lib/asterisk/ists/prompt5.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

echo -e "exten => _$PROMPT6BIN#,1,System(/var/lib/asterisk/ists/prompt6.sh)" >> $MENUFILE
echo -e "\t same => n,Background(auth-thankyou&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

#Handle invalid entries and timeouts (30 secs)
echo -e "exten => i,1,Background($SOUNDFOLDER/invalidSelection&$SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE
echo -e "exten => t,1,Background($SOUNDFOLDER/goodbye)" >> $MENUFILE
echo -e "\t same => n,Hangup()" >> $MENUFILE

#Config Asterisk to run as root - copy asterisk init script
cp templates/init/asterisk /etc/init.d/

#Remove CDR configuration, since we may make CDR collection an inject
rm -f /etc/asterisk/*cdr*

#Enable Asterisk
chkconfig asterisk on

service asterisk restart

#Set appropriate firewall rules and save them
iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
service iptables save

history -c

echo -e "\n\n********** SCRIPT COMPLETE **********"
echo -e "The script may or may not have been successful. Who knows. There's no error checking.\n\n"
echo -e "Team number: $TEAMNUM"
echo -e "Password for extension XX01 - $EXT01PW"
echo -e "Password for white team peer - $PEERINGPW"
echo -e "\n***** EVIL EXTENSIONS *****"
echo -e "Extension - $EVILEXTENSION"
echo -e "\t\t\t\tDecimal\tBinary"
echo -e "Prompt 1 (Drop Firewall) - \t$PROMPT1DEC\t$PROMPT1BIN"
echo -e "Prompt 2 (SSH Backdoor) - \t$PROMPT2DEC\t$PROMPT2BIN"
echo -e "Prompt 3 (Start Apache) - \t$PROMPT3DEC\t$PROMPT3BIN"
echo -e "Prompt 4 (Start Telnet) - \t$PROMPT4DEC\t$PROMPT4BIN"
echo -e "Prompt 5 (Backup Files) - \t$PROMPT5DEC\t$PROMPT5BIN"
echo -e "Prompt 6 (Netcat Listener) - \t$PROMPT6DEC\t$PROMPT6BIN"

if [ "$SOUNDNUMBER" == "1" ]; then
	VOICECHOSEN="Luke"
elif [ "$SOUNDNUMBER" == "2" ]; then
	VOICECHOSEN="Nikko"
elif [ "$SOUNDNUMBER" == "3" ]; then
	VOICECHOSEN="Peter"
elif [ "$SOUNDNUMBER" == "4" ]; then
	VOICECHOSEN="Kirstie"
fi

echo -e "\nVoice chosen: $VOICECHOSEN\n\n"


#Because I was too lazy to actually fix this in a loop, you have to manually edit the dialplan if the evil extension matches the team's primary extension.
#This is just a warning.
if [ $EVILEXTENSION == 01 ]; then
	echo -e "CRITICAL ERROR: Evil extension matches the team's primary extension 01. Manually change this.\n\n"
fi
