let PIC=0
echo -n "" > list.txt

while true; do
./readpipe.py show0
./readpipe.py stream
read
./readpipe.py snap
./readpipe.py show0
./readpipe.py pic
cat a.out | ../usb2tiff.py l_$PIC.tiff
./readpipe.py show1
./readpipe.py pic
cat a.out  | ../usb2tiff.py r_$PIC.tiff
echo "l_$PIC.tiff" >> list.txt
echo "r_$PIC.tiff" >> list.txt
let PIC=PIC+1


done