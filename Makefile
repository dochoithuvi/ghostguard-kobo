SHELL := /bin/sh
VERSION := 0.8.0-foundation
DIST := dist/GhostGuard-Kobo-v$(VERSION).zip

.PHONY: all test license-verifiers admin-tools package clean
all: test license-verifiers package

test:
	mkdir -p .build
	cc -std=c99 -Wall -Wextra -Werror -Iinclude src/classifier.c tests/test_classifier.c -o .build/test_classifier
	.build/test_classifier

license-verifiers:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-armv7 ./cmd/gg-license-verify
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w -buildid=' -o package/.adds/ghostguard/bin/gg-license-verify-aarch64 ./cmd/gg-license-verify

admin-tools:
	mkdir -p .build/admin
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags='-s -w -buildid=' -o .build/admin/gg-license-tool-windows-amd64.exe ./cmd/gg-license-tool
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w -buildid=' -o .build/admin/gg-license-tool-linux-amd64 ./cmd/gg-license-tool

package: license-verifiers
	rm -f $(DIST)
	cd package && zip -qr ../$(DIST) .
	@echo $(DIST)

clean:
	rm -rf .build
	rm -f dist/*.zip
