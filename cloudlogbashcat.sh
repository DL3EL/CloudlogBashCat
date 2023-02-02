#! /bin/bash

# cloudlogbashcat.sh 
# A simple script to keep Cloudlog in synch with rigctld or flrig.
# Copyright (C) 2018  Tony Corbett, G0WFV
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

DEBUG=0

rigFreq=0
rigOldFreq=1

rigMode="MATCH"
rigOldMode="NO MATCH"

delay=1
n=0

# load in config ...
source cloudlogbashcat.conf

simpleArg() {
    local arg="$1"
    local type=${arg%%:*} val=${arg#*:}
        echo -e "${indent}<param><value><$type>$val</$type></value></param>"
}

structArg() {
    local arg="$1"
        : parse wait complete ...
}

generateRequestXml() {
    method=$1; shift
    echo '<?xml version="1.0"?>'
    echo "<methodCall>"
    echo "    <methodName>$method</methodName>"
    if [[ $rigControlSoftware = "flrig" ]]; then
# no need of <params> when using fldigi
	echo "    <params>"
    fi

    indent="    "
    for arg; do
        indent="${indent}    "
        case $arg in
        struct:*) structArg "$arg";;
        *) simpleArg "$arg";;
        esac
    done

    if [[ $rigControlSoftware = "flrig" ]]; then
	echo "    </params>"
    fi
    echo "</methodCall>"
}

while true; do
	case $rigControlSoftware in
		rigctld)
			# Open FD 3 to rig control server ...
			exec 3<>/dev/tcp/$host/$port

			if [[ $? -ne 0 ]]; then
				echo "Unable to contact server" >&2
				exit 1
			fi

			# Get rigctld frequency, mode and bandwidth - accepts multiple commands
			echo -e "fm" >&3
			read -r -u3 rigFreq
			read -r -u3 rigMode
			read -r -u3 rigWidth

			# Close FD 3
			exec 3>&-
			;;

		flrig)
			# Get flrig frequency ...
			rpcxml=$(generateRequestXml "rig.get_vfo")
			rigFreq=$(curl -k $verbose --data "$rpcxml" "$host:$port" 2>/dev/null | xmllint --format --xpath '//value/text()' - 2>&1)

			if [[ $? -ne 0 ]]; then
				echo "Unable to contact server" >&2
				exit 1
			fi

			# Get flrig mode ...
			rpcxml=$(generateRequestXml "rig.get_mode")
			rigMode=$(curl -k $verbose --data "$rpcxml" "$host:$port" 2>/dev/null | xmllint --format --xpath '//value/text()' -)
			;;

		fldigi)
			# Get flrig frequency ...
			rpcxml=$(generateRequestXml "main.get_frequency")
			rigFreq=$(curl -k $verbose --data "$rpcxml" "$host:$port" 2>/dev/null | xmllint --format --xpath '//value/double/text()' - 2>&1)
			# freq is delivered as double: 14189860.000000, change format
			rigFreq=${rigFreq%.*}

			if [[ $? -ne 0 ]]; then
			    echo "Unable to contact server" >&2
			    exit 1
			fi

			# Get flrig mode ...
			rpcxml=$(generateRequestXml "rig.get_mode")
			rigMode=$(curl -k $verbose --data "$rpcxml" "$host:$port" 2>/dev/null | xmllint --format --xpath '//value/text()' -)
			case $rigMode in
			# CWR, RTTYR, etc is not supported by Cloudlog
			    CWR)
				rigMode="CW"
				;;
			    USB)
				rigMode="SSB"
				;;
			    LSB)
				rigMode="SSB"
				;;
			    PKTUSB)
				rigMode="PSK"
				;;
			    PKTLSB)
				rigMode="PSK"
				;;
			    RTTYR)
			    rigMode="RTTY"
			    ;;
			esac
			;;
		sparksdr)
			rigMode=$(rigctl -r $host:$port -m2 m)
			rigFreq=$(rigctl -r $host:$port -m2 f)
			
			IFS='-' read -ra  IP <<< "$rigMode"
			for rigMode in "${IP[@]}";
