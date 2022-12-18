#!/bin/bash

DEV=/dev/ttyUSB0
ADDR=08

# Get a 4 ASCII digit number and divide by $1, precision $2 ( or 2dp. ) $3 == 1 for signed.
get_div()
{
        N=${rdata:$OFFSET:4}
        OFFSET=$((OFFSET + 4))
        local P=${2:-2}

        N=$(printf "%d" 0x$N)
        [ "$3" = "1" -a $N -gt 32767 ] && N=$((N - 65536))
        N=$(bc <<< "scale = $P; $N / $1")
}

read_serdata()
{
        local len rdata tries=3 rd2

        while [ "${rdata:0:1}" != "~" ]
        do
                tries=$((tries - 1))
                [ $tries -le 0 ] && { echo "Failed to read start of input char (~), read \"$rdata\"" 1>&2 ; exit 1; }
                read -r -t5 rdata <$DEV
        done

        len=${rdata:10:3}
        len=$((0x$len))

        while [ ${#rdata} -lt $((len + 17)) ]
        do
                read -r -t5 rd2 <$DEV
                [ -z "$rd2" ] && { echo "Failed to read whole response." ; exit 2; }
                rdata="$rdata$rd2"
        done

        if [ "$RQCODE" = "42" ]
        then
                OFFSET=19
                [ "${rdata:7:2}" != "00" ] && { echo "Error code ${rdata:7:2}"; exit 3; }

                local l NCELL=$(printf "%d" 0x${rdata:17:2})

                echo "Number of cells: $NCELL"

                for l in $(seq 1 $NCELL)
                do
                        local V=$(printf "%d" 0x${rdata:$OFFSET:4})
                        OFFSET=$((OFFSET + 4))
                        echo "Cell $l: ${V}mV"
                done

                local NTEMPS=$(printf "%d" 0x${rdata:$OFFSET:2})
                OFFSET=$((OFFSET + 2))

                local TSTR="Cell Temp "

                for l in $(seq 1 $NTEMPS)
                do
                        [ $l -eq $((NTEMPS - 1)) ] && TSTR="Environmental Temp"
                        [ $l -eq $((NTEMPS)) ] && TSTR="Power Temp"
                        local T=$(printf "%d" 0x${rdata:$OFFSET:4})
                        OFFSET=$((OFFSET + 4))
                        T=$(bc <<< "scale = 1; ($T - 2731)/10")
                        echo "$TSTR ${T}C"
                done

                get_div 100 2 1         # Can't use $() because that creates a subshell
                echo "Charge/Discharge: ${N}A"
                get_div 100
                echo "Total Voltage: ${N}V"
                get_div 100
                echo "Residual Capacity: ${N}Ah"
                OFFSET=$((OFFSET + 2))
                get_div 100
                echo "Battery Capacity: ${N}Ah"
                get_div 10 1
                echo "SOC: ${N}%"
                get_div 100
                echo "Rated Capacity: ${N}Ah"
                get_div 1 0
                echo "Cycles: ${N}"
                get_div 10 1
                echo "SOH: ${N}%"
                get_div 100 2
                echo "Port Voltage: ${N}V"
        else
                echo "Response: \"$rdata\""
        fi

}

# Todo... calculate length checksum and insert in send string.

stty -F $DEV sane -echo -echoe -echok 9600

SUM=0

export RQCODE=${1:0:2}
RQ="20${ADDR}46$1"
echo "RQ=$RQ"
CMD=${RQ:0:8}
DATA=${RQ:8}
echo "DATA=$DATA"
LEN=${#DATA}
LEN=$(printf "%03X" $LEN)
echo "LEN=$LEN"
LENSUM=$((~(${LEN:0:1} + ${LEN:1:1} + ${LEN:2:1})))
LENSUM=$(printf "%X" $LENSUM)
LENSUM=${LENSUM:0-1:1}
LENSUM=$((0x$LENSUM + 1))
LENSUM=$(printf "%X" $LENSUM)
LENSUM=${LENSUM:0-1:1}
SEND=$CMD$LENSUM$LEN$DATA
echo "SEND=$SEND"

for d in $(echo -n "$SEND" | od -An -td1)
do
        SUM=$((SUM + $d))
        echo $d $SUM
done
echo "SUM=$SUM"

SUM=$((~$SUM))
echo "SUM=$SUM"
SUM="$(printf "%04X" $SUM)"
echo "SUM=$SUM"
SUM="${SUM:0-4:4}"
echo "SUM=$SUM"
SUM=$((0x$SUM + 1))
echo "SUM=$SUM"
SUM=$(printf "%04X" $SUM)
echo "SUM=$SUM"
SUM="${SUM:0-4:4}"
echo "SUM=$SUM"
SEND="~$SEND$SUM\r\n"
echo "Sending \"$SEND\""
read_serdata &
sleep 0.2
echo -e "$SEND" >$DEV
wait

