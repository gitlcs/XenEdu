#!/usr/bin/perl -w
#
#  Create a new Xen instances containing an installation of Debian
#
#  This is a reasonably simple script which is more of a cheap hack
# than a production tool, however it does appear to work nicely for
# my own uses.
#
#  The output of this script will be two files for each new instance:
#
#   1.  One 2Gb file for the installations primary disk image.
#   2.  One 128Mb file for the images swap partition.
#
#  Usage:
#
# ./create-xen-image.pl --hostname='vm03' --name='sql' \
#   --ip=192.168.1.93 --gateway=192.168.1.1 \
#   --network=192.168.1.0 --mask=255.255.255.0 \
#
#  The initial two arguments '--hostname' and '--dir' are mandatory,
# and control the hostname and output directory respectively.  Other
# parameters are all network based, either give the list as shown above
# or use the '--dhcp' option to setup the host with a DHCP allocated
# IP address.
#
#  Basic setup with your hosts file, resolv.conf, etc works just fine.
#
#  The image will also have an OpenSSH server installed upon it, and
# an appropriate /etc/inittab file created.
#
#  You are *strongly* advised to chroot() into the new instance once
# it has been setup to prune the users in the /etc/passwd file which
# will be copied from your hosts system.
#
#
# Steve
# --
# http://www.steve.org.uk/
#
# $Id: create-xen-image.pl,v 1.16 2006/09/20 08:33:20 steve Exp $
#

use strict;
use File::Copy;
use File::Temp qw/ tempdir /;

use Getopt::Long;


#
#  Print message and exit.
#
#  This script is now replaced by:
#
#      http://www.steve.org.uk/Software/xen-tools/
#
#
#print "\n This script has been superceeded by: \n\n";
#print "Xen-Tools:\n";
#print "  http://www.steve.org.uk/Software/xen-tools/\n";
#print " \n";
#print "(You may remove this message and continue using this script if you wish)\n\n";
#exit;

#
# Options set on the command line.
#
my $HOSTNAME;   # Mandatory.
my $DIR;        # Mandatory.


#
# Either *all* the relevant networking options must be setup, or
# DHCP must be selected.
#
#
my $IP;                        # set with '--ip=dd.dd.dd.dd'
my $GATEWAY;                   # set with '--gateway=dd.dd.dd.dd'
my $NETMASK="255.255.255.0";   # set with '--mask=dd.dd.dd.dd'
my $BROADCAST="192.168.254.255"; # set with '--broadcase=ddd.dd.dd.d'
my $NETWORK="192.168.1.0";     # set with '--network=dd.dd.dd.dd'
my $xname="test";              # set with '--name=test'
my $DHCP=0;                    # This setting overides the other options

#
#  Parse options.
#
        print "HOSTAME: ";
        chomp($HOSTNAME = <STDIN>);
        print "\n";
        print "IP: ";
        chomp($IP = <STDIN>);
        print "\n";
        print "GATEWAY: ";
        chomp($GATEWAY = <STDIN>);
        print "\n";
        print "MASK: ";
        chomp($NETMASK = <STDIN>);
        print "\n";
        print "BROADCAST: ";
        chomp($BROADCAST = <STDIN>);
        print "\n";
        print "NETWORK: ";
        chomp($NETWORK = <STDIN>);
        print "\n";
        print "NAME: ";
        chomp($xname = <STDIN>);
        print "\n";

#
#  Check that the arguments the user has supplied are both 
# valid, and complete.
#
checkArguments();



#
#  If the output directories don't exist then create them.
#
if ( ! -d $DIR . "/domains/" )
{
    mkdir $DIR . '/domains', 0777
      || die "Cannot create $DIR/domains - $!";
}
if ( ! -d $DIR . "/domains/" . $HOSTNAME )
{
    mkdir $DIR. '/domains/' . $HOSTNAME, 0777
      || die "Cannot create $DIR/domains/$HOSTNAME - $!" ;
}



