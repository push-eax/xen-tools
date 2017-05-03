#!/bin/bash

VERSION="0.0.1"

VERB="" # create or remove
NAME="GUEST" # Guest name
MEMORY="2048" # Guest memory in megabytes. 2048 by default
CPUS="2" # Guest vCPUs. 2 by default
SIZE="10240" # LVM volume size in megabytes. 10GB default
ISOPATH="" # Path to ISO to use for installation

echo `basename "$0"`
echo -e "v$VERSION\n"

# Parse command line arguments
if [ $# -gt 1 ]; then
	# TODO: Check for ISOPATH, fail if not given
	if [ $1 = "create" ] || [ $1 = "remove" ]; then
                VERB=$1
        else
		echo "Use \"create\" or \"remove\" command trees."
		exit 1
	fi

	last=""

	for i in $@;
	do
		case $last in
			-n|--name)	NAME=$i;;
			-m|--memory)	MEMORY=$i;;
			-c|--cpus)	CPUS=$i;;
			-s|--size)	SIZE=$i;;
			-p|--path)	ISOPATH=$i;;
		esac

		last=$i
	done
else
	echo "Too few arguments. Specify \"create\" or \"remove\"."
	exit 1
fi

type xm >/dev/null 2>&1 || type xl >/dev/null 2>&1 || { echo >&2 "Xen administration tools not found. Aborting..."; exit 1; }
type lvm >/dev/null 2>&1 || { echo >&2 "lvm not found. Aborting..."; exit 1; }


create() {
	printf "Creating LVM volume $NAME..."
	lvcreate -n"$NAME" -L"$SIZE"M vg0 # TODO: change vg0 to dynamic volume group detection
	if [ $? -eq 0 ]; then
		echo -e '[\033[00;32mOK\033[00;0m]'
	else 
		echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: Change FAIL colors to red
		echo "LVM volume $NAME could not be created. Aborting..."
		exit 1;
	fi

	FULLPATH=$(readlink -f $ISOPATH)

	printf "Creating LVM volume $NAME..."
	echo -e "\tkernel = '/usr/lib/xen-4.0/boot/hvmloader'
	builder='hvm'
	memory = $MEMORY
	vcpus = $CPUS
	name = '$NAME'
	vif = ['bridge=xenbr0']
	disk = ['phy:/dev/vg0/$NAME,hda,w','file:$FULLPATH,hdc:cdrom,r']
	acpi = 1
	device_model_version = 'qemu-xen'
	boot='d'
	sdl=0
	serial='pty'
	vnc=1
	vnclisten=''
	vncpasswd=''" >> "$NAME.cfg"
	if [ $? -eq 0 ]; then
		echo -e '[\033[00;32mOK\033[00;0m]'
	else
		echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: Change FAIL colors to red
		echo "Config file $NAME.cfg could not be written. Aborting..."
		exit 1;
	fi

	printf "Booting $NAME (10 seconds)..."
	xl create "$NAME.cfg" > /dev/null
	sleep 10;
	echo -e '[\033[00;32mOK\033[00;0m]'

	printf "Changing $NAME bootflag from 'c' (iso) to 'd' (disk)..."
	sed "s/boot='d'/boot='c'/" "$NAME.cfg" >> "$NAME.cfg"
	echo -e '[\033[00;32mOK\033[00;0m]'

	echo "$NAME created. Exiting..."
}

remove() {
	# Bring down the VM if it's online 
	if [ "$XENGUEST" != "" ]; then
		printf "$NAME is online. Bringing it down..."
		xl destroy $NAME
		echo -e '[\033[00;32mOK\033[00;0m]'
	fi

	printf "Removing $LVMPATH..."
	lvremove $LVMPATH
	if [ $? -eq 0 ]; then
                echo -e '[\033[00;32mOK\033[00;0m]'
        else
		echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: Change FAIL colors to red
		echo "$LVMPATH could not be removed. Aborting..."
		exit 1;
        fi

	echo "$NAME removed. Don't forget to delete $NAME.cfg!"
}


printf "Checking for guest LVM volume..."
LVMPATH=`lvdisplay | grep $NAME | grep "Path"`
LVMPATH=${LVMPATH:25} # magic number for trimming lvdisplay output. TODO: use awk

# TODO: check if LVMPATH returned a volume, print OK or FAIL depending on $VERB
echo -e '[\033[00;32mOK\033[00;0m]'
#echo "Found LVM volume $LVMPATH."

printf "Checking for $NAME in xl..."
XENGUEST=`xl list | grep $NAME`
# TODO: check if guest exists, print OK or FAIL depending on $VERB

echo -e '[\033[00;32mOK\033[00;0m]'
#echo "$NAME is online."


#echo "LVMPATH: $LVMPATH"
#echo "XENGUEST: $XENGUEST"


# TODO: this checking should happen in the prior block, not here

#if ([ "$LVMPATH" != "" ] && [ "$XENGUEST" != "" ] && [ $VERB = "create" ]) || [ $VERB = "remove" ]; then
#	$VERB
#fi

#echo "$LVMPATH"
#echo "$NAME"

if [ "$LVMPATH" != "" ]; then 
	[[ $VERB = "create" ]] || $VERB # call create()
else [[ $VERB = "remove" ]] || $VERB # call remove()
fi

echo "Finished."
# TODO: if verb = create, echo $NAME created. else, echo $NAME removed.
echo -e "\n"
exit 0
