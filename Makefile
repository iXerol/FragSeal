SHELL := /bin/bash

BAZEL := bazel
RESOURCE_DIR := FragSealCoreTests/Resources
BAZEL_BASE_FLAGS :=
BAZEL_ARGS ?=

# Legacy escape hatches kept for compatibility; prefer BAZEL_ARGS.
EXTRA_BAZEL_FLAGS ?=
BAZEL_FLAGS ?=
BAZEL_ALL_FLAGS = $(BAZEL_BASE_FLAGS) $(EXTRA_BAZEL_FLAGS) $(BAZEL_FLAGS) $(BAZEL_ARGS)

BAZEL_CXXOPTS ?=
export BAZEL_CXXOPTS

PRODUCT ?= cli
PLATFORM ?= auto
RUNTIME ?= auto
ARCH ?= auto
DECRYPTER ?= auto
OPENSSL_LIB ?=

ifneq ($(strip $(DECRYPTER_IMPL)),)
ifeq ($(strip $(DECRYPTER)),auto)
DECRYPTER := $(DECRYPTER_IMPL)
endif
endif

ifneq ($(strip $(OPENSSL_LIB)),)
FRAGSEAL_OPENSSL_CRYPTO_LIB := $(OPENSSL_LIB)
endif
FRAGSEAL_OPENSSL_CRYPTO_LIB ?=
export FRAGSEAL_OPENSSL_CRYPTO_LIB

# On Linux we need Swift bridging headers on the include path for any Bazel build.
ifeq ($(shell uname -s),Linux)
# Keep toolchain headers inside the execroot via sandbox mount pairs.
LINUX_CXX_VERSION ?= $(shell g++ -dumpversion | cut -d. -f1)
LINUX_BAZEL_CONFIG ?= $(shell arch="$$(uname -m)"; \
	if [ "$$arch" = "x86_64" ]; then echo "swift_linux_x86_64"; \
	elif [ "$$arch" = "aarch64" ] || [ "$$arch" = "arm64" ]; then echo "swift_linux_aarch64"; \
	else echo "swift_linux"; fi)
LINUX_CXX_TRIPLE ?= $(shell arch="$$(uname -m)"; \
	if [ "$$arch" = "x86_64" ]; then echo "x86_64-linux-gnu"; \
	elif [ "$$arch" = "aarch64" ] || [ "$$arch" = "arm64" ]; then echo "aarch64-linux-gnu"; \
	else gcc -dumpmachine; fi)
LINUX_CXX_INCLUDE_ABS ?= /usr/include/c++/$(LINUX_CXX_VERSION)
LINUX_CXX_ARCH_INCLUDE_ABS ?= /usr/include/$(LINUX_CXX_TRIPLE)/c++/$(LINUX_CXX_VERSION)
LINUX_LIBXML2_INCLUDE_ABS ?= /usr/include/libxml2
BRIDGING_INCLUDE_ROOT ?= external/swift_toolchain_include
LINUX_CXX_INCLUDE_ROOT_REL ?= external/libstdcpp/include
LINUX_LIBXML2_INCLUDE_ROOT_REL ?= external/libxml2/include
BAZEL_CXXOPTS += -I$(BRIDGING_INCLUDE_ROOT) \
	-I$(LINUX_CXX_INCLUDE_ROOT_REL)/c++ \
	-I$(LINUX_CXX_INCLUDE_ROOT_REL)/$(LINUX_CXX_TRIPLE)/c++ \
	-I$(LINUX_LIBXML2_INCLUDE_ROOT_REL)
BAZEL_BASE_FLAGS += --config=$(LINUX_BAZEL_CONFIG)
BAZEL_BASE_FLAGS += \
	--action_env=CPATH=$(LINUX_LIBXML2_INCLUDE_ABS) \
	--action_env=C_INCLUDE_PATH=$(LINUX_LIBXML2_INCLUDE_ABS) \
	--copt=-I$(BRIDGING_INCLUDE_ROOT) \
	--copt=-I$(LINUX_CXX_INCLUDE_ROOT_REL)/c++ \
	--copt=-I$(LINUX_CXX_INCLUDE_ROOT_REL)/$(LINUX_CXX_TRIPLE)/c++ \
	--copt=-I$(LINUX_LIBXML2_INCLUDE_ROOT_REL) \
	--cxxopt=-I$(BRIDGING_INCLUDE_ROOT) \
	--cxxopt=-I$(LINUX_CXX_INCLUDE_ROOT_REL)/c++ \
	--cxxopt=-I$(LINUX_CXX_INCLUDE_ROOT_REL)/$(LINUX_CXX_TRIPLE)/c++ \
	--cxxopt=-I$(LINUX_LIBXML2_INCLUDE_ROOT_REL) \
	--sandbox_add_mount_pair=$(LINUX_CXX_INCLUDE_ABS):$(LINUX_CXX_INCLUDE_ROOT_REL)/c++ \
	--sandbox_add_mount_pair=$(LINUX_CXX_ARCH_INCLUDE_ABS):$(LINUX_CXX_INCLUDE_ROOT_REL)/$(LINUX_CXX_TRIPLE)/c++ \
	--sandbox_add_mount_pair=$(LINUX_LIBXML2_INCLUDE_ABS):$(LINUX_LIBXML2_INCLUDE_ROOT_REL)
