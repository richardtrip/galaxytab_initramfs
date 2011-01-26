#!/sbin/busybox sh

rm /etc
mkdir /etc

sdcard_device='/dev/block/mmcblk0p1'
cache_partition='/dev/block/stl11'
dbdata_partition='/dev/block/stl10'
data_partition='/dev/block/mmcblk0p2'
system_partition='/dev/block/stl9'

generate_cwm_fstab()
{
	for x in cache datadata data system; do
		get_partition_for $x
		get_fs_for $x
		get_cwm_fstab_mount_option_for $fs
		echo "$partition /$x $fs $cwm_mount_options" >> /etc/fstab
		echo "/$x $fs $partition" >> /etc/recovery.fstab
	done

	# internal sdcard/USB Storage
	echo "$sdcard_device /sdcard vfat rw,uid=1000,gid=1015,iocharset=iso8859-1,shortname=mixed,utf8" >> /etc/fstab
	echo "/sdcard vfat $sdcard_device" >> /etc/recovery.fstab

	# external sdcard/USB Storage
	echo "/dev/block/mmcblk1p1 /sd-ext vfat rw,uid=1000,gid=1015,iocharset=iso8859-1,shortname=mixed,utf8" >> /etc/fstab
	echo "/sd-ext vfat /dev/block/mmcblk1p1" >> /etc/recovery.fstab
}

detect_all_filesystems()
{
	system_fs=`detect_fs_on system`
	dbdata_fs=`detect_fs_on dbdata`
	cache_fs=`detect_fs_on cache`
	data_fs=`detect_fs_on data`
}

detect_fs_on()
{
	resource=$1
	get_partition_for $resource
	log "filesystem detection on $resource:"
	if /sbin/tune2fs -l $partition 1>&2; then
		# we found an ext2/3/4 partition. but is it real ?
		# if the data partition mounts as rfs, it means
		# that this Ext4 partition is just lost bits still here
		log "Ext4 on $partition" 1
		echo ext4
		return
	fi
	log "RFS on $partition" 1
	echo rfs
}

get_partition_for()
{
	# resource partition getter which set a global variable named partition
	case $1 in
		cache)		partition=$cache_partition ;;
		dbdata)		partition=$dbdata_partition ;;
		datadata)	partition=$dbdata_partition ;;
		data)		partition=$data_partition ;;
		system)		partition=$system_partition ;;
	esac
}

get_fs_for()
{
	# resource filesystem getter which set a global variable named fs
	case $1 in
		cache)		fs=$cache_fs ;;
		dbdata)		fs=$dbdata_fs ;;
		datadata)	fs=$dbdata_fs ;;
		data)		fs=$data_fs ;;
		system)		fs=$system_fs ;;
	esac
}

get_cwm_fstab_mount_option_for()
{
	if test "$1" = "ext4"; then
		cwm_mount_options='journal=ordered,nodelalloc'
	else
		cwm_mount_options='check=no'
	fi
}

detect_all_filesystems

generate_cwm_fstab

rm /sdcard
mkdir /sdcard
busybox mount -t vfat /dev/block/mmcblk0p1 /sdcard

rmdir /sdcard/external_sd
mkdir /sdcard/external_sd
busybox mount -t vfat /dev/block/mmcblk1p1 /sdcard/external_sd

rm -rf /sdcard/.android_secure
if [ -d /sdcard/external_sd/.android_secure ];
then
  mkdir /sdcard/.android_secure
  busybox mount --bind /sdcard/external_sd/.android_secure /sdcard/.android_secure
fi;

