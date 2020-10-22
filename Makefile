TF_DIR := terraform
TF_PLAN := $(TF_DIR)/_terraform.plan
TF_VARS := -var-file=terraform/terraform.tfvars \
			-var="do_token=$$(cat ~/.digitalocean/token | tr -d '\n')"

.PHONY: deps
deps:
	asdf plugin add terraform || true
	asdf install

.PHONY: init
init: deps
	terraform init $(TF_DIR)

.PHONY: plan
plan: init
	terraform plan $(TF_VARS) -out=$(TF_PLAN) $(TF_DIR)

.PHONY: apply
apply: init
	terraform apply $(TF_PLAN)

.PHONY: destroy
destroy: init
	terraform destroy $(TF_VARS) $(TF_DIR)

.PHONY: deploy
deploy: plan apply

.PHONY: add-client
add-client:
ifndef name
	$(error 'name' is undefined - run with e.g. 'make add-client name=laptop')
endif
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh $(name) > ~/Downloads/wg-$(name).conf
