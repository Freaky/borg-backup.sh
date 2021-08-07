#!/bin/sh
#
# borg-backup.sh - BorgBackup shell script
#
# Copyright (c) 2017 Thomas Hurst <tom@hur.st>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
###############################################################################
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

BORG_BACKUP_SH_VERSION="0.6.0-pre"

: "${BORG:=/usr/local/bin/borg}"
: "${CONFIG:=/etc/borg-backup.conf}"
COMPRESSION='zlib'
PRUNE='-H 24 -d 14 -w 8 -m 6'

err() {
	echo "$@" 1>&2
	exit 78
}

usage() {
	echo "borg-backup.sh $BORG_BACKUP_SH_VERSION"
	echo
	echo "Configuration:"
	echo "  Borg:        $BORG"
	echo "  Config:      $CONFIG"
	echo "  Backups:     $BACKUPS"
	echo "  Location:    $TARGET"
	echo "  Compression: $COMPRESSION"
	echo "  Pruning:     $PRUNE"
	echo
	echo "Usage:"
	echo " $0 help"
	echo " $0 init [BACKUP]"
	echo " $0 create [BACKUP]"
	echo " $0 list [BACKUP]"
	echo " $0 check [BACKUP]"
	echo " $0 quickcheck [BACKUP]"
	echo " $0 repocheck [BACKUP]"
	echo " $0 prune [BACKUP]"
	echo " $0 break-lock [BACKUP]"
	echo " $0 extract BACKUP [borg extract command]"
	echo " $0 info BACKUP ARCHIVE"
	echo " $0 delete BACKUP ARCHIVE"
	echo " $0 borg BACKUP [arbitrary borg command-line]"
	echo
	echo " e.g: $0 borg etc extract ::etc-2017-02-21T20:00Z etc/rc.conf --stdout"
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
	eval "DIRS=\${BACKUP_${B}-}"
	[ -z "${DIRS}" ] && err "BACKUP_${B} not set (e.g. '/home/bla -e /home/bla/.foo')"
done

export BORG_PASSPHRASE="$PASSPHRASE"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%MZ")

nargs=$#
cmd=${1-}
backup=${2-}
if [ "$#" -gt 0 ]; then shift; fi
if [ "$#" -gt 0 ]; then shift; fi

rc=0
for B in $BACKUPS; do
	if [ "$nargs" -eq 1 ] || [ "$backup" = "$B" ] ; then
		export BORG_REPO="${TARGET}/${B}.borg"
		eval "DIRS=\$BACKUP_${B}"
		case $cmd in
			init)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG init --encryption=repokey || rc=$?
			;;
			create)
				[ "$nargs" -gt 2 ] && usage 64
				# shellcheck disable=SC2086
				$BORG create --exclude-caches --compression=${COMPRESSION} -v -s ::"${B}-${TIMESTAMP}" $DIRS || rc=$?
			;;
			list)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG list || rc=$?
			;;
			check)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v || rc=$?
			;;
			quickcheck)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v --last=1 || rc=$?
			;;
			repocheck)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG check -v --repository-only || rc=$?
			;;
			prune)
				[ "$nargs" -gt 2 ] && usage 64
				eval "THIS_PRUNE=\${PRUNE_${B}-\${PRUNE}}"
				# shellcheck disable=SC2086
				$BORG prune -sv $THIS_PRUNE || rc=$?
			;;
			info)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG info ::"$1" || rc=$?
			;;
			delete)
				[ "$nargs" -ne 3 ] && usage 64
				$BORG delete -s -p ::"$1" || rc=$?
			;;
			extract)
				[ "$nargs" -lt 3 ] && usage 64
				$BORG extract "$@" || rc=$?
			;;
			break-lock)
				[ "$nargs" -gt 2 ] && usage 64
				$BORG break-lock || rc=$?
			;;
			borg)
				[ "$nargs" -lt 2 ] && usage 64
				$BORG "$@" || rc=$?
			;;
			help|--help|-h)
				usage 0
			;;
			*)
				usage 64
		esac
	fi
done

exit $rc

