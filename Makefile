.PHONY: project test build run install clean

project:
	xcodegen generate

test:
	cd BetterClickCore && swift test

build: project
	xcodebuild -project betterclick.xcodeproj -scheme betterclick \
	  -configuration Debug -derivedDataPath .build-xcode build

run: build
	open .build-xcode/Build/Products/Debug/betterclick.app

install:
	./scripts/install.sh

clean:
	rm -rf .build-xcode betterclick.xcodeproj
	cd BetterClickCore && swift package clean
