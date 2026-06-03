.PHONY: init plan apply destroy clean help

TF                ?= terraform
AUTO              := -auto-approve
APP_NAME          := ep5-shortner
ECS_CLUSTER       := $(APP_NAME)-cluster
ECS_SERVICE       := $(APP_NAME)
ECS_RESOURCE_ADDR := aws_ecs_express_gateway_service.app

help:
	@echo "Targets:"
	@echo "  init      Download providers and modules"
	@echo "  plan      Show what apply would do"
	@echo "  apply     Build + push + deploy (auto-imports on Express bug #47437)"
	@echo "  destroy   Tear down everything"
	@echo "  clean     Remove .terraform/ and local state"

init:
	$(TF) init

plan:
	$(TF) plan

# AWS provider issue hashicorp/terraform-provider-aws#47437:
# aws_ecs_express_gateway_service errors on its consistency check after
# successful AWS-side create. Service ends up in AWS but missing from state.
# Workaround: tolerate first failure, import the orphan, re-apply clean.
apply:
	-@$(TF) apply $(AUTO)
	@if ! $(TF) state list 2>/dev/null | grep -qx '$(ECS_RESOURCE_ADDR)'; then \
		echo ">> $(ECS_RESOURCE_ADDR) missing from state — importing $(ECS_CLUSTER),$(ECS_SERVICE)" ; \
		$(TF) import $(ECS_RESOURCE_ADDR) $(ECS_CLUSTER),$(ECS_SERVICE) ; \
	fi
	$(TF) apply $(AUTO)

destroy:
	$(TF) destroy $(AUTO)

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
