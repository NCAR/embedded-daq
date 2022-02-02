#
# Makefile for nidas Debian packages
# The primary task is to invoke scons to do the build and
# install to the $DESTDIR. Install targets in the Makefile
# move things around in $DESTDIR when paths are dependent on
# Debian variable that is known to this Makefile, but isn't
# (yet) passed to scons
# 
# Here's a table of install directories of RPMs and Debian
# packages for various architectures. "scons install" puts
# things in a nidas directory tree, and then, if necessary
# nidas.spec and this Makefile move them to a place approprite
# for the package.
#
# $PREFIX is /typically defined to be /opt/nidas.
#
SCONS = scons
BUILD ?= "host"
REPO_TAG ?= v1.2
NPREFIX=/opt/nidas
PREFIX=/usr

# Where to find pkg-configs of other software
PKG_CONFIG_PATH := /usr/lib/$(DEB_HOST_MULTIARCH)/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

.PHONY : build clean scons_install

$(info DESTDIR=$(DESTDIR))
$(info DEB_BUILD_GNU_TYPE=$(DEB_BUILD_GNU_TYPE))
$(info DEB_HOST_GNU_TYPE=$(DEB_HOST_GNU_TYPE))
$(info DEB_HOST_MULTIARCH=$(DEB_HOST_MULTIARCH))

build:
	cd src; $(SCONS) --config=force -j 4 BUILD=$(BUILD) \
		REPO_TAG=$(REPO_TAG) \
		PREFIX=$(PREFIX) \
		NPREFIX=$(NPREFIX) \
		PKG_CONFIG_PATH=$(PKG_CONFIG_PATH)

scons_install:
	cd src; $(SCONS) -j 4 BUILD=$(BUILD) \
		REPO_TAG=$(REPO_TAG) \
		PREFIX=$(DESTDIR)$(PREFIX) \
		NPREFIX=$(DESTDIR)$(NPREFIX) \
		PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) install

install: scons_install

clean:
	cd src; $(SCONS) -c BUILD="$(BUILD)" \
		PREFIX=$(DESTDIR)$(PREFIX) \
		NPREFIX=$(DESTDIR)$(NPREFIX)

