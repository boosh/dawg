DO_TOKEN_FILE := ~/.digitalocean/token
YDNS_CREDS_FILE := ~/.ydns

TF_DIR := terraform
TF_PLAN := $(TF_DIR)/_terraform.plan
TF_VARS := -var-file=terraform/terraform.tfvars \
			-var="do_token=$$(cat $(DO_TOKEN_FILE) | tr -d '\n')" \
			-var="ydns_credentials=$$(cat $(YDNS_CREDS_FILE) | tr -d '\n')"

.DEFAULT_GOAL := help

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Dependencies

.PHONY: deps
deps: ## Install dependencies (if using asdf)
	asdf plugin add terraform || true
	asdf install || true

.PHONY: init
init: deps ## Terraform init
	terraform init $(TF_DIR)

##@ Infrastructure

.PHONY: plan
plan: init ## Terraform plan
	terraform plan $(TF_VARS) -out=$(TF_PLAN) $(TF_DIR)

.PHONY: apply
apply: init ## Terraform apply
	terraform apply $(TF_PLAN)

.PHONY: destroy
destroy: init ## Terraform destroy
	terraform destroy -auto-approve $(TF_VARS) $(TF_DIR)

.PHONY: deploy
deploy: plan apply  ## Terraform plan then apply

##@ Client management

.PHONY: new-client
new-client: ## Generate a new client config and write it to ~/Downloads
ifndef name
	$(error 'name' is undefined - run with e.g. 'make new-client name=laptop')
endif
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh -e $(terraform output endpoint) create $(name) > ~/Downloads/wg-$(name).conf

.PHONY: add-client
add-client: ## Add a client config
ifndef name
	$(error 'name' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=xxx')
endif
ifndef ip
	$(error 'ip' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=xxx')
endif
ifndef key
	$(error 'key' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=xxx')
endif
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh -c $(ip) -k $(key) add $(name)

##@ Server commands

.PHONY: status
status: ## Print server status
	ssh root@$$(terraform output ip | tr -d '\n') wg ;\
	if [[ $$? == 0 ]]; then echo "Server ready"; else echo "Server not ready..."; fi

.PHONY: ssh
ssh: ## SSH to the server
	ssh root@$$(terraform output ip | tr -d '\n')

.PHONY: qr
qr: ## Generate a QR code for the named config
ifndef name
	$(error 'name' is undefined - run with e.g. 'make qr name=laptop')
endif
	qrencode -t ansiutf8 < ~/Downloads/wg-$(name).conf
