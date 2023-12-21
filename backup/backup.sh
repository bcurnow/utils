#!/bin/bash

function backupFiles() {
  local config=$1

  for entry in $(cat ${backupConfigDir}/${config})
  do
    echo -n "${backupConfigDir}/${config} - Backing up '${entry}' using '${rsyncFlags}'..."
    backupOutput=$(rsync ${rsyncFlags} ${entry} ${backupUser}@${backupHost}::${backupModule}/${currentHost}/ 2>&1)
    if [ 0 -eq $? ]
    then
      echo "complete"
    else
      echo "failed!"
      echo ${backupOutput}
    fi
  done
}

if [ $EUID -ne 0 ]
then
  echo "You must run this as root" >&2
  exit 1
fi

backupConfig=$1
backupUser=backup
backupPasswordFile=/etc/backup/passwd
backupHost=backup.internal.curnowtopia.com
currentHost=$(hostname)
backupModule=backup
backupConfigDir=/etc/backup/backup.d
rsyncFlags="--password-file ${backupPasswordFile} -aqc --perms --delete-after --relative"

echo "Backing up ${currentHost} to ${backupModule} on ${backupHost}"
if [ -n "${backupConfig}" ]
then
  backupFiles ${backupConfig}
else
 for backupConfig in $(ls -1 ${backupConfigDir})
  do
    backupFiles ${backupConfig}
  done
fi

