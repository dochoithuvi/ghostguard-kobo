SHELL := /bin/sh
VERSION := 0.8.5
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
	! grep -q 'GhostGuard - Activate Profile' nickelmenu/ghostguard
	! grep -q 'GhostGuard - Report' nickelmenu/ghostguard
	! grep -q '90000' nickelmenu/ghostguard
	grep -q 'GhostGuard - Stop : cmd_spawn' nickelmenu/ghostguard
	grep -q 'ui_action.sh update' nickelmenu/ghostguard
	grep -q 'auto_activate_if_ready' scripts/ui_action.sh
	grep -q 'emergency_stop' scripts/ui_action.sh
	grep -q 'PROTECT_ACTIVE=0' scripts/emergency_stop.sh
	grep -q 'PENDING_APPROVAL' scripts/ui_action.sh
	grep -q 'manifest.online.json' scripts/update.sh
	grep -q 'koboroot_sha256' scripts/update.sh
	grep -q 'KoboRoot.tgz.part' scripts/update.sh
