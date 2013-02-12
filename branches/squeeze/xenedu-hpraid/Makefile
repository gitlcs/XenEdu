
#!/usr/bin/make -f

all:

install:
	# install conf files
	install -d $(DESTDIR)/etc
	#install -d $(DESTDIR)/etc/xenedu
	#install -d $(DESTDIR)/etc/xenedu/sudo.d
	#install -d $(DESTDIR)/etc/xen
	#install -d $(DESTDIR)/etc/xen/scripts
	cp -a etc/* $(DESTDIR)/etc/
	
	# install lib exemple
	install -d $(DESTDIR)/var/lib/xenedu
	cp -a lib/* $(DESTDIR)/var/lib
	# install sbin
	install -d $(DESTDIR)/sbin
	install -m 755 sbin/* $(DESTDIR)/sbin/

	# install home RSSH
	#install -d $(DESTDIR)/home/
	#install -d $(DESTDIR)/home/rssh
	#cp -a home/* $(DESTDIR)/home/
	
clean:


.PHONY: all install clean
