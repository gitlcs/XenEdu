#
# Regular cron jobs for the xenedu-windomus package
#
0 4	* * *	root	[ -x /usr/bin/xenedu-windomus_maintenance ] && /usr/bin/xenedu-windomus_maintenance
