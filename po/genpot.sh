#!/bin/sh
# Copyright (C) 2004 Dafydd Harries

POT=./alexandria.pot

rm -f $POT &&
rgettext ../bin/alexandria $(find ../lib -name '*.rb') -o $POT &&
xgettext --join-existing $(find ../data -name '*.glade') --output=$POT
