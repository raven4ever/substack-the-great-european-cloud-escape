.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init     Download providers and modules"
	@echo "  plan     Show what apply would do"
	@echo "  apply    Two-phase: IAM Grafana key first, then build + push + dashboard"
	@echo "  destroy  Tear everything down"
	@echo "  clean    Try destroy, then remove .terraform/ and state files"

init:
	$(TF) init

plan:
	$(TF) plan

# Two-phase apply — Grafana provider auth = scaleway_iam_api_key.grafana.secret_key
# (apply-time computed). Phase 1 mints the IAM key so provider can self-configure.
# Phase 2 applies everything else, including the dashboard.
apply:
	$(TF) apply $(AUTO) -target=scaleway_iam_api_key.grafana
	$(TF) apply $(AUTO)

destroy:
	$(TF) destroy $(AUTO)

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
