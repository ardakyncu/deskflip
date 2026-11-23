APP_NAME    := Deskflip
APP         := build/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications
INSTALLED   := $(INSTALL_DIR)/$(APP_NAME).app
LSREGISTER  := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build install uninstall quit icon clean

# Build build/Deskflip.app.
build:
	@./scripts/build-app.sh

# Build the app, move it to ~/Applications and open it. The bundle is moved,
# not copied, so Spotlight and Launch Services only ever see one Deskflip.
install: build quit
	@mkdir -p "$(INSTALL_DIR)"
	@rm -rf "$(INSTALLED)"
	@"$(LSREGISTER)" -u "$(APP)" 2>/dev/null || true
	@mv "$(APP)" "$(INSTALLED)"
	@"$(LSREGISTER)" -f "$(INSTALLED)"
	@open "$(INSTALLED)"
	@echo "Installed $(INSTALLED)"

# Quit Deskflip and remove it from ~/Applications.
uninstall: quit
	@if [ -d "$(INSTALLED)" ]; then "$(LSREGISTER)" -u "$(INSTALLED)" || true; fi
	@rm -rf "$(INSTALLED)"
	@echo "Removed $(INSTALLED)"

# Quit a running copy of Deskflip.
quit:
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x "$(APP_NAME)" >/dev/null || break; sleep 0.3; done

# Regenerate assets/icon.png, the icon shown in the README.
icon:
	@mkdir -p .build
	@xcrun swiftc -O -o .build/make-icon scripts/make-icon.swift
	@.build/make-icon assets/icon.png
	@echo "Wrote assets/icon.png"

# Remove all build output.
clean:
	@rm -rf .build build
