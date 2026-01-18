.PHONY: help setup scan clean

help:
	@echo "Available commands:"
	@echo "  make setup   - Create virtual environment"
	@echo "  make scan    - Run repo scan with logging"
	@echo "  make clean   - Remove logs and temp files"

setup:
	python3 -m venv .venv
	@echo "Virtual environment ready."

scan:
	./scripts/scan_repo.sh --path . --ext txt,md --log day2/scan_make.log

clean:
	rm -f day2/*.log
	@echo "Logs cleaned."
