SHELL := /bin/bash

HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

DART_IMAGE := luks-unlocker-dart
FLUTTER_IMAGE := luks-unlocker-flutter
DART_HOME_VOLUME := luks-unlocker-dart-home
FLUTTER_HOME_VOLUME := luks-unlocker-flutter-home

# Extra flags, e.g. DOCKER_OPTS="--network host" to reach the bench from tests.
DOCKER_BUILD_OPTS ?=
DOCKER_OPTS ?=
# Extra arguments for the test runner, e.g. ARGS="test/foo_test.dart -n name".
ARGS ?=
CMD ?= bash

BUILD_IMAGE = docker build -q $(DOCKER_BUILD_OPTS) --build-arg UID=$(HOST_UID) --build-arg GID=$(HOST_GID)
RUN = docker run --rm --init --user $(HOST_UID):$(HOST_GID) -v "$(CURDIR)":/work -w /work $(DOCKER_OPTS)
IN_DART = $(RUN) -v $(DART_HOME_VOLUME):/home/dev $(DART_IMAGE)
IN_FLUTTER = $(RUN) -v $(FLUTTER_HOME_VOLUME):/home/dev $(FLUTTER_IMAGE)
IN_DART_TTY = $(RUN) -it -v $(DART_HOME_VOLUME):/home/dev $(DART_IMAGE)
IN_FLUTTER_TTY = $(RUN) -it -v $(FLUTTER_HOME_VOLUME):/home/dev $(FLUTTER_IMAGE)

.PHONY: help images image-dart image-flutter image-emulator test test-core test-cli test-app test-bench test-app-bench \
	test-android-bench cli apk apk-release aab linux icons shell-dart shell-flutter run-dart run-flutter bench-up bench-down clean require-signing \
	promo promo-up promo-shots

help:
	@echo "Targets: test test-core test-cli test-app test-bench test-app-bench test-android-bench cli apk apk-release aab linux icons"
	@echo "         shell-dart shell-flutter run-dart CMD=... run-flutter CMD=... bench-up bench-down images clean"
	@echo "         promo promo-up promo-shots"

images: image-dart image-flutter

image-dart:
	@docker image inspect $(DART_IMAGE) >/dev/null 2>&1 || echo "Building $(DART_IMAGE) image..."
	@$(BUILD_IMAGE) -t $(DART_IMAGE) -f tool/Dockerfile.dart tool >/dev/null

image-flutter:
	@docker image inspect $(FLUTTER_IMAGE) >/dev/null 2>&1 || echo "Building $(FLUTTER_IMAGE) image (first build takes 15+ minutes)..."
	@$(BUILD_IMAGE) -t $(FLUTTER_IMAGE) -f tool/Dockerfile.flutter tool >/dev/null

test: test-core test-cli test-app

test-core: image-dart
	$(IN_DART) bash -ec 'dart pub get; cd packages/unlock_core; dart analyze --fatal-infos; dart test $(ARGS)'

test-cli: image-dart
	$(IN_DART) bash -ec 'dart pub get; cd packages/unlock_cli; dart analyze --fatal-infos; dart test $(ARGS)'

test-app: image-flutter
	$(IN_FLUTTER) bash -ec 'cd app; flutter pub get; flutter analyze; flutter test $(ARGS)'

cli: image-dart
	$(IN_DART) bash -ec 'dart pub get; mkdir -p build; dart compile exe packages/unlock_cli/bin/luks_unlock.dart -o build/luks-unlock'

apk: image-flutter
	$(IN_FLUTTER) bash -ec 'cd app; flutter build apk --debug'

# Release builds refuse to run without the signing config, which would fall back to the debug key.
KEY_PROPERTIES := app/android/key.properties
require-signing:
	@test -f $(KEY_PROPERTIES) || { echo "$(KEY_PROPERTIES) is missing; see app/android/app/build.gradle.kts."; exit 1; }

apk-release: image-flutter require-signing
	$(IN_FLUTTER) bash -ec 'cd app; flutter build apk --release'

# Play Store upload: app/build/app/outputs/bundle/release/app-release.aab
aab: image-flutter require-signing
	$(IN_FLUTTER) bash -ec 'cd app; flutter build appbundle --release'

linux: image-flutter
	$(IN_FLUTTER) bash -ec 'cd app; flutter build linux --debug'

icons:
	docker run --rm -e HOST_UID=$(HOST_UID) -e HOST_GID=$(HOST_GID) -v "$(CURDIR)":/work -w /work alpine:3.22 tool/gen_icons.sh

shell-dart: image-dart
	$(IN_DART_TTY) bash

shell-flutter: image-flutter
	$(IN_FLUTTER_TTY) bash

run-dart: image-dart
	$(IN_DART) bash -ec '$(CMD)'

run-flutter: image-flutter
	$(IN_FLUTTER) bash -ec '$(CMD)'

