# Define variables for script paths
SCRIPTS_DIR=scripts
TRIE_TEST_SCRIPT=$(SCRIPTS_DIR)/trie-test.sh
TRIE_BENCHMARK_SCRIPT=$(SCRIPTS_DIR)/trie-benchmark.sh
MINIMAL_SCRIPT=$(SCRIPTS_DIR)/minimal-colorizer.sh
MINIMAL_COLORIZER=colorizer_minimal
MINIMAL_TRIE=colorizer_trie

TEST_SCRIPT=$(SCRIPTS_DIR)/run_tests.sh

help:
	@echo "Available targets:"
	@echo "  make test              - Run all mini.test tests"
	@echo "  make test-file FILE=f  - Run a single test file"
	@echo "  make trie              - Run trie test and benchmark"
	@echo "  make trie-test         - Run trie test"
	@echo "  make trie-benchmark    - Run trie benchmark"
	@echo "  make minimal           - Run the minimal script"
	@echo "  make clean             - Remove test/colorizer_*"

trie: trie-test trie-benchmark

trie-test:
	@echo "Running trie test..."
	@bash $(TRIE_TEST_SCRIPT)

trie-benchmark:
	@echo "Running trie benchmark..."
	@bash $(TRIE_BENCHMARK_SCRIPT)

minimal:
	@echo "Running minimal config..."
	@bash $(MINIMAL_SCRIPT)

clean:
	@echo "Removing test/"$(MINIMAL_COLORIZER)
	@rm -rf test/$(MINIMAL_COLORIZER)
	@echo "Removing test/trie/"$(MINIMAL_TRIE)
	@rm -rf test/trie/$(MINIMAL_TRIE)

test:
	@echo "Running tests..."
	@bash $(TEST_SCRIPT)

test-file:
	@echo "Running test file: $(FILE)"
	@bash $(TEST_SCRIPT) $(FILE)

.PHONY: help test test-file trie trie-test trie-benchmark minimal clean
