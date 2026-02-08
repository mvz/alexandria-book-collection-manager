
POT=./alexandria.pot

RUBY=../exe/alexandria $(shell find ../lib -name '*.rb' -and -not -path '*macui*')

DESKTOP=../alexandria.desktop

GLADE=$(shell find ../share/alexandria/glade -name '*.glade')

PO=$(wildcard *.po)

$(POT): $(RUBY) $(GLADE) $(DESKTOP)
	rm -f $(POT)
	@echo Updating PO template from Ruby files
	@rxgettext --output=$(POT) $(RUBY)
	@echo Updating PO template from Glade files
	@xgettext --output=$(POT) --join-existing $(GLADE)
	@echo Updating PO template from desktop file
	@xgettext --output=$(POT) --join-existing $(DESKTOP)

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

