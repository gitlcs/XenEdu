#
# Regular cron jobs for the xenedu-hpraid package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-hpraid_maintenance ] && /usr/bin/xenedu-hpraid_maintenance
