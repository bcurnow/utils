#!/bin/bash

backupUser=backup
backupPasswordFile=/etc/backup/passwd
backupHost=backup.internal.curnowtopia.com
currentHost=$(hostname)
backupModule=backup-${currentHost}
backupConfig=/etc/backup/backup.d
rsyncFlags="--password-file ${backupPasswordFile} -aqc --perms --delete-after --relative"

echo "Backing up ${currentHost} to ${backupModule} on ${backupHost}"

exitCode=0

for config in $(ls -1 ${backupConfig})
do
  echo "Processing config entry '${backupConfig}/${config}'"
  for entry in $(cat ${backupConfig}/${config})
  do
    echo -n "Backing up '${entry}' using '${rsyncFlags}'..."
    ret=$(rsync ${rsyncFlags} ${entry} ${backupUser}@${backupHost}::${backupModule} 2>&1)
    if [ $? -eq 0 ]
    then
      echo "complete"
    else
      echo "failed!"
      echo ${ret}
      exitCode=1
    fi
  done
done
