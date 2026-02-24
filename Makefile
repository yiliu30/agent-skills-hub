.PHONY: help update catalog settings install list

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

update: ## Update third-party skills to latest upstream
	git submodule update --remote --merge
	@echo "\033[32m✅ Submodules updated to latest.\033[0m"

catalog: ## Rebuild catalog.json from all skill sources
	python scripts/build-catalog.py

settings: ## Generate VS Code chat.agentSkillsLocations snippet
	./scripts/generate-vscode-settings.sh

install: ## Install a skill: make install SKILL=git-commit TARGET=~/.config/skills/
	@if [ -z "$(SKILL)" ] || [ -z "$(TARGET)" ]; then \
		echo "Usage: make install SKILL=<name> TARGET=<dir>"; exit 1; \
	fi
	./scripts/install-skill.sh $(SKILL) $(TARGET)

list: ## List all available skills
	./scripts/install-skill.sh --list

refresh: update catalog ## Update submodules + rebuild catalog
	@echo "\033[32m✅ Skills updated and catalog rebuilt.\033[0m"
