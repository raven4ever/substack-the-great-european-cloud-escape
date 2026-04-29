.PHONY: init plan apply destroy clean help

TF   ?= terraform
AUTO := -auto-approve

help:
	@echo "Targets:"
	@echo "  init      Download providers and modules"
	@echo "  plan      Show what apply would do"
	@echo "  apply     Two-phase apply: Kapsule cluster + pool first, then the rest"
	@echo "  destroy   Drop in-cluster state, then destroy everything"
	@echo "  clean     Try destroy, then remove .terraform/ and state files"

init:
	$(TF) init

plan:
	$(TF) plan

# Two-phase apply — required because the helm/kubernetes providers need
# scaleway_k8s_cluster.app.kubeconfig (known-after-apply) to configure
# themselves. Phase 1 creates the cluster + pool. Phase 2 applies everything
# else (Helm release, outputs). Same pattern as the AWS module.
apply:
	$(TF) apply $(AUTO) \
		-target=scaleway_k8s_cluster.app \
		-target=scaleway_k8s_pool.app
	$(TF) apply $(AUTO)

# Destroy — remove in-cluster resources from state first so Terraform doesn't
# try to talk to the cluster API while it's being torn down. Kapsule's
# delete_additional_resources=true ensures CCM-provisioned LBs also go away.
destroy:
	-$(TF) state rm helm_release.app
	-$(TF) state rm null_resource.wait_for_lb
	-$(TF) state rm data.kubernetes_service.app
	$(TF) destroy $(AUTO) -refresh=false

clean:
	-$(MAKE) destroy
	rm -rf .terraform* terraform.tfstate* .kube
