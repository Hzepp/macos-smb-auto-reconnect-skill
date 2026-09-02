#!/bin/zsh

set -u

PATH=/usr/bin:/bin:/usr/sbin:/sbin

if (( $# != 2 )); then
    exit 64
fi

smb_url=$1
state_file=$2
remote=${smb_url#smb://}
endpoint=${remote#*@}

mount_line=$(/sbin/mount | /usr/bin/grep -F -- "@${endpoint} on " | /usr/bin/head -n 1)

if [[ -n $mount_line ]]; then
    mount_point=${mount_line#* on }
    mount_point=${mount_point% (smbfs*}

    if /usr/bin/smbutil statshares -m "$mount_point" -f json >/dev/null 2>&1; then
        /bin/rm -f "$state_file"
        exit 0
    fi

    failures=0
    if [[ -r $state_file ]]; then
        failures=$(<"$state_file")
        [[ $failures == <-> ]] || failures=0
    fi
    (( failures += 1 ))
    /usr/bin/printf '%s\n' "$failures" > "$state_file"

    # Avoid reacting to a single transient probe failure.
    if (( failures < 2 )); then
        exit 75
    fi

    if ! /sbin/umount "$mount_point" >/dev/null 2>&1; then
        exit 73
    fi
    /bin/rm -f "$state_file"
else
    /bin/rm -f "$state_file"
fi

/usr/bin/osascript - "$smb_url" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
    mount volume (item 1 of argv)
end run
APPLESCRIPT
