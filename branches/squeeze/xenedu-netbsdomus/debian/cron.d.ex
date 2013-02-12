#
# Regular cron jobs for the xenedu-netbsdomus package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-netbsdomus_maintenance ] && /usr/bin/xenedu-netbsdomus_maintenance
