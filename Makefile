# Define variables for script paths
SCRIPTS_DIR=scripts
TRIE_TEST_SCRIPT=$(SCRIPTS_DIR)/trie-test.sh
TRIE_BENCHMARK_SCRIPT=$(SCRIPTS_DIR)/trie-benchmark.sh
MINIMAL_SCRIPT=$(SCRIPTS_DIR)/minimal-colorizer.sh
MINIMAL_DEV_SCRIPT=$(SCRIPTS_DIR)/minimal-colorizer-dev.sh
MINIMAL_TAILWIND_SCRIPT=$(SCRIPTS_DIR)/minimal-tailwind.sh
MINIMAL_TAILWIND_DEV_SCRIPT=$(SCRIPTS_DIR)/minimal-tailwind-dev.sh
MINIMAL_COLORIZER=colorizer_minimal
MINIMAL_TAILWIND=colorizer_tailwind
MINIMAL_TRIE=colorizer_trie

TEST_SCRIPT=$(SCRIPTS_DIR)/run_tests.sh

help:
	@echo "Available targets:"
	@echo "  make test              - Run all mini.test tests"
	@echo "  make test-file FILE=f  - Run a single test file"
	@echo "  make trie              - Run trie test and benchmark"
	@echo "  make trie-test         - Run trie test"
	@echo "  make trie-benchmark    - Run trie benchmark"
	@echo "  make minimal               - Run the minimal script (remote)"
	@echo "  make minimal-dev           - Run the minimal script (local)"
	@echo "  make minimal-tailwind      - Run the minimal tailwind config (remote)"
	@echo "  make minimal-tailwind-dev  - Run the minimal tailwind config (local)"
	@echo "  make docs              - Generate vimdoc and HTML docs"
	@echo "  make docs-html         - Generate HTML docs only"
	@echo "  make clean             - Remove test/colorizer_*"

trie: trie-test trie-benchmark

trie-test:
	@echo "Running trie test..."
	@bash $(TRIE_TEST_SCRIPT)

trie-benchmark:
	@echo "Running trie benchmark..."
	@bash $(TRIE_BENCHMARK_SCRIPT)

minimal:
	@echo "Running minimal config (remote)..."
	@bash $(MINIMAL_SCRIPT)

minimal-dev:
	@echo "Running minimal config (local)..."
	@bash $(MINIMAL_DEV_SCRIPT)

minimal-tailwind:
	@echo "Running minimal tailwind config (remote)..."
	@bash $(MINIMAL_TAILWIND_SCRIPT)

minimal-tailwind-dev:
	@echo "Running minimal tailwind config (local)..."
	@bash $(MINIMAL_TAILWIND_DEV_SCRIPT)

clean:
	@echo "Removing test/"$(MINIMAL_COLORIZER)
	@rm -rf test/$(MINIMAL_COLORIZER)
	@echo "Removing test/"$(MINIMAL_TAILWIND)
	@rm -rf test/$(MINIMAL_TAILWIND)
	@echo "Removing test/tailwind/node_modules"
	@rm -rf test/tailwind/node_modules
	@echo "Removing test/trie/"$(MINIMAL_TRIE)
	@rm -rf test/trie/$(MINIMAL_TRIE)

test:
	@echo "Running tests..."
	@bash $(TEST_SCRIPT)

test-file:
	@echo "Running test file: $(FILE)"
	@bash $(TEST_SCRIPT) $(FILE)

docs: docs-html
	@bash $(SCRIPTS_DIR)/gen_docs.sh

docs-html:
	@echo "Generating HTML docs..."
	@bash $(SCRIPTS_DIR)/gen_html.sh

.PHONY: help test test-file trie trie-test trie-benchmark minimal minimal-dev minimal-tailwind minimal-tailwind-dev clean docs docs-html
