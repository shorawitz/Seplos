LEN="002"
echo $LEN
LENSUM=$((~(${LEN:0:1} + ${LEN:1:1} + ${LEN:2:1})))
echo $LENSUM
TEST1=${LEN:0:1}
echo $TEST1
TEST2=${LEN:1:1}
echo $TEST2
TEST3=${LEN:2:1}
echo $TEST3
TEST3a=($TEST1+$TEST2+$TEST3)
echo $TEST3a
TEST4=$((~($TEST1+$TEST2+$TEST3)))
echo $TEST4

LENSUM=$(printf "%X" $LENSUM)
echo $LENSUM

TEST="D"
echo $TEST
TEST=$((0x$TEST + 1))
echo $TEST

SEND="20084642E00201"
echo $SEND

for d in $(echo -n "$SEND" | od -An -td1)
do
	SUM=$((SUM + $d))
	echo $d, $SUM
done

SUM=$((~$SUM))
echo $SUM

SUM="$(printf "%04X" $SUM)"
echo $SUM

SUM="${SUM:0-4:4}"
echo $SUM

YO=333
echo $YO
YO=$((~$YO))
echo $YO
