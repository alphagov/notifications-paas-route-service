.DEFAULT_GOAL := help
SHELL := /bin/bash

CF_ORG = govuk-notify
CF_APP_NAME ?= route-service

$(eval export CF_APP_NAME=${CF_APP_NAME})

.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: generate-manifest
generate-manifest: ## Generates the PaaS manifest file
	$(if ${CF_SPACE},,$(error Must specify CF_SPACE))
	$(if ${NOTIFY_CREDENTIALS},,$(error Must specify NOTIFY_CREDENTIALS))
	erb manifest.yml.erb

.PHONY: api
api:
	$(eval export SUBDOMAIN=api)
	@true

.PHONY: admin
admin:
	$(eval export SUBDOMAIN=www)
	@true

.PHONY: preview
preview: ## Set PaaS space to preview
	$(eval export CF_SPACE=preview)
	$(eval export BASE_DOMAIN=notify.works)
	@true

.PHONY: staging
staging: ## Set PaaS space to staging
	$(eval export CF_SPACE=staging)
	$(eval export CF_INSTANCES=2)
	# $(eval export BASE_DOMAIN=staging-notify.works)
	@true

.PHONY: production
production: ## Set PaaS space to production
	$(eval export CF_SPACE=production)
	$(eval export CF_INSTANCES=2)
	# $(eval export BASE_DOMAIN=notifications.service.gov.uk)
	@true

.PHONY: check-variables
check-variables:
	$(if ${CF_SPACE},,$(error Must specify CF_SPACE))
	cf target -s ${CF_SPACE}

.PHONY: add-cloudfront-ips
add-cloudfront-ips:
	./add_cloudfront_ips.sh

.PHONY: cf-push
cf-push: check-variables add-cloudfront-ips ## Pushes the app to Cloud Foundry (causes downtime!)
	cf push -f <(make -s generate-manifest)
	rm nginx.conf

.PHONY: cf-deploy
cf-deploy: check-variables add-cloudfront-ips ## Deploys the app to Cloud Foundry without downtime
	@cf app --guid ${CF_APP_NAME} || exit 1
	cf rename ${CF_APP_NAME} ${CF_APP_NAME}-rollback
	cf push -f <(make -s generate-manifest)
	cf scale -i $$(cf curl /v2/apps/$$(cf app --guid ${CF_APP_NAME}) | jq -r ".entity.instances" 2>/dev/null || echo "1") ${CF_APP_NAME}
	cf stop ${CF_APP_NAME}-rollback
	cf delete -f ${CF_APP_NAME}-rollback
	rm nginx.conf

.PHONY: cf-rollback
cf-rollback: check-variables ## Rollbacks the app to the previous release
	@cf app --guid ${CF_APP_NAME}-rollback || exit 1
	@[ $$(cf curl /v2/apps/`cf app --guid ${CF_APP_NAME}-rollback` | jq -r ".entity.state") = "STARTED" ] || (echo "Error: rollback is not possible because ${CF_APP_NAME}-rollback is not in a started state" && exit 1)
	cf delete -f ${CF_APP_NAME} || true
	cf rename ${CF_APP_NAME}-rollback ${CF_APP_NAME}

.PHONY: cf-create-route-service
cf-create-route-service: check-variables ## Creates the route service
	cf create-user-provided-service ${CF_APP_NAME} -r https://notify-${CF_APP_NAME}-${CF_SPACE}.cloudapps.digital

.PHONY: cf-bind-route-service
cf-bind-route-service: check-variables ## Binds the route service to the given route
	$(if ${SUBDOMAIN},,$(error Must specify SUBDOMAIN))
	cf bind-route-service ${BASE_DOMAIN} ${CF_APP_NAME} --hostname ${SUBDOMAIN}

.PHONY: cf-unbind-route-service
cf-unbind-route-service: check-variables ## Binds the route service to the given route
	$(if ${SUBDOMAIN},,$(error Must specify SUBDOMAIN))
	cf unbind-route-service ${BASE_DOMAIN} ${CF_APP_NAME} --hostname ${SUBDOMAIN}
