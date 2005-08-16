
POT=./alexandria.pot

RUBY=../bin/alexandria $(shell find ../lib -name '*.rb' -and -not -path '*macui*')

GLADE=$(shell find ../data -name '*.glade')

HEADERS=$(shell find .. -name '*.h')

PO=$(wildcard *.po)

$(POT): $(RUBY) $(GLADE) ../alexandria.desktop.in.h $(HEADERS)
	rm -f $(POT)
	@echo Updating PO template from Ruby files
	@rgettext --output=$(POT) $(RUBY)
	@echo Updating PO template from Glade files
	@xgettext --output=$(POT) --join-existing $(GLADE)
	@echo Updating PO template from header files
	@xgettext --output=$(POT) --join-existing --extract-all $(HEADERS)

../alexandria.desktop.in.h: ../alexandria.desktop.in
	intltool-extract --type=gettext/ini ../alexandria.desktop.in

$(PO): $(POT)
	msgmerge -U $@ $(POT)

po: $(POT)
	@echo Updating PO files
	@for po in $(PO); do \
		echo -n "$$po: "; \
		msgmerge -U $$po $(POT); \
	done

check:
	@echo Checking PO files
	@echo
	@for po in $(PO); do \
		echo "$$po: "; \
		msgfmt -cvv $$po -o /dev/null; \
		echo; \
	done

.PHONY: $(PO) po check

