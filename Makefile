.PHONY: test build release install run check

# Fast feedback loop: pure-logic unit tests, no mouse control, no live
# window/screen access, no Accessibility/Screen Recording permissions
# needed. Run this after every change instead of driving the real UI.
test:
	swift test

build:
	swift build

release:
	swift build -c release

install: release
	./build_app.sh

run: install
	open /Applications/StashBar.app

# Everything that should pass before calling a change done.
check: test release
