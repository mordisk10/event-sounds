.PHONY: help project open clean

help:
	@echo "Instakai — UI"
	@echo ""
	@echo "  make project   XcodeGen ile Instakai.xcodeproj üret / generate the project"
	@echo "  make open      Projeyi Xcode'da aç / open in Xcode"
	@echo "  make clean     Üretilen dosyaları sil / remove generated files"

project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen bulunamadı: brew install xcodegen"; exit 1; }
	xcodegen generate
	@echo "Hazır: Instakai.xcodeproj"

open: project
	open Instakai.xcodeproj

clean:
	rm -rf Instakai.xcodeproj DerivedData
