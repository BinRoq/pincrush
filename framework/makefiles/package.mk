ifeq ($(FW_PACKAGING_RULES_LOADED),)
FW_PACKAGING_RULES_LOADED := 1

.PHONY: package before-package internal-package after-package-buildno after-package

# For the toplevel invocation of make, mark 'all' and the *-package rules as prerequisites.
# We do not do this for anything else, because otherwise, all the packaging rules would run for every subproject.
ifeq ($(_FW_TOP_INVOCATION_DONE),)
package:: all before-package internal-package after-package
else
package:: internal-package
endif

FAKEROOT := $(FW_SCRIPTDIR)/fakeroot.sh -p "$(FW_PROJECT_DIR)/.debmake/fakeroot"
export FAKEROOT

# Only do the master packaging rules if we're the toplevel make invocation.
ifeq ($(_FW_TOP_INVOCATION_DONE),)
FW_CAN_PACKAGE := $(shell [ -d "$(FW_PROJECT_DIR)/layout" ] && echo 1 || echo 0)

ifeq ($(FW_CAN_PACKAGE),1)

FW_PACKAGE_NAME := $(shell grep Package "$(FW_PROJECT_DIR)/layout/DEBIAN/control" | cut -d' ' -f2)
FW_PACKAGE_ARCH := $(shell grep Architecture "$(FW_PROJECT_DIR)/layout/DEBIAN/control" | cut -d' ' -f2)
FW_PACKAGE_VERSION := $(shell grep Version "$(FW_PROJECT_DIR)/layout/DEBIAN/control" | cut -d' ' -f2)

FW_PACKAGE_BUILDNUM = $(shell TOP_DIR="$(TOP_DIR)" $(FW_SCRIPTDIR)/deb_build_num.sh $(FW_PACKAGE_NAME) $(FW_PACKAGE_VERSION))
FW_PACKAGE_DEBVERSION = $(shell grep Version "$(FW_PACKAGE_STAGING_DIR)/DEBIAN/control" | cut -d' ' -f2)

ifdef STOREPACKAGE
	FW_PACKAGE_FILENAME = cydiastore_$(FW_PACKAGE_NAME)_v$(FW_PACKAGE_DEBVERSION)
else
	FW_PACKAGE_FILENAME = $(FW_PACKAGE_NAME)_$(FW_PACKAGE_DEBVERSION)_$(FW_PACKAGE_ARCH)
endif

before-package::
	$(ECHO_NOTHING)rm -rf "$(FW_PACKAGE_STAGING_DIR)"$(ECHO_END)
	$(ECHO_NOTHING)rsync -a "$(FW_PROJECT_DIR)/layout/" "$(FW_PACKAGE_STAGING_DIR)" --exclude "_MTN" --exclude ".git" --exclude ".svn" --exclude ".DS_Store" --exclude "._.*"$(ECHO_END)
	$(ECHO_NOTHING)$(FAKEROOT) -c$(ECHO_END)

after-package-buildno::
ifeq ($(PACKAGE_BUILDNAME),)
	$(ECHO_NOTHING)sed -e 's/Version: \(.*\)/Version: \1-$(FW_PACKAGE_BUILDNUM)/g' "$(FW_PROJECT_DIR)/layout/DEBIAN/control" > "$(FW_PACKAGE_STAGING_DIR)/DEBIAN/control"$(ECHO_END)
else
	$(ECHO_NOTHING)sed -e 's/Version: \(.*\)/Version: \1-$(FW_PACKAGE_BUILDNUM)+$(PACKAGE_BUILDNAME)/g' "$(FW_PROJECT_DIR)/layout/DEBIAN/control" > "$(FW_PACKAGE_STAGING_DIR)/DEBIAN/control"$(ECHO_END)
endif
	$(ECHO_NOTHING)echo "Installed-Size: $(shell du $(DU_EXCLUDE) DEBIAN -ks "$(FW_PACKAGE_STAGING_DIR)" | cut -f 1)" >> "$(FW_PACKAGE_STAGING_DIR)/DEBIAN/control"$(ECHO_END)

after-package:: after-package-buildno
	$(ECHO_NOTHING)$(FAKEROOT) -r dpkg-deb -b "$(FW_PACKAGE_STAGING_DIR)" "$(FW_PROJECT_DIR)/$(FW_PACKAGE_FILENAME).deb" 2>/dev/null$(ECHO_END)

ifeq ($(FW_DEVICE_IP),)
install::
	@echo "Error: $(MAKE) install requires that you set FW_DEVICE_IP in your environment.\nIt is also recommended that you have public-key authentication set up for root over SSH, or you'll be entering your password a lot."; exit 1
else # FW_DEVICE_IP
install:: internal-install after-install
internal-install::
	scp "$(FW_PROJECT_DIR)/$(FW_PACKAGE_FILENAME).deb" root@$(FW_DEVICE_IP):
	ssh root@$(FW_DEVICE_IP) "dpkg -i $(FW_PACKAGE_FILENAME).deb"

after-install:: internal-after-install
endif

else # FW_CAN_PACKAGE
before-package::
	@echo "$(MAKE) package requires there to be a layout/ directory in the project root, containing the basic package structure."; exit 1

after-package::

endif # FW_CAN_PACKAGE

endif # _FW_TOP_INVOCATION_DONE

internal-package::

internal-after-install::

endif # FW_PACKAGING_RULES_LOADED
