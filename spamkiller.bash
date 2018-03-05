#!/bin/bash

<<DOC
 Description:
        Run this script without any arguments against server where exim queue is full. This script
        searches for known PHP spamming scripts (see: signatures, filepattern) within users directories
        where spam emails are originating from. If such scripts are detected then they are printed
        and mode 000 is applied.

 Usage:
        cat <this-script>.bash | ssh -T <target-server>

        Note: ssh -T disable psudo TTY allocation but not required.

 Bugs:
        Please report to https://github.com/tuladhar/spamkiller.bash
DOC

# uncomment for debugging
#set -x

# search for known spam script signatures (regex) only in those scripts matching the filepattern (regex)
# add more spam scripts signature here as regex.
SIGNATURES='\$t60=\"|base64_decode\";return|\"64_decode\";return|\(base64_decode \(|\"base\" \. \"64_decode\"'
# add more spam scripts file pattern here as regex
FILEPATTERN=".*(php|php\.suspected)$"

HOSTNAME=`hostname -s`
function xecho() { level='*'; msg="$1"; echo "[$level] [$HOSTNAME] $msg"; }

# colors
export TERM=dumb
color_red()   { printf '\033[31m'; }
color_green() { printf '\033[32m'; }
color_blue()  { printf '\033[36m'; }
color_reset() { printf '\033[00m'; }

color_blue
xecho "Script started on server $HOSTNAME."
color_reset

# start timer
START_TIMER=$(date +%s);

# top 5 local mail senders (ordered by email count)
xecho "Searching for top 5 local senders (users) by message count..."

top_users_msg_count=$(eximstats -t5 -ne -nr -nt -nvr /var/log/exim_mainlog \
        | grep -A7 'Top 5 local senders by message count' \
        | egrep -v "root|mailnull|Top |^-|sender" \
        | tail -5 | awk '{print $NF "=("$1")"}');

top_users=$(echo $top_users_msg_count \
        | tr ' ' '\n' | tr '=' ' ' | awk '{print $1}' \
        | tr '\n' ' ' | tr -d '()' | uniq);

xecho "Top 5 local senders (order by message count):"
echo $top_users_msg_count | tr ' ' '\n' | tr '=' ' ' \
        | grep -v '()' | egrep -v '^\n' | uniq | cat -n;

for user in $top_users
do
        [ -z "$user" ] && continue
        xecho "[$user] Searching for spam directory(s) for user $user..."
        
        grep -sq $user /etc/userdomains
        [ $? -ne 0 ] && { xecho "[$user] Oops! not a cpanel user. skipping..." ; continue; }

        dirs=$(grep cwd /var/log/exim_mainlog* \
                | grep -v /var/spool \
                | awk -F'cwd=' '{print $2}' \
                | awk '{print $1}' | sort | uniq -c \
                | sort -n | awk -F ' ' '{print $2}' \
                | grep home | grep $user | egrep -v public_html$ | grep public_html);

        if [ -z "$dirs" ]
        then
                xecho "[$user] No directory found."
        else
                xecho "[$user] Directory(s) found:"
                echo "$dirs" | tr ' ' '\n' | cat -n
        
                xecho "[$user] Searching for spam scripts in above directories..." 
                
                color_red
                for dir in $dirs
                do
                        # skip if directory doesn't exists
                        [ -e "$dir" ] || continue
                        find "$dir" -regextype posix-extended -iregex "$FILEPATTERN" -type f \
                        | sort | uniq | xargs -I % egrep -l "$SIGNATURES" "%" \
                        | xargs -I % bash -c "ls -l '%'; chmod -c 000 '%';";
                done
                color_reset
        fi
        xecho "[$user] Search completed for user $user."
done

# clear frozen mail queue
color_green
xecho "Clearing mail queue (frozen only) ..."; size=$(exim -bpc)
xecho "Cleared: $(exiqgrep -z -i | xargs -I % -P10 exim -Mrm '%' | wc -l) of $size, Current: $(exim -bpc) (Non-frozen: $(exiqgrep -x -i | wc -l))"
color_reset

# end timer
END_TIMER=$(date +%s)
let ELAPSED="${END_TIMER}-${START_TIMER}"

color_blue
xecho "Script completed in $ELAPSED seconds."
color_reset

exit 0
