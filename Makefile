MINT ?= mint

.PHONY: help brew-strap bootstrap-brew bootstrap-mint generate lint test verify build-css build-site serve ci

help:
	@printf "Available targets:\n"
	@printf "  brew-strap      Install local tooling with Homebrew Brewfile\n"
	@printf "  bootstrap-brew  Alias for brew-strap\n"
	@printf "  bootstrap-mint  Install Mint-managed tools from Mintfile\n"
	@printf "  generate        Generate Xcode project with XcodeGen\n"
	@printf "  lint            Run SwiftLint in strict mode\n"
	@printf "  test            Run swift test\n"
	@printf "  verify          Run generate + lint + test\n"
	@printf "  build-css       Compile Tailwind CSS\n"
	@printf "  build-site      Build static site output\n"
	@printf "  serve           Serve generated site locally\n"
	@printf "  ci              Bootstrap Mint tools and run verify\n"

brew-strap:
	brew bundle --file Brewfile

bootstrap-brew: brew-strap

bootstrap-mint:
	$(MINT) bootstrap

generate:
	$(MINT) run yonaskolb/XcodeGen@2.43.0 xcodegen generate --spec project.yml

lint:
	$(MINT) run realm/SwiftLint@0.63.2 swiftlint lint --strict --config .swiftlint.yml

test:
	swift test

verify: generate lint test

build-css:
	npm run build:tailwind

build-site:
	swift run inkwell build

serve:
	swift run inkwell serve

ci: bootstrap-mint verify
