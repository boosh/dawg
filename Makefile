TF_DIR := terraform
TF_PLAN := $(TF_DIR)/_terraform.plan
TF_VARS := -var-file=terraform/terraform.tfvars \
			-var="do_token=$$(cat ~/.digitalocean/token | tr -d '\n')"

.PHONY: deps
deps:
	asdf plugin add terraform || true
	asdf install || true

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
	terraform destroy -auto-approve $(TF_VARS) $(TF_DIR)

.PHONY: deploy
deploy: plan apply

.PHONY: new-client
new-client:
ifndef name
	$(error 'name' is undefined - run with e.g. 'make new-client name=laptop')
endif
	ssh root@$$(terraform output ip | tr -d '\n') /usr/local/bin/wg-add-client.sh $(name) > ~/Downloads/wg-$(name).conf

.PHONY: status
status:
	ssh root@$$(terraform output ip | tr -d '\n') wg ;\
	if [[ $$? == 0 ]]; then echo "Server ready"; else echo "Server not ready..."; fi

.PHONY: ssh
ssh:
	ssh root@$$(terraform output ip | tr -d '\n')