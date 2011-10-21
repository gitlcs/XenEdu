#!/usr/bin/perl -w
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
my $HOSTNAME="debian-squeeze";   # Mandatory.
#my $DIR;        # Mandatory.

#
# Either *all* the relevant networking options must be setup, or
# DHCP must be selected.
#
#
my $IP;                        # set with '--ip=dd.dd.dd.dd'
my $GATEWAY;                   # set with '--gateway=dd.dd.dd.dd'
my $NETMASK="255.255.255.0";   # set with '--mask=dd.dd.dd.dd'
my $BROADCAST="192.168.1.255"; # set with '--broadcase=ddd.dd.dd.d'
my $NETWORK="192.168.1.0";     # set with '--network=dd.dd.dd.dd'
my $xname="squeeze";              # set with '--name=test'
my $xmemory="512";
my $DHCP=0;                    # This setting overides the other options
my $XENMAC=`xenedu-mac-generator`;  # Mac Address for SE3
my $XENCPUS=1;
$XENMAC=`echo -n $XENMAC`;
#
#  Parse options.
#
        print "IP: ";
        chomp($IP = <STDIN>);
        print "\n";
        print "MASK: ";
        chomp($NETMASK = <STDIN>);
	print "\n";
        print "GATEWAY: ";
        chomp($GATEWAY = <STDIN>);
        print "\n";
        print "Memoire RAM a allouer(en MB) : ";
        chomp($xmemory = <STDIN>);
        print "\n";
	print "indiquer le nombre de CPUs a allouer : ";
	chomp($XENCPUS = <STDIN>);
        print "\n";
        print "Nom de la machine (hostname) ? :";
        chomp($HOSTNAME = <STDIN>);
        print "\n";
	$BROADCAST=`ipcalc -n $IP $NETMASK | grep Broadcast| awk {'print \$2'}`;
	chomp($BROADCAST);
	$NETWORK=`ipcalc -n $IP $NETMASK | grep Network | awk {'print \$2'}| awk -F/ {'print \$1'}`;
	chomp($NETWORK);

#
#  Check that the arguments the user has supplied are both 
# valid, and complete.
#
checkArguments();

#
# The two images we'll use, one for the disk image, one for swap.
#
my $image = "/dev/vol0/xenedu-".$xname."-root" ;
my $swap  = "/dev/vol0/xenedu-".$xname."-swp" ;
my $imgvar  = "/dev/vol0/xenedu-".$xname."-var" ;
my $imghome = "/dev/vol0/xenedu-".$xname."-home";
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
`/bin/dd if=/dev/zero of=$imgvar bs=2M count=1 seek=1024 >/dev/null 2>/dev/null`;
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
`mkdir $dir/home`;

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
`debootstrap --arch amd64 squeeze $dir http://ftp2.fr.debian.org/debian`;
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
#
# Stable
deb http://ftp2.fr.debian.org/debian     squeeze main contrib non-free
deb-src http://ftp2.fr.debian.org/debian squeeze main contrib non-free

# 
#  Security updates
#
deb     http://security.debian.org/ squeeze/updates  main contrib non-free
deb-src http://security.debian.org/ squeeze/updates  main contrib non-free


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

my @hostModules = "/lib/modules/2.6.26-2-xen-amd64";
                                                                                          
foreach my $file ( @hostModules )
{
File::Copy::cp( $file, $dir . "/lib/modules" );
}
`cp -a /lib/modules/2.6.26-2-xen-amd64  $dir/lib/modules`;

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
/dev/xvda1     /        ext3     errors=remount-ro     0     1
/dev/xvda2     /var     ext3     errors=remount-ro     0     1
/dev/xvda3     none     swap     sw                    0     0
/dev/xvda4     /home    ext3	defaults,quota	      0	    0
proc          /proc    proc     defaults              0     0
E_O_TAB
close( TAB );

print "Done\n";


#
#  Install locales
#
installLocales();
#
#  Install OpenSSH
#
installOpenSSH();
#
# install Udev
#
installUdev();
#
#  Fixup Inittab file
#
fixupInittab();
#
# Install SE3 Packages
#
#installSE3Packages();


#
#  Now unmount the image.
#
`umount $dir/var`;
`umount $dir`;


#
# Finally setup Xen to allow us to create the image.
#
print "Setting up Xen configuration file .. ";
open( XEN, ">", "/etc/xen/xenedu-$HOSTNAME.cfg" );
print XEN<<E_O_XEN;
kernel = "/boot/vmlinuz-2.6.32-5-xen-amd64"
ramdisk = "/boot/initrd.img-2.6.32-5-xen-amd64"
memory = $xmemory
name   = "$HOSTNAME"
vif = [ 'mac=$XENMAC' ]
disk   = [ 'phy:$image,xvda1,w','phy:$imgvar,xvda2,w','phy:$swap,xvda3,w','phy:$imghome,xvda4,w' ]
root   = "/dev/xvda1 ro"
extra = "4 console=hvc0 xencons=tty"
vcpus = $XENCPUS

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

# Ajout de la vm au boot du dom0
`ln -snf /etc/xen/xenedu-$HOSTNAME.cfg /etc/xen/auto/02-xenedu-$HOSTNAME.cfg`;

#
#  Give status message
#
print <<EOEND;


 Once completed you may start your new instance of Xen with:
 Vous pouvez désormais demarrer votre machine virutelle squeeze avec la commande :
 
    xm create xenedu-$HOSTNAME.cfg -c

 La machine virtuelle sera demarrer automatiquement au boot de  la machine physique.
 pour annuler ce comportement : 
  rm /etc/xen/auto/02-xenedu-$HOSTNAME.cfg
  
    
EOEND



=head2 checkArguments

  Check that the arguments the user has specified are complete and
 make sense.

=cut

sub checkArguments
{

    if (!defined( $HOSTNAME ) )
    {
    $HOSTNAME="squeeze";
    print<<EOF

  You should set a hostname with '--hostname=foo'.

  This option is required.
EOF
      ;
        exit;
    }

    if (!defined( $XENCPUS ) )
    {
        $XENCPUS=1;

    }
    if (!defined( $xname ) )
    {
    $xname="squeeze";
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




=head2 installLocales

  Install Locales and set ot  
=cut
  
sub installLocales
{
  `chroot $dir  echo "locales locales/default_environment_locale      select  fr_FR.UTF-8" |debconf-set-selections`;
  `chroot $dir  echo "locales locales/locales_to_be_generated multiselect     fr_FR ISO-8859-1, fr_FR.UTF-8 UTF-8, ISO-8859-15" |debconf-set-selections`;
  `chroot $dir  echo "tzdata  tzdata/Zones/Europe     select  Paris" |debconf-set-selections`; 
  `chroot $dir /usr/bin/apt-get update`;
  `DEBIAN_FRONTEND=noninteractive chroot $dir /usr/bin/apt-get --yes --force-yes install locales`;
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


=head2 installUdev

  Install Udev upon the virtual instance.
  
=cut
  
sub installUdev
{
	`chroot $dir /usr/bin/apt-get update`;
	`DEBIAN_FRONTEND=noninteractive chroot $dir /usr/bin/apt-get --yes --force-yes install udev`;
}
              
=head2 installSE3Packages

  Pre-Install SE3 upon the virtual instance.
  
=cut
  
sub installSE3Packages
{
	`chroot $dir /usr/bin/apt-get update`;
	`DEBIAN_FRONTEND=noninteractive chroot $dir /usr/bin/apt-get --yes --force-yes --download-only install se3 se3-domain`;
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