# sonst läuft es nicht
			do
			    echo "" >/dev/null
			done
			# sparksdr delivers not all modes, try to guess them
			if [ "$rigMode"="" ]; then 
			    case $rigFreq in
				136000)
				    rigMode="USB"
				    ;;
				474200)
				    rigMode="USB"
				    ;;
				1836000)
				    rigMode="FT8"
				    ;;
				3573000)
				    rigMode="FT8"
				    ;;
				3576000)
				    rigMode="FT4"
				    ;;
				3568600)
				    rigMode="WSPR"
				    ;;
				5357000)
				    rigMode="FT8"
				    ;;
				5366000)
				    rigMode="WSPR"
				    ;;
				7074000)
				    rigMode="FT8"
				    ;;
				7038600)
				    rigMode="WSPR"
				    ;;
				7047500)
				    rigMode="FT4"
				    ;;
				10136000)
				    rigMode="FT8"
				    ;;
				10138700)
				    rigMode="WSPR"
				    ;;
				10140000)
				    rigMode="FT4"
				    ;;
				14074000)
				    rigMode="FT8"
				    ;;
				14080000)
				    rigMode="FT4"
				    ;;
				14095600)
				    rigMode="WSPR"
				    ;;
				18100000)
				    rigMode="FT8"
				    ;;
				18104000)
				    rigMode="FT4"
				    ;;
				18104600)
				    rigMode="WSPR"
				    ;;
				21074000)
				    rigMode="FT8"
				    ;;
				21094600)
				    rigMode="WSPR"
				    ;;
				21140000)
				    rigMode="FT4"
				    ;;
				24915000)
				    rigMode="FT8"
				    ;;
				24919000)
				    rigMode="FT4"
				    ;;
				24924600)
				    rigMode="WSPR"
				    ;;
				28070000)
				    rigMode="FT4"
				    ;;
				28074000)
				    rigMode="FT8"
				    ;;
				28124600)
				    rigMode="WSPR"
				    ;;
			    esac
			fi    
			
			rigMode=$(echo $rigMode|tr -d '\n')
			case $rigMode in
			    CWR)
				rigMode="CW"
				;;
			    USB)
				rigMode="SSB"
				;;
			    LSB)
				rigMode="SSB"
				;;
			    280)
				rigMode="WSPR"
				;;
			    4900)
				rigMode="JT9"
				;;
			    2850)
				rigMode="SSTV"
				;;
			    3000)
				rigMode="PSK"
				;;
			    16000)
				rigMode="FM"
				;;
			    44000)
				rigMode="USB"
				;;
			    PKTUSB)
				rigMode="PSK"
				;;
			    PKTLSB)
				rigMode="PSK"
				;;
    			esac
			;;

		*)
			echo "Unknown rig control server type" >&2
			exit 1
			;;
	esac

  if [ "$n" -gt 600 ]; then
# make sure that at least every 10 min something is pushed to cloudlog, to prevent an error message (rig not responding)
    rigOldFreq=0
    n=0
    [[ $DEBUG -eq 1 ]] && printf  "%s   %s $(date +"%Y/%m/%d %H:%M")\n" $rigFreq $rigMode
 else 
    n=$((n+1))
  fi    

		
  if [ "$rigFreq" -ne "$rigOldFreq"  ] || [ "$rigMode" != "$rigOldMode"  ]; then
    # rig freq or mode changed, update Cloudlog
    [[ $DEBUG -eq 1 ]] && printf  "%s   %s $(date +"%Y/%m/%d %H:%M")\n" $rigFreq $rigMode
    rigOldFreq=$rigFreq
    rigOldMode=$rigMode

    curl --silent --insecure \
         --header "Content-Type: application/json" \
         ${cloudlogHttpAuth:+"--header"} \
         ${cloudlogHttpAuth:+"Authorization: $cloudlogHttpAuth"} \
         --request POST \
         --data "{ 
           \"key\":\"$cloudlogApiKey\",
           \"radio\":\"$cloudlogRadioId\",
           \"frequency\":\"$rigFreq\",
           \"mode\":\"$rigMode\",
           \"timestamp\":\"$(date -u +"%Y/%m/%d %H:%M")\"
         }" $cloudlogApiUrl >/dev/null 2>&1

    n=0
  fi

	sleep $delay
done

# Testcall, use in CLI, if script does not show any update in cloudlog
# curl --insecure --header "Content-Type: application/json" --request POST --data "{ \"key\":\"cl6key2520519d8\",\"radio\":\"HL2 R1\",\"frequency\":\"24911000\",\"mode\":\"FM\",\"timestamp\":\"2023/02/02 12:42\"}" https://192.168.1.1/index.php/api/radio
