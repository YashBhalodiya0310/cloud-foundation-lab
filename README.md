# Cloud Foundation Lab

A small but real foundation repo that demonstrates:
- **Repo hygiene + quality gates** (scanner with exit codes + JSON report)
- **CI automation** (GitHub Actions runs checks on every push/PR)
- **Infrastructure as Code** (AWS CDK Python: S3 + DynamoDB example stack)

## Repo Scanner (Quality Gates)

`scripts/scan_repo.sh` scans the repo and enforces simple rules:
- File count must be under a limit
- `.env` files are forbidden (common secret leak)
- Basic secret-pattern detection (baseline)

Exit codes:
- `0` = PASS
- `20` = FAIL (quality gate violation)
- `2` = bad args

Run locally:
```bash
./scripts/scan_repo.sh --path . --ext txt,md --json /tmp/report.json
echo $?
