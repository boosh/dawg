DO_TOKEN_FILE := ~/.digitalocean/token
YDNS_CREDS_FILE := ~/.ydns
SERVER_KEYS_PATH := ~/.dawg-server-keys

TF_DIR := terraform
TF_PLAN := $(TF_DIR)/_terraform.plan
TF_VARS := -var-file=terraform/terraform.tfvars \
			-var="do_token=$$(cat $(DO_TOKEN_FILE) | tr -d '\n')" \
			-var="ydns_credentials=$$(cat $(YDNS_CREDS_FILE) | tr -d '\n')" \
			-var="server_private_key=$$(cat $(SERVER_KEYS_PATH) | head -n1 || echo "")" \
			-var="server_preshared_key=$$(cat $(SERVER_KEYS_PATH) | tail -n1 || echo "")"

.DEFAULT_GOAL := help

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Dependencies

.PHONY: deps
deps: ## Install dependencies (if using asdf)
	asdf plugin add terraform || true
	asdf install || terraform version

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
	$(MAKE) download-key

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
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh -e $$(terraform output endpoint) create $(name) > ~/Downloads/wg-$(name).conf

.PHONY: add-client
add-client: ## Add a client config
ifndef name
	$(error 'name' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=<public key>')
endif
ifndef ip
	$(error 'ip' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=<public key>')
endif
ifndef key
	$(error 'key' is undefined - run with e.g. 'make add-client name=laptop ip=10.0.0.3 key=<public key>')
endif
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh -c $(ip) -k $(key) add $(name)

##@ Server commands

ip ?= $$(terraform output ip | tr -d '\n')

.PHONY: status
status: ## Print server status
	ssh root@$(ip) wg ;\
	if [[ $$? == 0 ]]; then echo "Server ready"; exit 0; else echo "Server not ready..."; exit 1; fi

.PHONY: ssh
ssh: ## SSH to the server
	ssh root@$$(terraform output ip | tr -d '\n')

.PHONY: download-key
download-key: ## Download the server's private keys and store locally
	set -eo pipefail ;\
	if [[ -f $(SERVER_KEYS_PATH) ]]; then \
		echo Private keys already exists at $(SERVER_KEYS_PATH) ;\
	else \
		ssh root@$$(terraform output ip | tr -d '\n') cat /etc/wireguard/server_private.key > $(SERVER_KEYS_PATH) && \
		ssh root@$$(terraform output ip | tr -d '\n') cat /etc/wireguard/server_preshared.key >> $(SERVER_KEYS_PATH) && \
			echo Private keys downloaded to $(SERVER_KEYS_PATH) ;\
	fi

.PHONY: qr
qr: ## Generate a QR code for the named config
ifndef name
	$(error 'name' is undefined - run with e.g. 'make qr name=laptop')
endif
	qrencode -t ansiutf8 < ~/Downloads/wg-$(name).conf
