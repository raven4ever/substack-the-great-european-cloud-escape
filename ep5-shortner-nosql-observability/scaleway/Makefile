.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init     Download providers and modules"
	@echo "  plan     Show what apply would do"
	@echo "  apply    Build + push + deploy (needs TF_VAR_grafana_auth)"
	@echo "  destroy  Tear everything down"
	@echo "  clean    Try destroy, then remove .terraform/ and state files"

init:
	$(TF) init

plan:
	$(TF) plan

# Grafana SA token via TF_VAR_grafana_auth. Create SA in Cockpit Grafana UI first.
apply:
	$(TF) apply $(AUTO)

destroy:
	$(TF) destroy $(AUTO)

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
