.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init      Download providers and modules"
	@echo "  plan      Show what apply would do"
	@echo "  apply     Two-phase apply: cluster + access first, then the rest"
	@echo "  destroy   Drop in-cluster state, then destroy everything"
	@echo "  clean     Remove .terraform/ (forces re-init)"

init:
	$(TF) init

plan:
	$(TF) plan

# Two-phase apply — required because the helm/kubernetes providers need
# aws_eks_cluster.app.endpoint (known-after-apply) to configure themselves.
# Phase 1 creates the cluster, nodes, and the access entry for the Terraform
# caller so the helm provider can authenticate. Phase 2 applies everything
# else (IRSA, Helm releases, outputs).
apply:
	$(TF) apply $(AUTO) \
		-target=aws_eks_cluster.app \
		-target=aws_eks_node_group.app \
		-target=aws_eks_access_entry.terraform_caller \
		-target=aws_eks_access_policy_association.terraform_caller_admin
	$(TF) apply $(AUTO)

# Destroy — remove in-cluster resources from state first so Terraform doesn't
# try to talk to the cluster API while it's being torn down. The cluster takes
# them with it when aws_eks_cluster is destroyed.
destroy:
	-$(TF) state rm helm_release.app
	-$(TF) state rm helm_release.aws_load_balancer_controller
	-$(TF) state rm null_resource.wait_for_lb
	-$(TF) state rm data.kubernetes_service.app
	$(TF) destroy $(AUTO) -refresh=false

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate*
