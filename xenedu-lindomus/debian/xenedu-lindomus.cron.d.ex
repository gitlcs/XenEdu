#
# Regular cron jobs for the xenedu-lindomus package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-lindomus_maintenance ] && /usr/bin/xenedu-lindomus_maintenance
