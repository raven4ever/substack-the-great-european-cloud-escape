.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init     Download providers and modules"
	@echo "  plan     Show what apply would do"
	@echo "  apply    Two-phase: Grafana IAM key first, then build + push + dashboard"
	@echo "  destroy  Tear everything down"
	@echo "  clean    Try destroy, then remove .terraform/ and state files"

init:
	$(TF) init

plan:
	$(TF) plan

# Two-phase: Grafana provider X-Auth-Token = apply-time IAM key secret.
apply:
	$(TF) apply $(AUTO) -target=scaleway_iam_api_key.grafana
	$(TF) apply $(AUTO)

destroy:
	$(TF) destroy $(AUTO)

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
