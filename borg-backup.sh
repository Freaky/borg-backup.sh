#!/bin/sh
#
# borg-backup.sh - BorgBackup shell script
#
# Author: Thomas Hurst <tom@hur.st>
#
# No warranty expressed or implied. Beware of dog. Slippery when wet.
# This isn't going to be your *only* backup method, right?
#
# Synopsis:
#
# $ touch /etc/borg-backup.conf && chmod go-rw /etc/borg-backup.conf
# $ cat >>/etc/borg-backup.conf
# TARGET=backup@host:/backups
# PASSPHRASE='incorrect zebra generator clip'
# BACKUPS='homes etc'
# BACKUP_homes='/home -e /home/bob/.trash'
# BACKUP_etc='/etc'
# # (also available: COMPRESSION, PRUNE
# ^D
# $ borg-backup.sh init
# $ borg-backup.sh create
# $ borg-backup.sh list
# $ borg-backup.sh help
# $ CONFIG=/etc/another-borg-backup.conf borg-backup.sh init

set -eu

: "${BORG:=/usr/local/bin/borg}"
: "${CONFIG:=/etc/borg-backup.conf}"
COMPRESSION='zlib'
PRUNE='-H 24 -d 14 -w 8 -m 6'

err() {
	echo "$@" 1>&2
	exit 78
}

usage() {
	echo "Borg:        $BORG"
	echo "Config:      $CONFIG"
	echo "Backups:     $BACKUPS"
	echo "Location:    $TARGET"
	echo "Compression: $COMPRESSION"
	echo "Pruning:     $PRUNE"
	echo
	echo "Usage:"
	echo " $0 help"
	echo " $0 init [backup]"
	echo " $0 create [backup]"
	echo " $0 list [backup]"
	echo " $0 check [backup]"
	echo " $0 prune [backup]"
	echo " $0 info backup archive"
	echo " $0 delete backup archive"
	echo " $0 borg backup [arbitrary borg command-line]"
	echo
	echo " e.g: $0 borg etc extract ::etc-2017-02-21T20:00 etc/rc.conf --stdout"
	exit "$1"
}

[ -z "$CONFIG" ] && err "CONFIG unset"
[ -r "$CONFIG" ] || err "CONFIG $CONFIG unreadable"
[ -f "$CONFIG" ] || err "CONFIG $CONFIG not a regular file"

# shellcheck disable=SC1090
. "$CONFIG"

[ -e "$BORG" ]          || err "$BORG not executable (see https://borgbackup.readthedocs.io/en/stable/installation.html)"
[ -z "$PRUNE" ]         && err "PRUNE not set (e.g. '-H 24 -d 14 -w 8 -m 6')"
[ -z "${PASSPHRASE-}" ] && err "PASSPHRASE not set (e.g. 'incorrect zebra generator clip')"
[ -z "${TARGET-}" ]     && err "TARGET not set (e.g. 'backup@host:/backup/path')"
[ -z "${BACKUPS-}" ]    && err "BACKUPS not set (e.g. 'homes etc')"

for B in $BACKUPS; do
	eval "DIRS=\$BACKUP_${B}"
	[ -z "${DIRS}" ] && err "BACKUP_${B} not set (e.g. '/home/bla -e /home/bla/.foo')"
done

export BORG_PASSPHRASE="$PASSPHRASE"

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M")

nargs=$#
cmd=${1-}
backup=${2-}
shift || true
shift || true

rc=0
for B in $BACKUPS; do
	if [ "$nargs" -eq 1 ] || [ "$backup" = "$B" ] ; then
		export BORG_REPO="${TARGET}/${B}.borg"
		eval "DIRS=\$BACKUP_${B}"
		case $cmd in
			init)
				$BORG init --encryption=repokey || rc=$?
			;;
			create)
				# shellcheck disable=SC2086
				$BORG create --exclude-caches --compression=${COMPRESSION} -v -s ::"${B}-${TIMESTAMP}" $DIRS || rc=$?
			;;
			list)
				$BORG list || rc=$?
			;;
			check)
				$BORG check || rc=$?
			;;
			prune)
				# shellcheck disable=SC2086
				$BORG prune -sv $PRUNE || rc=$?
			;;
			info)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG info ::"$3" || rc=$?
			;;
			delete)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG delete -s -p ::"$3" || rc=$?
			;;
			borg)
				[ "$nargs" -lt 2 ] && usage 64
				$BORG "${@}" || rc=$?
			;;
			help)
				usage 0
			;;
			*)
				usage 64

		esac
	fi
done

exit $rc

