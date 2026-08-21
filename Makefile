SHELL := /bin/sh
VERSION := 0.8.1.1-hotfix
DIST := dist/GhostGuard-Kobo-v$(VERSION).zip
KOBOROOT := dist/GhostGuard-Kobo-v$(VERSION)-KoboRoot.tgz

.PHONY: all test license-verifiers sync-package package koboroot clean
all: test package koboroot

test:
	sh -n scripts/*.sh
	sh -n DCPRO_GhostGuard_Kobo_OneClick.sh
	mkdir -p .build
	cc -std=c99 -Wall -Wextra -Werror -Iinclude src/classifier.c tests/test_classifier.c -o .build/test_classifier
	.build/test_classifier
	sh tests/test_profile_lifecycle.sh
	go test ./cmd/gg-license-verify

license-verifiers:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-armv7 ./cmd/gg-license-verify
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-aarch64 ./cmd/gg-license-verify

sync-package:
	cp scripts/ghostguard.sh package/.adds/ghostguard/ghostguard.sh
	cp scripts/supervisor.sh package/.adds/ghostguard/supervisor.sh
	cp scripts/license_bridge.sh package/.adds/ghostguard/license_bridge.sh
	cp scripts/profile_manager.sh package/.adds/ghostguard/profile_manager.sh
	cp scripts/nm_quick.sh package/.adds/ghostguard/nm_quick.sh
	cp config/defaults.conf package/.adds/ghostguard/defaults.conf
	cp nickelmenu/ghostguard package/.adds/nm/ghostguard
	chmod +x package/.adds/ghostguard/*.sh package/.adds/ghostguard/bin/ghostguardd-* 2>/dev/null || true

package: sync-package license-verifiers
	mkdir -p dist
	rm -f $(DIST)
	cd package && zip -qr ../$(DIST) .
	@echo $(DIST)

# Native Kobo one-file install package. Kobo's boot update mechanism extracts
# /mnt/onboard/.kobo/KoboRoot.tgz over /, so the archive must contain the
# mnt/onboard/.adds tree rather than a top-level .adds directory.
# Runtime data is intentionally not populated by this target; existing data/
# survives upgrades because tar only overwrites paths present in the archive.
koboroot: sync-package license-verifiers
	mkdir -p dist
	rm -rf .build/koboroot
	mkdir -p .build/koboroot/mnt/onboard
	cp -R package/.adds .build/koboroot/mnt/onboard/.adds
	find .build/koboroot/mnt/onboard/.adds/ghostguard -type f -name '*.sh' -exec chmod 755 {} \;
	chmod 755 .build/koboroot/mnt/onboard/.adds/ghostguard/bin/ghostguardd-* 2>/dev/null || true
	chmod 755 .build/koboroot/mnt/onboard/.adds/ghostguard/bin/gg-license-verify-* 2>/dev/null || true
	rm -f $(KOBOROOT)
	tar -czf $(KOBOROOT) -C .build/koboroot mnt
	@echo $(KOBOROOT)

clean:
	rm -rf .build
	rm -f dist/*.zip dist/*.tgz
