#!/bin/zsh

set -eu

usage() {
    print -u2 'Usage: manage.sh [--install | --uninstall] --url smb://user@host/share [--interval seconds]'
}

mode=dry-run
smb_url=''
interval=30
explicit_mode=''

while (( $# > 0 )); do
    case "$1" in
        --install)
            [[ -z $explicit_mode ]] || { print -u2 'Choose only one of --install or --uninstall.'; exit 64; }
            mode=install
            explicit_mode=install
            ;;
        --uninstall)
            [[ -z $explicit_mode ]] || { print -u2 'Choose only one of --install or --uninstall.'; exit 64; }
            mode=uninstall
            explicit_mode=uninstall
            ;;
        --url)
            (( $# >= 2 )) || { usage; exit 64; }
            smb_url=$2
            shift
            ;;
        --interval)
            (( $# >= 2 )) || { usage; exit 64; }
            interval=$2
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 64 ;;
    esac
    shift
done

[[ $(uname -s) == Darwin ]] || { print -u2 'This installer requires macOS.'; exit 69; }
[[ $smb_url == smb://*/* ]] || { print -u2 'URL must start with smb:// and include a share.'; exit 64; }
[[ $smb_url != *$'\n'* && $smb_url != *$'\r'* ]] || { print -u2 'URL contains control characters.'; exit 64; }
[[ $interval == <-> ]] && (( interval >= 15 )) || { print -u2 'Interval must be an integer of at least 15 seconds.'; exit 64; }

authority=${${smb_url#smb://}%%/*}
if [[ $authority == *@* ]]; then
    user_info=${authority%@*}
    [[ $user_info != *:* ]] || { print -u2 'Password-like user info is not allowed; use Keychain.'; exit 64; }
fi

script_dir=${0:A:h}
worker_source="$script_dir/reconnect-worker.sh"
[[ -f $worker_source ]] || { print -u2 "Missing worker: $worker_source"; exit 66; }

job_id=$(print -rn -- "$smb_url" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print substr($1,1,12)}')
label="io.sofunny.macos-nas-reconnect.$job_id"
support_dir="$HOME/Library/Application Support/sofunny-macos-nas-reconnect"
worker_target="$support_dir/$job_id.sh"
state_file="$support_dir/$job_id.failures"
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

print "Mode: $mode"
print "URL: $smb_url"
print "Interval: $interval seconds"
print "Label: $label"
print "LaunchAgent: $plist"

[[ $mode != dry-run ]] || exit 0

if [[ $mode == uninstall ]]; then
    /bin/launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
    /bin/rm -f "$plist" "$worker_target" "$state_file"
    print 'Uninstalled. The current SMB mount was left unchanged.'
    exit 0
fi

xml_escape() {
    /usr/bin/printf '%s' "$1" | /usr/bin/sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g'
}

/bin/mkdir -p "$support_dir" "$HOME/Library/LaunchAgents"
/bin/cp "$worker_source" "$worker_target"
/bin/chmod 700 "$worker_target"

escaped_label=$(xml_escape "$label")
escaped_worker=$(xml_escape "$worker_target")
escaped_url=$(xml_escape "$smb_url")
escaped_state=$(xml_escape "$state_file")
temp_plist=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/nas-reconnect.XXXXXX")
trap '/bin/rm -f "$temp_plist"' EXIT

/bin/cat > "$temp_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$escaped_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$escaped_worker</string>
        <string>$escaped_url</string>
        <string>$escaped_state</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>$interval</integer>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$temp_plist" >/dev/null
/bin/cp "$temp_plist" "$plist"
/bin/chmod 600 "$plist"
/bin/launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "$domain" "$plist"
print "Installed. Verify with: launchctl print $domain/$label"
