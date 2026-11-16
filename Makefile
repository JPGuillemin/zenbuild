# zenbuild - universal Slackware package builder
PREFIX  ?= /usr
BINDIR  ?= $(PREFIX)/bin
DESTDIR ?=
SCRIPT  ?= zenbuild
INSTALL ?= install

.PHONY: all install uninstall check

all: check

check:
	@bash -n "$(SCRIPT)"

install:
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)"
	$(INSTALL) -m 755 "$(SCRIPT)" "$(DESTDIR)$(BINDIR)/zenbuild"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/zenbuild"
