.PHONY: help project test lint clean

help:
	@echo "Instakai"
	@echo ""
	@echo "  make project   XcodeGen ile Instakai.xcodeproj üret"
	@echo "  make test      InstakaiCore birim testlerini çalıştır (Xcode gerekmez)"
	@echo "  make clean     Üretilen dosyaları sil"

# The app project is generated from project.yml; see the comment there.
project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen bulunamadı: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "Hazır: Instakai.xcodeproj"

# InstakaiCore is Foundation-only, so tests run on any machine with a Swift
# toolchain — no simulator, no Xcode.
test:
	swift test

clean:
	rm -rf Instakai.xcodeproj .build