#
# The two images we'll use, one for the disk image, one for swap.
#
my $image = "/dev/VirtualsCows/".$xname."-root" ;
my $swap  = "/dev/VirtualsCows/".$xname."-swp" ;
my $imgvar  = "/dev/VirtualsCows/".$xname."-var" ;

#
#  Create swapfile and initialise it.
#
print "Creating swapfile : $swap\n";
`/bin/dd if=/dev/zero of=$swap bs=1024k count=128 >/dev/null 2>/dev/null`;
print "Initializing swap file\n";
`/sbin/mkswap $swap`;
print "Done\n";

#
#  Create disk file and initialise it.
#
print "Creating disk image: $image\n";
`/bin/dd if=/dev/zero of=$image bs=2M count=1 seek=1024 >/dev/null 2>/dev/null`;
print "Creating EXT3 filesystem\n";
`/sbin/mkfs.ext3 -F $image`;
print "Done\n";
print "Creating disk image var: $image\n";
`/bin/dd if=/dev/zero of=/dev/vol0/$imgvar bs=2M count=1 seek=1024 >/dev/null 2>/dev/null`;
print "Creating EXT3 filesystem\n";
`/sbin/mkfs.ext3 -F $imgvar`;
print "Done\n";


#
#  Now mount the image, in a secure temporary location.
#
my $dir = tempdir( CLEANUP => 1 );
`mount -t ext3 $image $dir`;
`mkdir $dir/var`;
`mount -t ext3 $imgvar $dir/var`;

#
# Test that the mount worked
#
if ( ! -d $dir . "/lost+found" )
{
    print "Something went wrong trying to mount the new filesystem\n";
    exit;
}

#
#  Install the base system.
#
print "Running debootstrap to install the system.   This will take a while!\n";
`debootstrap --arch amd64 lenny $dir ftp://ftp2.fr.debian.org/debian`;
print "Done\n";

#
#  If the debootstrap failed then we'll setup the output directories
# for the configuration files here.
#
`mkdir -p $dir/etc/apt`;
`mkdir -p $dir/etc/network`;

#
#  OK now we can do the basic setup.
#
print "Setting up APT sources .. ";
open( APT, ">", $dir . "/etc/apt/sources.list" );
print APT<<E_O_APT;
#
#  /etc/apt/sources.list
#


# Stable
deb http://ftp2.fr.debian.org/debian     lenny main contrib non-free
deb-src http://ftp2.fr.debian.org/debian lenny main contrib non-free

# 
#  Security updates
#
deb     http://security.debian.org/ lenny/updates  main contrib non-free
deb-src http://security.debian.org/ lenny/updates  main contrib non-free


E_O_APT
close( APT );

print "Done\n";



#
#  Copy some files from the host system, after setting up the hostname.
#
#
`echo '$HOSTNAME' > $dir/etc/hostname`;

my @hostFiles = ( "/etc/resolv.conf",
                  "/etc/hosts",
                  "/etc/passwd",
                  "/etc/group",
                  "/etc/shadow",
                  "/etc/gshadow" );

foreach my $file ( @hostFiles )
{
    File::Copy::cp( $file, $dir . "/etc" );
}


#
#  Disable TLS
#
if ( -d $dir . "/lib/tls" ) 
{
    `mv $dir/lib/tls $dir/lib/tls.disabled`;
}


#
#  Now setup the IP address
#
print "Setting up IP address .. ";
open( IP, ">", $dir . "/etc/network/interfaces" );
print IP<<E_O_IP;
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
E_O_IP

if ( $DHCP )
{
    print IP "iface eth0 dhcp\n";
}
else
{
    print IP <<E_O_STATIC;
iface eth0 inet static
 address $IP
 gateway $GATEWAY
 netmask $NETMASK
 network $NETWORK
 broadcast $BROADCAST
E_O_STATIC
}

close( IP );

print "Done\n";



#
#  Now setup the fstab
#
print "Setting up /etc/fstab .. ";
open( TAB, ">", $dir . "/etc/fstab" );
print TAB<<E_O_TAB;
/dev/sda1     /     ext3     errors=remount-ro     0     1
/dev/sda2     /var     ext3     errors=remount-ro     0     1
/dev/sda3     none  swap     sw                    0     0
proc          /proc proc     defaults              0     0
E_O_TAB
close( TAB );

