SHELL := /bin/sh
VERSION := 0.8.7.1
DIST := dist/GhostGuard-Kobo-v$(VERSION).zip
KOBOROOT := dist/GhostGuard-Kobo-v$(VERSION)-KoboRoot.tgz
CLANG ?= clang
COMMON_NATIVE := -fuse-ld=lld -Os -ffreestanding -fno-builtin -fno-stack-protector -nostdlib -static -Wl,--build-id=none -Wl,-e,_start

.PHONY: all test native-binaries license-verifiers sync-package package koboroot clean
all: test package koboroot

test:
	sh -n scripts/*.sh
	sh -n DCPRO_GhostGuard_Kobo_OneClick.sh
	@COUNT="$$(grep -c '^menu_item[[:space:]]*:' nickelmenu/ghostguard)"; [ "$$COUNT" -eq 4 ] || { echo "Expected exactly 4 GhostGuard menu items, got $$COUNT"; exit 1; }
	grep -q 'GhostGuard - Status' nickelmenu/ghostguard
	grep -q 'GhostGuard - Start' nickelmenu/ghostguard
	grep -q 'GhostGuard - Stop' nickelmenu/ghostguard
	grep -q 'GhostGuard - Update' nickelmenu/ghostguard
	grep -q 'GhostGuard - Stop : cmd_spawn' nickelmenu/ghostguard
	grep -q '"$$CORE" shadow' scripts/ui_action.sh
	! grep -q '"$$CORE" start' scripts/ui_action.sh
	grep -q 'PROTECT_ACTIVE=0' scripts/emergency_stop.sh
	grep -q 'PROTECT_FILTER_ARMED' scripts/emergency_stop.sh
	grep -q 'PROTECT_WATCHDOG' scripts/emergency_stop.sh
	grep -q 'manifest.online.json' scripts/update.sh
	grep -q 'koboroot_sha256' scripts/update.sh
	grep -q 'KoboRoot.tgz.part' scripts/update.sh
	grep -q 'SHA_MISMATCH' scripts/update.sh
	grep -q 'SAFETY_ROLLBACK=1' config/defaults.conf
	grep -q 'SAFETY_HANDSHAKE=0' config/defaults.conf
	grep -q 'PROTECT_ACTIVE=0' config/defaults.conf
	grep -q 'SAFETY_ROLLBACK requested=' scripts/supervisor.sh
	grep -q 'PROBATION_PASSED -> SHADOW retained by v0.8.7.1 rollback' scripts/supervisor.sh
	! grep -q 'arm_protect' scripts/supervisor.sh
	! grep -q 'EVIOCGRAB' scripts/supervisor.sh
	grep -q 'BASELINE_STABLE_LIVE' scripts/profile_manager.sh
	grep -q 'EVIOCGRAB' src/ghostguardd.c
	grep -q 'UI_DEV_CREATE' src/ghostguardd.c
	grep -q 'SYN_DROPPED' src/ghostguardd.c
	python3 tools/prepare_native.py
	grep -q 'ghost_capture.gglog' .build/ghostguardd.c
	grep -q 'episode_guard' .build/ghostguardd.c
	grep -q 'ALLOW_ESCAPE' .build/ghostguardd.c
	grep -q 'observer_profile.ggdata' .build/ghostguardd.c
	grep -q 'RUNTIME_FAULT.ggstate' .build/ghostguardd.c
	mkdir -p .build
	cc -std=c99 -Wall -Wextra -Werror -Iinclude src/classifier.c tests/test_classifier.c -o .build/test_classifier
	.build/test_classifier
	sh tests/test_profile_lifecycle.sh
	sh tests/test_safety_hotfix.sh
	python3 tests/test_episode_guard.py
	sh tests/test_shadow_rollback_0871.sh
	go test ./cmd/gg-license-verify
	$(MAKE) sync-package
	sh -n package/.adds/ghostguard/*.sh
	grep -q 'observer_profile.ggdata' package/.adds/ghostguard/ghostguard.sh
	grep -q 'profile_v5.ggstate' package/.adds/ghostguard/profile_manager.sh
	grep -q 'GhostGuard Kobo 0.8.7.1 Emergency Shadow Rollback' package/.adds/ghostguard/nm_quick.sh
	grep -q 'Protect: DISABLED' package/.adds/ghostguard/nm_quick.sh
	grep -q 'EVIOCGRAB: OFF' package/.adds/ghostguard/nm_quick.sh
	grep -q 'manifest.online.json' package/.adds/ghostguard/update.sh
	grep -q 'KoboRoot.tgz.part' package/.adds/ghostguard/update.sh
	grep -q '^Version: 0.8.7.1$$' package/.adds/ghostguard/VERSION
	grep -q '^Protect: DISABLED in v0.8.7.1$$' package/.adds/ghostguard/VERSION
	! grep -q '\.txt' package/.adds/ghostguard/ghostguard.sh
	! grep -q '\.txt' package/.adds/ghostguard/profile_manager.sh

native-binaries:
	python3 tools/prepare_native.py
	$(CLANG) --target=armv7-linux-gnueabihf $(COMMON_NATIVE) -o package/.adds/ghostguard/bin/ghostguardd-armv7 .build/ghostguardd.c
	$(CLANG) --target=aarch64-linux-gnu $(COMMON_NATIVE) -o package/.adds/ghostguard/bin/ghostguardd-aarch64 .build/ghostguardd.c

license-verifiers:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-armv7 ./cmd/gg-license-verify
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-aarch64 ./cmd/gg-license-verify

sync-package:
	cp scripts/ghostguard.sh package/.adds/ghostguard/ghostguard.sh
	cp scripts/supervisor.sh package/.adds/ghostguard/supervisor.sh
	cp scripts/license_bridge.sh package/.adds/ghostguard/license_bridge.sh
	cp scripts/profile_manager.sh package/.adds/ghostguard/profile_manager.sh
	cp scripts/nm_quick.sh package/.adds/ghostguard/nm_quick.sh
	cp scripts/ui_action.sh package/.adds/ghostguard/ui_action.sh
	cp scripts/emergency_stop.sh package/.adds/ghostguard/emergency_stop.sh
	cp scripts/update.sh package/.adds/ghostguard/update.sh
	cp config/defaults.conf package/.adds/ghostguard/defaults.conf
	cp nickelmenu/ghostguard package/.adds/nm/ghostguard
	python3 tools/prepare_runtime.py
	chmod +x package/.adds/ghostguard/*.sh 2>/dev/null || true

package: sync-package native-binaries license-verifiers
	mkdir -p dist
	rm -f $(DIST)
	cd package && zip -qr ../$(DIST) .
	@echo $(DIST)

koboroot: sync-package native-binaries license-verifiers
	mkdir -p dist
	rm -rf .build/koboroot
	mkdir -p .build/koboroot/mnt/onboard
	cp -R package/.adds .build/koboroot/mnt/onboard/.adds
	find .build/koboroot/mnt/onboard/.adds/ghostguard -type f -name '*.sh' -exec chmod 755 {} \;
	chmod 755 .build/koboroot/mnt/onboard/.adds/ghostguard/bin/* 2>/dev/null || true
	rm -f $(KOBOROOT)
	tar -czf $(KOBOROOT) -C .build/koboroot mnt
	@echo $(KOBOROOT)

clean:
	rm -rf .build
	rm -f dist/*.zip dist/*.tgz