endif

define MAKE_SELECTOR_ENV
host_os="$$(uname -s)"; \
case "$$host_os" in \
	Darwin) host_platform="macos" ;; \
	Linux) host_platform="linux" ;; \
	*) echo "Unsupported host OS: $$host_os" >&2; exit 1 ;; \
esac; \
host_macos_version="$$(sw_vers -productVersion 2>/dev/null || echo 0)"; \
host_macos_major="$${host_macos_version%%.*}"; \
product="$(PRODUCT)"; \
platform="$(PLATFORM)"; \
runtime="$(RUNTIME)"; \
arch="$(ARCH)"; \
decrypter="$(DECRYPTER)"; \
openssl_lib_override="$(OPENSSL_LIB)"; \
if [ "$$platform" = "auto" ]; then \
	platform="$$host_platform"; \
fi; \
case "$$platform" in \
	macos|linux) ;; \
	*) echo "Invalid PLATFORM='$$platform' (expected: auto, macos, linux)." >&2; exit 1 ;; \
esac; \
if [ "$$platform" != "$$host_platform" ]; then \
	echo "PLATFORM=$$platform requires a $$platform host or container (current host $$host_os)." >&2; \
	exit 1; \
fi; \
decrypter_flags=""; \
case "$$decrypter" in \
	""|auto) decrypter="auto" ;; \
	commoncrypto) decrypter_flags="--define DECRYPTER_IMPL=commoncrypto" ;; \
	openssl) decrypter_flags="--define DECRYPTER_IMPL=openssl" ;; \
	*) echo "Invalid DECRYPTER='$$decrypter' (expected: auto, commoncrypto, openssl)." >&2; exit 1 ;; \
esac; \
if [ "$$decrypter" = "commoncrypto" ] && [ "$$platform" != "macos" ]; then \
	echo "DECRYPTER=commoncrypto is only supported on macOS." >&2; \
	exit 1; \
fi; \
if [ -n "$$openssl_lib_override" ]; then \
	export FRAGSEAL_OPENSSL_CRYPTO_LIB="$$openssl_lib_override"; \
fi
endef

define RESOLVE_OPENSSL_RUNTIME
if [ -z "$${FRAGSEAL_OPENSSL_CRYPTO_LIB:-}" ]; then \
	for candidate in \
		"/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib" \
		"/usr/local/opt/openssl@3/lib/libcrypto.3.dylib" \
		"/opt/local/lib/libcrypto.3.dylib"; do \
		if [ -f "$$candidate" ]; then \
			export FRAGSEAL_OPENSSL_CRYPTO_LIB="$$candidate"; \
			break; \
		fi; \
	done; \
fi; \
if [ -z "$${FRAGSEAL_OPENSSL_CRYPTO_LIB:-}" ] && command -v brew >/dev/null 2>&1; then \
	brew_prefix="$$(brew --prefix openssl@3 2>/dev/null || true)"; \
	if [ -n "$$brew_prefix" ] && [ -f "$$brew_prefix/lib/libcrypto.3.dylib" ]; then \
		export FRAGSEAL_OPENSSL_CRYPTO_LIB="$$brew_prefix/lib/libcrypto.3.dylib"; \
	fi; \
fi
endef

.PHONY: resources build test project clean help

resources:
	./Scripts/gen-fake-assets.sh