print "Done\n";




#
#  Install OpenSSH
#
installOpenSSH();

#
#  Fixup Inittab file
#
fixupInittab();



#
#  Now unmount the image.
#
`umount $dir/var`;
`umount $dir`;


#
# Finally setup Xen to allow us to create the image.
#
print "Setting up Xen configuration file .. ";
open( XEN, ">", "/etc/xen/$HOSTNAME.cfg" );
print XEN<<E_O_XEN;
kernel = "/boot/vmlinuz-2.6.18.8-xen"
ramdisk = "/boot/initrd.img-2.6.18.8-xen"
memory = 256
name   = "$HOSTNAME"
vif = [ '' ]
disk   = [ 'phy:$image,sda1,w','phy:$imgvar,sda2,w','phy:$swap,sda3,w' ]
root   = "/dev/sda1 ro"
extra = "4 xencons=tty"
E_O_XEN
if ( $DHCP )
{
    print XEN "dhcp=\"dhcp\"\n";
}
else
{
    print XEN "#dhcp=\"dhcp\"\n";
}
close( XEN );

print "Done\n";


#
#  Give status message
#
print <<EOEND;

  To finish the setup of your new host $HOSTNAME please run:

    mkdir /mnt/tmp
    mount -t ext3 $image /mnt/tmp

    chroot /mnt/tmp /bin/bash

    # Get security upgrades.
    apt-get upgrade

    # setup passwords, etc.
    passwd root

    # Cleanup.
    exit
    umount /mnt/tmp

 Once completed you may start your new instance of Xen with:

    xm create $HOSTNAME.cfg -c

EOEND




=head2 checkArguments

  Check that the arguments the user has specified are complete and
 make sense.

=cut

sub checkArguments
{

    if (!defined( $HOSTNAME ) )
    {
        print<<EOF

  You should set a hostname with '--hostname=foo'.

  This option is required.
EOF
      ;
        exit;
    }


    if (!defined( $xname ) )
    {
        print<<EOF

  You should set a machine name with '--name=myname'.

EOF
          ;
        exit;
    }



    #
    #  Make sure the directory exists.
    #


    #
    #  Only one of DHCP / IP is required.
    #
    if ( $DHCP && $IP )
    {
        print "You've chosen both DHCP and an IP address.\n";
        print "Only one is supported\n";
        exit;
    }

    if ( $DHCP )
    {
        $GATEWAY="";
        $NETMASK="";
        $BROADCAST="";
        $IP="";
    }
}




=head2 installOpenSSH

  Install OpenSSH upon the virtual instance.

=cut

sub installOpenSSH
{
    `chroot $dir /usr/bin/apt-get update`;
    `DEBIAN_FRONTEND=noninteractive chroot $dir /usr/bin/apt-get --yes --force-yes install ssh`;
    `chroot $dir /etc/init.d/ssh stop`;
}


=head2 fixupInittab

  Copy the host systems /etc/inittab to the virtual installation 
 making a couple of minor changes:

  1. Setup the first console to be "Linux".
  2. Disable all virtual consoles.

=cut 

sub fixupInittab
{
    my @init;
    open( INITTAB, "<", "/etc/inittab" );
    foreach my $line ( <INITTAB> )
    {
        chomp $line;
        if ( $line =~ /:respawn:/ )
        {
            if ( $line =~ /^1/ )
            {
                #$line = "s0:12345:respawn:/sbin/getty 115200 ttyS0 linux"
                $line = "1:2345:respawn:/sbin/getty 38400 tty1"
            }
            else
            {
                $line = "#" . $line;
            }
        }
        push @init, $line;
    }
    close( INITTAB );
    
    
    open( OUTPUT, ">", "$dir/etc/inittab" );
    foreach my $line ( @init )
    {
        print OUTPUT $line . "\n";
    }
    close( OUTPUT )
}
