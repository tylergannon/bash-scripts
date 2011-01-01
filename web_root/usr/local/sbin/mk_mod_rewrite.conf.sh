#################################################################
#
#   mk_mod_rewrite.conf.sh
#   
#   This script generates an apache configuration file for mod_rewrite
#   on the UCSF.edu web servers,
#   based on the paths found in the ee_legacy_urls table of the configured database.
#
#   Author: Tyler Gannon <tyler@medallurgy.com>
#   Written: 2010 - 12 - 14
#
#################################################################

filename='/etc/httpd/conf.d/mod_rewrite.gen.conf'
user='ucsfdrupal'
password='08$cuR3'
dbhost='dbpa.ucsf.edu'
db='ucsf_drupal_prod'
apache_restart_script='/etc/init.d/httpd'

tmpfile='/tmp/mod_rewrite.conf.tmp'

cat > $tmpfile <<EOQ
#################################################################
#
#   mod_rewrite configuration
#   
#   DO NOT EDIT THIS FILE DIRECTLY.
#   This file is auto-generated by the script, /usr/sbin/mk_mod_rewrite.conf.sh,
#   based on the paths found in the ee_legacy_urls table of the configured database.
#
#   Author: Tyler Gannon <tyler@medallurgy.com>
#
#   This file was created at `date`
#
#################################################################

RewriteEngine on
Options +FollowSymLinks

EOQ

get_hosts_query="select distinct left(replace(old_path, 'http://', ''), -1+position('/' in replace(old_path, 'http://', ''))) from ee_legacy_urls;"
for host in $(mysql -h $dbhost -p$password -u $user $db -sN -e "$get_hosts_query"); do
	count_rules_query="select count(1) from ee_legacy_urls where instr(old_path, '$host') > 0"
	rule_count=$(mysql -h $dbhost -p$password -u $user $db -sN -e "$count_rules_query")
	cat >> $tmpfile <<-EOQ
	
	
	  # Rewrite rules for $host
  	RewriteCond %{HTTP_HOST} !^${host/www\./(www\.)?} 	[NC]  
	  RewriteRule . - 				[S=$rule_count]
	EOQ

	rewrite_rules_query="select concat('RewriteRule ^/', substring(old_path, 8+position('/' in replace(old_path, 'http://', ''))), '$ /', new_path, ' [NC,R=301,L]') from ee_legacy_urls where instr(old_path, '$host') > 0;"
	mysql -h $dbhost -p$password -u $user $db -sN -e "$rewrite_rules_query" >> $tmpfile

	if [ $? -ne 0 ]; then 
	  echo Encountered an error getting data from the database.  Exiting.
	  exit 1
	fi	
done

echo Successfully generated new mod_rewrite configuration.  Going to overwrite $filename.
echo "I will save a copy of the old `basename $filename` at /etc/httpd/conf.backup/"
if [ -d /etc/httpd/conf.backup ]; then echo; else mkdir /etc/httpd/conf.backup; fi
cp $filename "/etc/httpd/conf.backup/`basename $filename`.`date +%Y%m%d`"
cp $tmpfile $filename
echo Ok, restarting Apache.  
$apache_restart_script restart
exit 0