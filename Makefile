# Makefile — leomulticloud experiment driver
#
# Quick-start:
#   make init                  # initialise Terraform providers
#   make plan                  # dry-run (no changes)
#   make apply                 # deploy infrastructure (TTL=60 default)
#   make apply TTL=120         # deploy with a different TTL
#   make health                # check both cloud /health endpoints
#   make experiment TTL=60     # interactive RTO measurement run
#   make outputs               # print Terraform output values
#   make destroy               # tear down all infrastructure

# ── Config ────────────────────────────────────────────────────────────────────
SHELL         := /bin/bash   # required for pipefail, time builtin, $$(...)
.SHELLFLAGS   := -euo pipefail -c

TF            := terraform -chdir=terraform
LOG_DIR       := logs
# Override TTL per run: make apply TTL=120  (must be 60, 120, or 300)
TTL           ?= 60

.PHONY: init plan apply destroy outputs health ssh-aws experiment help

# ── Targets ───────────────────────────────────────────────────────────────────

help:
	@echo "Usage: make <target> [TTL=60|120|300]"
	@echo ""
	@echo "  init        terraform init (run once)"
	@echo "  plan        terraform plan (read-only)"
	@echo "  apply       deploy infrastructure; logs to logs/apply_<ts>.log"
	@echo "  destroy     tear down all infrastructure"
	@echo "  outputs     print terraform output values"
	@echo "  health      curl /health on both AWS and Azure"
	@echo "  ssh-aws     open SSH session to EC2 primary"
	@echo "  experiment  start RTO measurement (interactive)"
	@echo ""
	@echo "  Default TTL=60; override with: make apply TTL=120"

init:
	$(TF) init

plan:
	$(TF) plan -var="dns_ttl=$(TTL)"

apply:
	@mkdir -p $(LOG_DIR)
	@LOG_FILE=$(LOG_DIR)/apply_$$(date +%Y%m%dT%H%M%S).log; \
	echo "========================================"; \
	echo "Apply started: $$(date)  TTL=$(TTL)s"; \
	echo "Log: $$LOG_FILE"; \
	echo "========================================"; \
	{ time $(TF) apply -var="dns_ttl=$(TTL)"; } 2>&1 | tee "$$LOG_FILE"; \
	echo "========================================"; \
	echo "Apply ended:   $$(date)"; \
	echo "========================================"

destroy:
	$(TF) destroy

outputs:
	$(TF) output

health:
	@AWS_URL=$$($(TF) output -raw aws_health_check_url 2>/dev/null); \
	AZURE_URL=$$($(TF) output -raw azure_health_check_url 2>/dev/null); \
	echo "── AWS primary ──────────────────────────"; \
	curl -sf --max-time 5 "$$AWS_URL" | python3 -m json.tool || echo "  UNREACHABLE"; \
	echo "── Azure secondary ──────────────────────"; \
	curl -sf --max-time 5 "$$AZURE_URL" | python3 -m json.tool || echo "  UNREACHABLE"

ssh-aws:
	@IP=$$($(TF) output -raw aws_primary_ip 2>/dev/null); \
	KEY=$${SSH_KEY:-$$HOME/.ssh/id_rsa}; \
	echo "Connecting to $$IP (key: $$KEY)"; \
	ssh -i "$$KEY" ubuntu@"$$IP"

experiment:
	@APP_URL=$$($(TF) output -raw app_url 2>/dev/null | sed 's|http://||'); \
	echo "Starting RTO experiment for TTL=$(TTL)s against $$APP_URL"; \
	DNS_TTL=$(TTL) ./tests/measure_rto.sh "$$APP_URL" Azure 5
