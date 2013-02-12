#
# Regular cron jobs for the xenedu-nut package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-nut_maintenance ] && /usr/bin/xenedu-nut_maintenance
