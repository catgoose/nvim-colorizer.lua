# Define variables for script paths
SCRIPTS_DIR=scripts
MINIMAL_TRIE_SCRIPT=$(SCRIPTS_DIR)/minimal-trie.sh
MINIMAL_SCRIPT=$(SCRIPTS_DIR)/minimal-colorizer.sh

# Default target: help
help:
	@echo "Available targets:"
	@echo "  make trie       - Run the minimal-trie script"
	@echo "  make minimal    - Run the minimal script"
	@echo "  make clean      - Remove test/colorizer_*"

# Target to run the minimal-trie script
trie:
	@echo "Running minimal-trie script..."
	@bash $(MINIMAL_TRIE_SCRIPT)

# Target to run the minimal script
minimal:
	@echo "Running minimal script..."
	@bash $(MINIMAL_SCRIPT)

# Clean target (optional)
clean:
	@echo "Removing test/colorizer_*"
	@rm -rf test/colorizer_*

# Phony targets
.PHONY: help trie minimal clean
