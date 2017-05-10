#!/bin/bash

VERSION="0.0.1"

VERB="" # create or remove
NAME="" # Guest name
MEMORY="2048" # Guest memory in megabytes. 2048 by default
CPUS="2" # Guest vCPUs. 2 by default
SIZE="10240" # LVM volume size in megabytes. 10GB default
ISOPATH="" # Path to ISO to use for installation

echo `basename "$0"`
echo -e "v$VERSION\n"

# Parse command line arguments
if [ $# -gt 2 ]; then
	# TODO: Check for ISOPATH, fail if not given
	if [ $1 = "create" ] || [ $1 = "remove" ]; then
                VERB=$1
        else
		echo "Use \"create\" or \"remove\" command trees."
		exit 1
	fi

	NAME=$2

	last=""

	for i in $@;
	do
		case $last in
			-m|--memory)	MEMORY=$i;;
			-c|--cpus)	CPUS=$i;;
			-s|--size)	SIZE=$i;;
			-p|--path)	ISOPATH=$i;;
			-h|--help)	printusage();;
		esac

		last=$i
	done

	if [ $VERB = "create" ] && [ $ISOPATH = "" ]; then
		echo "Specify path to ISO using -p."
	fi


else
	echo "Too few arguments. See --help."
	exit 1
fi

type xm >/dev/null 2>&1 || type xl >/dev/null 2>&1 || { echo >&2 "Xen administration tools not found. Aborting..."; exit 1; }
type lvm >/dev/null 2>&1 || { echo >&2 "lvm not found. Aborting..."; exit 1; }

printusage() {
	# TODO: write --help
	echo "USAGE"
	exit 0;
}

create() {
	if [ "$LVMPATH" != "" ]; then
		echo "Volume $LVMPATH already exists. Aborting..."
		exit 1
	fi

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
	vncpasswd=''
	usbdevice='tablet'" >> "$NAME.cfg"
	if [ $? -eq 0 ]; then
		echo -e '[\033[00;32mOK\033[00;0m]'
	else
		echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: Change FAIL colors to red
		echo "Config file $NAME.cfg could not be written. Aborting..."
		exit 1;
	fi

	printf "Booting $NAME (10 seconds)..."
	xl create "$NAME.cfg" > /dev/null 2>&1
	sleep 10;
	echo -e '[\033[00;32mOK\033[00;0m]'

	printf "Changing $NAME bootflag from 'd' (iso) to 'c' (disk)..."
	sed -i "10s/d/c/" $NAME.cfg
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
	lvremove $LVMPATH -f
	if [ $? -eq 0 ]; then
                echo -e '[\033[00;32mOK\033[00;0m]'
        else
		echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: Change FAIL colors to red
		echo "$LVMPATH could not be removed. Aborting..."
		exit 1;
        fi

        printf "Removing $NAME.cfg..."
        rm $NAME.cfg
        if [ $? -eq 0 ]; then
                echo -e '[\033[00;32mOK\033[00;0m]'
        else
                echo -e '[\033[00;32mFAIL\033[00;0m]' # TODO: change FAIL colors to red
                echo "$NAME.cfg could not be removed. Aborting..."
                exit 1;
        fi
}


printf "Checking for guest LVM volume..."
LVMPATH=$(lvdisplay | grep $NAME | grep "Path")
LVMPATH=${LVMPATH:25} # magic number for trimming lvdisplay output. TODO: use awk

# TODO: check if LVMPATH returned a volume, print OK or FAIL depending on $VERB
echo -e '[\033[00;32mOK\033[00;0m]'
#echo "Found LVM volume $LVMPATH."

printf "Checking for $NAME in xl..."
XENGUEST=$(xl list | grep $NAME)
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

#if [ "$LVMPATH" != "" ]; then 
#	[[ $VERB = "create" ]] || $VERB # call create()
#else [[ $VERB = "remove" ]] || $VERB # call remove()
#fi

$VERB # call create() or remove()

echo "Finished."
# TODO: if verb = create, echo $NAME created. else, echo $NAME removed.
echo -e "\n"
exit 0