build:
	@set -euo pipefail; \
	$(MAKE_SELECTOR_ENV); \
	$(RESOLVE_OPENSSL_RUNTIME); \
	bazel_target=""; \
	case "$$product" in \
		cli) \
			if [ "$$platform" = "linux" ]; then \
				case "$$runtime" in \
					auto|native) runtime="native" ;; \
					backdeploy) echo "RUNTIME=backdeploy is only supported for macOS CLI builds." >&2; exit 1 ;; \
					*) echo "Invalid RUNTIME='$$runtime' (expected: auto, native, backdeploy)." >&2; exit 1 ;; \
				esac; \
				if [ "$$arch" != "auto" ]; then \
					echo "ARCH is only supported for macOS CLI builds; omit ARCH for PLATFORM=linux." >&2; \
					exit 1; \
				fi; \
				bazel_target="//FragSeal:fragseal_cli_linux"; \
			else \
				case "$$runtime" in \
					auto) \
						if [ "$$host_macos_major" -ge 26 ]; then runtime="native"; else runtime="backdeploy"; fi ;; \
					native|backdeploy) ;; \
					*) echo "Invalid RUNTIME='$$runtime' (expected: auto, native, backdeploy)." >&2; exit 1 ;; \
				esac; \
				if [ "$$arch" = "auto" ]; then \
					arch="universal"; \
				fi; \
				case "$$arch" in \
					arm64|x86_64|universal) ;; \
					*) echo "Invalid ARCH='$$arch' (expected: auto, arm64, x86_64, universal)." >&2; exit 1 ;; \
				esac; \
				if [ "$$runtime" = "native" ]; then \
					case "$$arch" in \
						arm64) bazel_target="//FragSeal:fragseal_arm64" ;; \
						x86_64) bazel_target="//FragSeal:fragseal_x86_64" ;; \
						universal) bazel_target="//FragSeal:universal_fragseal" ;; \
					esac; \
				else \
					case "$$arch" in \
						arm64) bazel_target="//FragSeal:fragseal_backdeploy_bundle_arm64" ;; \
						x86_64) bazel_target="//FragSeal:fragseal_backdeploy_bundle_x86_64" ;; \
						universal) bazel_target="//FragSeal:fragseal_backdeploy_bundle" ;; \
					esac; \
				fi; \
			fi ;; \
		framework) \
			if [ "$$runtime" != "auto" ]; then \
				echo "RUNTIME is not supported for PRODUCT=framework; omit it." >&2; \
				exit 1; \
			fi; \
			if [ "$$arch" != "auto" ]; then \
				echo "ARCH is not supported for PRODUCT=framework; omit it." >&2; \
				exit 1; \
			fi; \
			bazel_target="//FragSealCore:FragSealCore" ;; \
		app) \
			echo "PRODUCT=app is reserved but not implemented yet." >&2; \
			exit 1 ;; \
		*) \
			echo "Invalid PRODUCT='$$product' (expected: cli, framework)." >&2; \
			exit 1 ;; \
	esac; \
	echo "Resolved build: PRODUCT=$$product PLATFORM=$$platform RUNTIME=$$runtime ARCH=$$arch DECRYPTER=$$decrypter"; \
	echo "Building $$bazel_target with BAZEL_CXXOPTS=$$BAZEL_CXXOPTS"; \
	$(BAZEL) build $$decrypter_flags $(BAZEL_ALL_FLAGS) $$bazel_target; \
	if [ "$$product" = "cli" ] && [ "$$runtime" = "backdeploy" ]; then \
		case "$$arch" in \
			arm64) backdeploy_root="bazel-bin/FragSeal/arm64" ;; \
			x86_64) backdeploy_root="bazel-bin/FragSeal/x86_64" ;; \
			universal) backdeploy_root="bazel-bin/FragSeal" ;; \
		esac; \
		echo "Built back-deploy bundle:"; \
		echo "  $$backdeploy_root/fragseal_backdeploy"; \
		echo "  $$backdeploy_root/Frameworks/libswiftCompatibilitySpan.dylib"; \
	fi; \
	if [ "$$product" = "cli" ] && [ "$$platform" = "macos" ] && [ "$$decrypter" = "openssl" ] && [ -n "$${FRAGSEAL_OPENSSL_CRYPTO_LIB:-}" ]; then \
		if [ "$$arch" = "universal" ]; then \
			echo "Universal OpenSSL builds still require a target-machine libcrypto slice that matches the selected runtime arch."; \
		else \
			echo "OpenSSL note: runtime validation still requires a libcrypto slice that matches ARCH=$$arch."; \
		fi; \
		echo "Use OPENSSL_LIB=/absolute/path/to/libcrypto to override runtime lookup during tests or local runs."; \
	fi

