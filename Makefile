.PHONY: help scan synth deploy destroy outputs test

help:
	@echo "Targets:"
	@echo "  scan     - run repo scanner quality gates"
	@echo "  synth    - CDK synth (infra)"
	@echo "  deploy   - CDK deploy (infra)"
	@echo "  destroy  - CDK destroy (infra)"
	@echo "  outputs  - show CloudFormation outputs (infra)"
	@echo "  test     - run infra unit tests"

scan:
	./scripts/scan_repo.sh --path . --ext txt,md --json /tmp/report.json

synth:
	cd infra && npx -y aws-cdk@2 synth

deploy:
	cd infra && npx -y aws-cdk@2 deploy

destroy:
	cd infra && npx -y aws-cdk@2 destroy

outputs:
	aws cloudformation describe-stacks \
	  --stack-name InfraStack \
	  --region eu-west-2 \
	  --query "Stacks[0].Outputs" \
	  --output table

test:
	cd infra && python3 -m pip install -r requirements-dev.txt && python -m pytest -q
