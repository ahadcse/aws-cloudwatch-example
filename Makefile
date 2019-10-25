#!/usr/bin/env bash

ENVIRONMENT ?= dev
SERVICE ?= aws-cloudwatch-example
AWS_REGION ?= eu-west-1
BITBUCKET_BUILD_NUMBER ?= localbuild

ARTIFACTS_BUCKET:=artifactory-deployment-$(ENVIRONMENT)
ARTIFACTS_PREFIX:=$(SERVICE)

ALARMS_STACK = $(SERVICE)-alarms
TOPICS_STACK = $(SERVICE)-topics

cfn-package = @echo "\n----- CFN package START -----\n" && \
	mkdir -p cloudformation/dist  && \
	aws cloudformation package \
	--template-file cloudformation/${1} \
	--output-template-file cloudformation/dist/${1} \
	--s3-bucket $(ARTIFACTS_BUCKET) \
	--s3-prefix $(ARTIFACTS_PREFIX) && \
	echo "\n----- CFN package DONE -----\n"

cfn-deploy = @echo "\n----- Deployment START -----\n" && \
	aws cloudformation deploy \
	--template-file cloudformation/dist/${1} \
	--stack-name ${2} \
	--capabilities CAPABILITY_NAMED_IAM \
	--region $(AWS_REGION) \
	--tags "Environment=$(ENVIRONMENT)" \
	--parameter-overrides Environment=$(ENVIRONMENT) Service=$(STACK_NAME) && \
	date && \
	echo "\n----- Deployment DONE -----\n"

cfn-deploy-s3 = aws cloudformation deploy \
	--template-file cloudformation/dist/s3.yml \
	--stack-name $(SERVICE)-s3 \
	--region $(AWS_REGION) \
	--tags Environment=$(ENVIRONMENT) \
	--parameter-overrides \
		BucketName=$(ARTIFACTS_BUCKET)

.PHONY: deployment-bucket
deployment_bucket:
	$(call cfn-package,s3.yml)
	$(call cfn-deploy-s3)

.PHONY: package-topics
package-topics:
	$(call cfn-package,sqsAlarmTopics.yml)

.PHONY: deploy-topics
deploy-topics:
	$(call cfn-deploy,sqsAlarmTopics.yml,$(TOPICS_STACK))

.PHONY: package-alarms
package-alarms:
	$(call cfn-package,sqsAlarms.yml)

.PHONY: deploy-alarms
deploy-alarms:
	$(call cfn-deploy,sqsAlarms.yml,$(ALARMS_STACK))

.PHONY: deploy
deploy:
	$(call cfn-package,s3.yml)
	$(call cfn-deploy-s3)
	$(call cfn-package,sqsAlarms.yml)
	$(call cfn-package,sqsAlarmTopics.yml)
	$(call cfn-deploy,sqsAlarms.yml,$(ALARMS_STACK))
	$(call cfn-deploy,sqsAlarmTopics.yml,$(TOPICS_STACK))
