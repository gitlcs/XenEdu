
#!/usr/bin/make -f

all:

install:
	# install conf files
	install -d $(DESTDIR)/etc
	install -d $(DESTDIR)/etc/xenedu
	install -d $(DESTDIR)/etc/xenedu/sudo.d
	install -d $(DESTDIR)/etc/xen
	install -d $(DESTDIR)/etc/xen/scripts
	#cp -a etc/* $(DESTDIR)/etc/
	
	# install NetBSD domu kernel
	install -d $(DESTDIR)/boot
	install -d $(DESTDIR)/boot/netbsd-amd64
	install -d $(DESTDIR)/boot/netbsd-i386
	cp -a boot/* $(DESTDIR)/boot/
	
	# install lib exemple
	install -d $(DESTDIR)/var/lib/xenedu
	cp -a lib/* $(DESTDIR)/var/lib/xenedu
	# install sbin
	install -d $(DESTDIR)/sbin
	install -m 755 sbin/* $(DESTDIR)/sbin/

clean:


.PHONY: all install clean
