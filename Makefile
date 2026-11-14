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

.PHONY: help images image-dart image-flutter test test-core test-cli test-app test-bench cli apk linux \
	shell-dart shell-flutter run-dart run-flutter bench-up bench-down clean

help:
	@echo "Targets: test test-core test-cli test-app test-bench cli apk linux shell-dart shell-flutter"
	@echo "         run-dart CMD=... run-flutter CMD=... bench-up bench-down images clean"

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

linux: image-flutter
	$(IN_FLUTTER) bash -ec 'cd app; flutter build linux --debug'

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

bench-up:
	docker compose -f bench/compose.yaml up -d --build

bench-down:
	docker compose -f bench/compose.yaml down -v

clean:
	rm -rf build app/build
