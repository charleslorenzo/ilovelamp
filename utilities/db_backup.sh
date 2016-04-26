#!/bin/bash

backup_parent_dir="/var/www/scheduled/backups"
website_root_dir="/var/www/html/NAME_HERE"
site_name="NAME_HERE"
dropbox_client_name="DROPBOX_CLIENT_FOLDER_NAME"
dropbox_api_key="API_KEY"

# MySQL settings
mysql_user="USERNAME"
mysql_password="PASSWORD"

# Read MySQL password from stdin if empty
if [ -z "${mysql_password}" ]; then
  echo -n "Enter MySQL ${mysql_user} password: "
  read -s mysql_password
  echo
fi

# Check MySQL password
echo exit | mysql --user=${mysql_user} --password=${mysql_password} -B 2>/dev/null
if [ "$?" -gt 0 ]; then
  echo "MySQL ${mysql_user} password incorrect"
  exit 1
else
  echo "MySQL ${mysql_user} password correct."
fi

# Create backup directory and set permissions
backup_date=`date +%Y_%m_%d_%H_%M`
backup_dir="${backup_parent_dir}/${backup_date}"
echo "Backup directory: ${backup_dir}"
mkdir -p "${backup_dir}"
chmod 700 "${backup_dir}"

# Get MySQL databases
mysql_databases=`echo 'show databases' | mysql --user=${mysql_user} --password=${mysql_password} -B | sed /^Database$/d`

# Backup and compress each database
for database in $mysql_databases
do
  if [ "${database}" == "information_schema" ] || [ "${database}" == "performance_schema" ] || [ "${database}"  == "mysql" ]; then
  :

  else
  echo "Creating backup of \"${database}\" database"
  mysqldump ${additional_mysqldump_params} --user=${mysql_user} --password=${mysql_password} ${database} | gzip > "${backup_dir}/${database}.sql.gz"
  chmod 600 "${backup_dir}/${database}.sql.gz"
fi
done

# Backup and compress site files
tar -zcvf "${backup_dir}/${site_name}_site_files.tar.gz" "${website_root_dir}"
chmod 600 "${backup_dir}/${site_name}_site_files.tar.gz"
# Compress DB and site files
tar -zcvf "${site_name}-${backup_date}.tar.gz" "${backup_dir}"

# Send to compressed backup directory to dropbox
uploadURL="https://content.dropboxapi.com/2/files/upload"
header1="Authorization: Bearer ${dropbox_api_key}"
header2="Content-Type: application/octet-stream"
header3="Dropbox-API-Arg: {\"path\":\"/semgeeks clients/${dropbox_client_name}/Web/Backups/${site_name}-${backup_date}.tar.gz\", \"mode\": \"add\"}"
file="@${site_name}-${backup_date}.tar.gz"

curl -X "POST" --header "${header1}" --header "${header2}" --header "${header3}" --data-binary "${file}" ${uploadURL}