test: resources
	@set -euo pipefail; \
	$(MAKE_SELECTOR_ENV); \
	bazel_targets=""; \
	test_env_flags=""; \
	extra_test_flags=""; \
	if [ "$$product" != "cli" ]; then \
		echo "test does not support PRODUCT=$$product yet; omit PRODUCT or use PRODUCT=cli." >&2; \
		exit 1; \
	fi; \
	if [ "$$arch" != "auto" ]; then \
		echo "ARCH is not supported for test; omit it." >&2; \
		exit 1; \
	fi; \
	case "$$runtime" in \
		auto|native|backdeploy) ;; \
		*) echo "Invalid RUNTIME='$$runtime' (expected: auto, native, backdeploy)." >&2; exit 1 ;; \
	esac; \
	if [ "$$platform" = "linux" ]; then \
		if [ "$$runtime" = "backdeploy" ]; then \
			echo "RUNTIME=backdeploy is only supported for macOS tests." >&2; \
			exit 1; \
		fi; \
		runtime="native"; \
		bazel_targets="//FragSealCoreTests:FragSealCoreTests_host //FragSealCliTests:FragSealCliFunctionalTest_linux"; \
	else \
		if [ "$$runtime" = "auto" ]; then \
			if [ "$$host_macos_major" -ge 26 ]; then runtime="native"; else runtime="backdeploy"; fi; \
		fi; \
		case "$$runtime" in \
			native) bazel_targets="//FragSealCoreTests:FragSealCoreTests //FragSealCliTests:FragSealCliFunctionalTest_macos" ;; \
			backdeploy) \
				bazel_targets="//FragSealCoreTests:FragSealCoreTests_backdeploy //FragSealCliTests:FragSealCliFunctionalTest_backdeploy"; \
				extra_test_flags="--host_macos_minimum_os=$$host_macos_version" ;; \
			*) echo "Invalid RUNTIME='$$runtime' (expected: auto, native, backdeploy)." >&2; exit 1 ;; \
		esac; \
		$(RESOLVE_OPENSSL_RUNTIME); \
	fi; \
	if [ -n "$${FRAGSEAL_OPENSSL_CRYPTO_LIB:-}" ]; then \
		echo "Using OpenSSL runtime from $$FRAGSEAL_OPENSSL_CRYPTO_LIB"; \
		test_env_flags="--test_env=FRAGSEAL_OPENSSL_CRYPTO_LIB=$$FRAGSEAL_OPENSSL_CRYPTO_LIB"; \
	fi; \
	echo "Resolved test: PLATFORM=$$platform RUNTIME=$$runtime DECRYPTER=$$decrypter"; \
	echo "Testing $$bazel_targets with BAZEL_CXXOPTS=$$BAZEL_CXXOPTS"; \
	$(BAZEL) test $$decrypter_flags $$test_env_flags $$extra_test_flags $(BAZEL_ALL_FLAGS) $$bazel_targets

project:
	$(BAZEL) run //:xcodeproj

clean:
	$(BAZEL) clean
	find $(RESOURCE_DIR) -maxdepth 1 -type f ! -name '.gitkeep' -delete
	rm -rf FragSeal.xcodeproj
	rm -rf .build .swiftpm

help:
	@echo "Workflow targets:"
	@echo "  make build      # build PRODUCT=cli|framework (PRODUCT defaults to cli)"
	@echo "  make test       # regenerate fixtures (if needed) then run tests for the current host"
	@echo "  make resources  # regenerate deterministic backup fixtures"
	@echo "  make project    # generate FragSeal.xcodeproj"
	@echo "  make clean      # bazel clean + remove generated fixtures"
	@echo
	@echo "Selectors:"
	@echo "  PRODUCT=cli|framework   (default: cli; PRODUCT=app is reserved but not implemented)"
	@echo "  PLATFORM=auto|macos|linux (default: auto; cross-platform builds are rejected)"
	@echo "  RUNTIME=auto|native|backdeploy (CLI on macOS only; default: auto)"
	@echo "  ARCH=auto|arm64|x86_64|universal (CLI on macOS only; default: auto -> universal)"
	@echo "  DECRYPTER=auto|commoncrypto|openssl (default: auto)"
	@echo "  OPENSSL_LIB=/absolute/path/to/libcrypto (runtime override for modern crypto or DECRYPTER=openssl)"
	@echo "  BAZEL_ARGS=\"...\"     # extra Bazel flags"
	@echo
	@echo "Common examples:"
	@echo "  make build"
	@echo "  make build PRODUCT=framework"
	@echo "  make build PLATFORM=macos RUNTIME=backdeploy"
	@echo "  make build PLATFORM=linux DECRYPTER=openssl"
	@echo "  make test"
	@echo "  make test PLATFORM=macos RUNTIME=backdeploy"
	@echo "  make test DECRYPTER=openssl OPENSSL_LIB=/absolute/path/to/libcrypto.3.dylib"
	@echo
	@echo "Invalid combinations fail fast:"
	@echo "  PRODUCT=framework with RUNTIME or ARCH"
	@echo "  PLATFORM=linux with RUNTIME=backdeploy or ARCH != auto"
