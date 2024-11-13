#!/bin/bash

# Backup for Dovecot Imap sever
# Allan <bizcotti@gmail.com>
# November 11, 2024
#
# What this does:
#  1.) Backs up local IMAP account $ACCOUNT logically to a backup IMAP directory
#  2.) Creates an XZ compressed tar file of that account
#    2a.) On day zero, that tar archive is a full backup
#    2b.) Subsequent backups are differentials
#  3.) The backup is encrypted with GPG
#  4.) SHA256 sums are calculated
#  5.) The files are uploaded
#    5a.) On day zero, all remote differentials are deleted in advance
#    5b.) On all days remote copies are deleted before uploading

set -eEuo pipefail

declare ACCOUNT
ACCOUNT="$(git config 'user.email')"
# readonly ACCOUNT
declare PASSWD
PASSWD="$(sed -e 's/ .*//' < <(md5sum ~/.ssh/id_ed25519))"
readonly PASSWD
declare -r DESTDIR='/mnt/raid6/allan/backups'
declare -i SFX
SFX=$(($(date +%u) % 7))
readonly ACCOUNT PASSWD SFX
declare -r ARCHIVE="maildir-${SFX}.txz"
declare -r SNARCHV="maildir-${SFX}.snar"
declare -r GPGARCHIVE="${ARCHIVE}.gpg"
declare -r GPGSHA256="${GPGARCHIVE}.sha256"
declare -r TARSHA256="${ARCHIVE}.sha256"

create_archive(){
    declare archive="$1"
    declare snarchv="$2"
    declare archdir="$3"
    declare versfx="${snarchv#*-}"
    declare levelzero_snar='/dev/null'
    # $snarchv can end in 0 or 1,2,3 etc
    if [[ "${versfx:0:1}" == '0' ]]
    then
        echo "This is a level 0 archive, removing incremental file"
        test -f "${snarchv}" && rm "${snarchv}"
    else
        levelzero_snar="${snarchv/-?\./-0.}"
        if [[ -f "$levelzero_snar" ]]
        then
            echo "Copying ${levelzero_snar} to ${snarchv}"
            cp --force "${levelzero_snar}" "${snarchv}"
        else
            echo "Warning, file ${levelzero_snar} not found."
        fi
    fi
    XZ_OPT=-3 tar --create --xz --file="$archive" \
        --listed-incremental="${snarchv}" "${archdir}"
} # create_archive()

{
    date +"Start %F %T"
    # rsync -av --exclude '.Archive*' /home/vmail/allan.peda@gmail.com/Maildir/ /mnt/raid6/allan/backups/maildir/
    echo "Backing up email (maildir:${DESTDIR}/${ARCHIVE%-?.txz})"
    sudo doveadm backup -u "$ACCOUNT" -x "Archive*" "maildir:${DESTDIR}/${ARCHIVE%-?.txz}"
    cd "$DESTDIR"
    #
    echo "Archiving IMAP backup (${ARCHIVE})"
    test -f "${ARCHIVE}" && rm -f "${ARCHIVE}"
    create_archive "$ARCHIVE" "$SNARCHV" "${ARCHIVE%-?.txz}"
    stat --format "Archive is %s bytes" "$ARCHIVE"
    #
    echo "Calculating checksum of archive"
    sha256sum "$ARCHIVE" | tee "${DESTDIR}/$TARSHA256"
    test -f "${DESTDIR}/${GPGARCHIVE}" && rm -f "${DESTDIR}/${GPGARCHIVE}"
    #
    echo "Encrypting archive (${DESTDIR}/${GPGARCHIVE})"
    gpg -o "${DESTDIR}/${GPGARCHIVE}" --pinentry-mode loopback \
        --passphrase "$PASSWD" \
        --symmetric --cipher-algo AES256 "${ARCHIVE}"
    echo "Calculating checksum of encrypted archive"
    sha256sum "$GPGARCHIVE" | tee "$GPGSHA256"
    #
    if [[ $SFX -eq 0 ]]
    then
        echo "Level zero (full) archive, clearing old differential files."
        rclone delete "Mega:${ACCOUNT}/" --include "${ARCHIVE%-*}-[1-9]*"
    fi
    echo "Uploading $GPGSHA256"
    rclone delete "Mega:${ACCOUNT}/" --include "$GPGSHA256"
    rclone copyto "${DESTDIR}/$GPGSHA256"  "Mega:${ACCOUNT}/$GPGSHA256"
    rclone delete "Mega:${ACCOUNT}/" --include "$TARSHA256"
    rclone copyto "${DESTDIR}/$TARSHA256"  "Mega:${ACCOUNT}/$TARSHA256"
    echo "Uploading encrypted archive $GPGARCHIVE"
    rclone delete "Mega:${ACCOUNT}/" --include "$GPGARCHIVE"
    rclone copyto "${DESTDIR}/$GPGARCHIVE" "Mega:${ACCOUNT}/$GPGARCHIVE"
    echo "Cleaning up trash"
    rclone cleanup --verbose "Mega:${ACCOUNT}/"
    date +"End %F %T"
    cd - >/dev/null
} | tee -a "/tmp/${ARCHIVE%-?.txz}.log"
