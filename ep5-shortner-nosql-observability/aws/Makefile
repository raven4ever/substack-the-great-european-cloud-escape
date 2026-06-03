.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init      Download providers and modules"
	@echo "  plan      Show what apply would do"
	@echo "  apply     Build image, push to ECR, deploy ECS Express service"
	@echo "  destroy   Tear down everything"
	@echo "  clean     Remove .terraform/ and local state"

init:
	$(TF) init

plan:
	$(TF) plan

apply:
	$(TF) apply $(AUTO)

destroy:
	$(TF) destroy $(AUTO)

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