# Bench-tagged engine and CLI tests against target1/target2; assumes `make bench-up`.
BENCH_RELAY_DIR := .dart_tool/bench-relay
test-bench: image-dart
	@bash packages/unlock_core/test/integration/bench_relay.sh "$(CURDIR)/$(BENCH_RELAY_DIR)" bench/compose.yaml & \
	relay=$$!; trap 'kill $$relay 2>/dev/null' EXIT; \
	$(RUN) --network luks-bench -e BENCH=1 -e BENCH_RELAY_DIR=/work/$(BENCH_RELAY_DIR) \
		-v $(DART_HOME_VOLUME):/home/dev $(DART_IMAGE) bash -ec 'dart pub get >/dev/null; \
		cd packages/unlock_core; dart test -j 1 --tags bench $(ARGS) test/integration; \
		cd ../unlock_cli; dart test -j 1 --tags bench $(ARGS) test'

# The Linux app under Xvfb unlocks target1-3 in parallel; assumes `make bench-up`, resets the targets first.
BENCH_COMPOSE := docker compose -f bench/compose.yaml
BENCH_TARGETS := target1 target2 target3
BENCH_PASS := fake-bench-pass
BENCH_RESET = for t in $(BENCH_TARGETS); do \
		$(BENCH_COMPOSE) exec -T $$t bench-ctl clear >/dev/null && \
		$(BENCH_COMPOSE) exec -T $$t bench-ctl set PASSPHRASE=$(BENCH_PASS) >/dev/null || exit 1; \
	done
# "target1=SHA256:..,..;target2=..;": the targets' pre-boot fingerprints.
BENCH_KEYS = $$(for t in $(BENCH_TARGETS); do \
		printf '%s=%s;' $$t "$$($(BENCH_COMPOSE) exec -T $$t bench-ctl fingerprint | awk '$$1 == "preboot" {print $$3}' | paste -sd, -)"; \
	done)
test-app-bench: image-flutter
	@$(BENCH_RESET)
	@keys=$(BENCH_KEYS); \
	$(RUN) --network luks-bench -e BENCH_PREBOOT_KEYS="$$keys" -v $(FLUTTER_HOME_VOLUME):/home/dev $(FLUTTER_IMAGE) \
		bash -ec 'cd app; flutter pub get >/dev/null; xvfb-run -a flutter test -d linux --dart-define=BENCH=1 \
		--dart-define=BENCH_PASSPHRASE=$(BENCH_PASS) --dart-define=BENCH_PREBOOT_KEYS="$$BENCH_PREBOOT_KEYS" \
		integration_test/bench_run_test.dart'

# The same flow on an Android emulator (needs /dev/kvm); assumes `make bench-up`. Logs go to build/android-bench.
EMULATOR_IMAGE := luks-unlocker-emulator
image-emulator: image-flutter
	@docker image inspect $(EMULATOR_IMAGE) >/dev/null 2>&1 || echo "Building $(EMULATOR_IMAGE) image (downloads an Android system image)..."
	@docker build -q $(DOCKER_BUILD_OPTS) --build-arg BASE=$(FLUTTER_IMAGE) -t $(EMULATOR_IMAGE) -f tool/Dockerfile.emulator tool >/dev/null

# kvm needs a Docker daemon that sees /dev/kvm (Docker Desktop does not); off is software emulation, very slow.
EMULATOR_ACCEL ?= kvm
EMULATOR_DEVICE = $(if $(filter kvm,$(EMULATOR_ACCEL)),--device /dev/kvm --group-add $$(stat -c %g /dev/kvm))
test-android-bench: image-emulator
ifeq ($(EMULATOR_ACCEL),kvm)
	@docker run --rm --device /dev/kvm $(EMULATOR_IMAGE) true >/dev/null 2>&1 || { \
		echo "The Docker daemon cannot see /dev/kvm; EMULATOR_ACCEL=off runs without it, very slowly."; exit 1; }
endif
	@$(BENCH_RESET)
	@keys=$(BENCH_KEYS); \
	$(RUN) --network luks-bench $(EMULATOR_DEVICE) -e EMULATOR_ACCEL=$(EMULATOR_ACCEL) \
		-e BENCH_PREBOOT_KEYS="$$keys" -e BENCH_PASS=$(BENCH_PASS) \
		-v $(FLUTTER_HOME_VOLUME):/home/dev $(EMULATOR_IMAGE) bash tool/android_bench.sh

bench-up:
	docker compose -f bench/compose.yaml up -d --build

bench-down:
	docker compose -f bench/compose.yaml down -v

# Landing page: promo/ is the content, promo/engine renders it; deploys use promo/compose.yaml.
PROMO_IMAGE := luks-unlocker-promo
PROMO_PORT ?= 8888

# Local preview image; its privacy policy and terms are placeholders.
promo:
	docker build -q $(DOCKER_BUILD_OPTS) -t $(PROMO_IMAGE) --build-arg ALLOW_PLACEHOLDER_LEGAL=1 promo

promo-up: promo
	@echo "http://localhost:$(PROMO_PORT)"
	docker run --rm -p 127.0.0.1:$(PROMO_PORT):80 $(PROMO_IMAGE)

# Android blocks screenshots of the app, so the widget tests render its screens into promo/images.
promo-shots: image-flutter
	$(IN_FLUTTER) bash -ec 'cd app; flutter test --dart-define=PROMO_SHOTS=1 test/promo/promo_screenshots_test.dart'
	docker run --rm -e HOST_UID=$(HOST_UID) -e HOST_GID=$(HOST_GID) -v "$(CURDIR)":/work -w /work alpine:3.22 tool/promo_webp.sh

clean:
	rm -rf build app/build
