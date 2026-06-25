APP     := TriggerHappy
SCHEME  := TriggerHappy
CONFIG  := Debug
PRODUCT := $(APP).app
DERIVED := $(HOME)/Library/Developer/Xcode/DerivedData

.DEFAULT_GOAL := build
.PHONY: build install run clean help

build: ## Compile the app (xcodebuild)
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) build

install: build ## Build, copy TriggerHappy.app to the project root, and launch it
	@APP_PATH=$$(ls -dt $(DERIVED)/$(APP)-*/Build/Products/$(CONFIG)/$(PRODUCT) 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ]; then echo "build product not found — run 'make build' first"; exit 1; fi; \
	rm -rf ./$(PRODUCT) && cp -R "$$APP_PATH" ./$(PRODUCT); \
	echo "installed ./$(PRODUCT)"; \
	open ./$(PRODUCT)

run: ## Launch the locally-copied app
	open ./$(PRODUCT)

clean: ## Remove build products
	xcodebuild -project $(APP).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) clean
	rm -rf ./$(PRODUCT)

help: ## Show available targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed -E 's/:.*## /\t/' | sort
