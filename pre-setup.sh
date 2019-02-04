#!/bin/sh

echo "Removing perl524 & installing perl526"
[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
rpm -Uv --force rpms/cpanel-perl-526-5.26.0-1.debuginfo.cp1170.x86_64.rpm

echo "Checking for missing modules"
OUT=$(/usr/local/cpanel/3rdparty/bin/perl -MTest2::Bundle::Extended -e1)
if [ "x$?" != "x0" ]; then
    echo "Installing Test2::Bundle::Extended"
    rpm -Uv https://vmware-manager.dev.cpanel.net/RPM/11.70/centos/7/x86_64/cpanel-perl-526-Test2-Suite-0.000114-1.cp1170.noarch.rpm
fi

echo "Setting prove for 526 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/526/bin/prove /usr/local/cpanel/3rdparty/bin/prove
