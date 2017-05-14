# xen-tools
A collection of scripts designed to automate some Xen-related tasks.

## xen-provision.sh

A script that can either create or remove HVM guests. The script was written using the Xen Project [Beginner's Guide](https://wiki.xenproject.org/wiki/Xen_Project_Beginners_Guide).

Dependencies: lvm and xl

Usage:	./xen-provision.sh create
	./xen-provision.sh remove

Options:
	-n, --name: Name of the guest
	-m, --memory: Memory in megabytes to allocate
	-c, --cpus: CPU cores to allocate
	-s, --size: Size of LVM volume in megabytes
	-p, --path: Path to ISO to boot the guest from. Does not need to be absolute. The script will resolve absolute paths.

All options have default values except -p, which must be specified.
