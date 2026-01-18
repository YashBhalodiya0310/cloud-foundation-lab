.PHONY: help setup scan clean docker-build docker-scan

IMAGE_NAME=repo-scanner

help:
	@echo "Available commands:"
	@echo "  make setup        - Create virtual environment"
	@echo "  make scan         - Run repo scan locally"
	@echo "  make docker-build - Build scanner Docker image"
	@echo "  make docker-scan  - Run scanner inside Docker (CI simulation)"
	@echo "  make clean        - Remove logs"

setup:
	python3 -m venv .venv
	@echo "Virtual environment ready."

scan:
	./scripts/scan_repo.sh --path . --ext txt,md --log day2/scan_make.log

docker-build:
	docker build -t $(IMAGE_NAME) .

docker-scan:
	docker run --rm \
		-v "$$(pwd):/repo" \
		$(IMAGE_NAME) --path /repo --ext txt,md

clean:
	rm -f day2/*.log
	@echo "Logs cleaned."
