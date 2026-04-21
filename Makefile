MINT ?= mint
SWIFTLINT ?= $(MINT) run realm/SwiftLint@0.63.2 swiftlint

.PHONY: help brew-strap bootstrap-brew bootstrap-mint lint test verify build-css build-site serve ci install bump-patch bump-minor bump-major

help:
	@printf "Available targets:\n"
	@printf "  brew-strap      Install local tooling with Homebrew Brewfile\n"
	@printf "  bootstrap-brew  Alias for brew-strap\n"
	@printf "  bootstrap-mint  Install Mint-managed tools from Mintfile\n"
	@printf "  lint            Run SwiftLint in strict mode\n"
	@printf "  test            Run swift test\n"
	@printf "  verify          Run lint + test\n"
	@printf "  build-css       Compile Tailwind CSS\n"
	@printf "  build-site      Build static site output\n"
	@printf "  serve           Serve generated site locally\n"
	@printf "  ci              Bootstrap Mint tools and run verify\n"
	@printf "  install         Build and copy release binary to /usr/local/bin\n"
	@printf "  bump-patch      Bump semantic version patch number\n"
	@printf "  bump-minor      Bump semantic version minor number\n"
	@printf "  bump-major      Bump semantic version major number\n"

brew-strap:
	brew bundle --file Brewfile

bootstrap-brew: brew-strap

bootstrap-mint:
	$(MINT) bootstrap

lint:
	$(SWIFTLINT) lint --quiet --strict --config .swiftlint.yml

test:
	swift test

verify: lint test

build-css:
	npm run build:tailwind

build-site:
	swift run inkwell build

serve:
	swift run inkwell serve

ci: bootstrap-mint verify

install:
	swift build -c release
	cp .build/release/inkwell /usr/local/bin/inkwell

bump-patch:
	python3 scripts/bump_version.py --part patch

bump-minor:
	python3 scripts/bump_version.py --part minor

bump-major:
	python3 scripts/bump_version.py --part major
