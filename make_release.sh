#!/bin/sh

RM="`which rm` -vrf"
MKDIR="`which mkdir` -p"

if [ "$1foo" = "foo" ]; then
	echo "usage: `basename $0` X.Y.Z"
	exit 1
fi

PKG="alexandria-$1"
PKG_NAME="$PKG.tar.gz"
TMP_DIR="/tmp/$PKG"

echo "Creating temporary directory..."
$RM $TMP_DIR
$MKDIR $TMP_DIR
cp -r * $TMP_DIR
cd $TMP_DIR

echo "Removing unnecessary files..."
$RM `find . -name CVS -or -name ".cvsignore" -or -name ".#*" -or -name "*~"`
$RM `find data/alexandria/glade -name "*.gladep" -or -name "*.bak"`
$RM RELEASE_CHECKLIST make_release.sh InstalledFiles config.save
$RM data/locale lib/alexandria/config.rb lib/alexandria/version.rb
$RM po/alexandria.pot po/genpot.sh

echo "Updating version number..."
echo $1 > VERSION

echo "Generating tarball..."
cd ..
$RM $PKG_NAME 
tar -czf $PKG_NAME $PKG
du -h "`dirname $TMP_DIR`/$PKG_NAME"

exit 0
