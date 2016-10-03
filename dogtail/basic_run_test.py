#!/usr/bin/env python

from dogtail.tree import *
from dogtail.utils import run

run('bin/alexandria', appName = 'alexandria')
app = root.application('alexandria')
quit_item = app.menuItem('Quit')
quit_item.doActionNamed('click')
