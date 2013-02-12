#
# Regular cron jobs for the xenedu-base package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-base_maintenance ] && /usr/bin/xenedu-base_maintenance
