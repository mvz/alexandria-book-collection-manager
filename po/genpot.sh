#!/bin/sh
# Copyright (C) 2004 Dafydd Harries

POT=./alexandria.pot

set -e

intltool-extract --type=gettext/ini alexandria.desktop.in

rm -f $POT
rgettext ../bin/alexandria $(find ../lib -name '*.rb') -o $POT
xgettext --extract-all --join-existing \
	$(find ../data -name '*.glade') \
	$(find .. -name '*.h') \
	--output=$POT

