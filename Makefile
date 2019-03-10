.PHONY: magic

clean:
	rm -rf .build

xcodeproj:
	swift package generate-xcodeproj

docker-build:
	docker build --tag rester -f Dockerfile.base .

test-linux: docker-build
	docker run --rm rester swift test

test-macos: xcodeproj
	set -o pipefail && \
	xcodebuild test \
		-scheme Rester \
		-destination platform="macOS" \

test-swift:
	swift test

test-all: test-linux test-macos

magic:
	sourcery   --templates ./.sourcery   --sources Tests   --args testimports='@testable import '"ResterTests"   --output Tests/LinuxMain.swift

release-macos:
	swift build --static-swift-stdlib -c release

release-linux: docker-build
	docker run --rm -v $(PWD):/host -w /host rester swift build --static-swift-stdlib -c release
