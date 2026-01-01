#!/usr/local/bin/bash
# Time-stamp: <>

# Backup essential configuration files
# Must run as root
set -eEuo pipefail

# de sure to skip
# /etc/ssl/private/ or /etc/ssl/certs/private

datenow="$(date '+%Y-%m-%d')"
backup="/tmp/config-backup-${datenow}.tar"
backup_listing="/tmp/config-backup-${datenow}.toc"
full_listing="/tmp/config-full-${datenow}.toc"
skip_listing="/tmp/config-skip-${datenow}.toc"
# paths to search
patharray=("/etc/" "/usr/local/" "/var/lib/radicale/")
echo "Generating full listing"
find "${patharray[@]}" -type f > "$full_listing"
echo "Generating omit listing"
find "${patharray[@]}" -type f \
     \( -path /etc/spwd.db \
     -o -path /etc/pwd.db \
     -o -path /etc/master.passwd \
     -o -path '/etc/ssh/*key' \) \
     | sed -e 's/^/^/; s/$/$/' >  "$skip_listing"

# save list of what was omitted in the archive
echo "$skip_listing" > "$backup_listing"

echo "Using the omitted listing to generate the backup list"
grep -v -f "$skip_listing" "$full_listing" >> "$backup_listing"
# save what we skipped in the tarfile

echo "Running tar -cf $backup -I ${backup_listing}"
tar -cf "$backup" -I "$backup_listing"
echo "Archive created, now compressing"
xz --verbose "$backup"
