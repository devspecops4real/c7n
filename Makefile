COMMON_STACK := c7n-common
COMMON_REGION := us-east-1
POLICY_REGIONS := us-west-2 us-east-1
MAILER_TO_ADDRESS := casey.lee@stelligent.com
MAILER_FROM_ADDRESS := casey.lee@stelligent.com

default: validate

deps:
	@echo "=== setup dependencies ==="
	@which aws || pip install --upgrade awscli
	pip install -r requirements.txt

cfn-validate: deps
	aws cloudformation validate-template --template-body file://cfn/common.yml

cfn: deps cfn-validate
	-@aws cloudformation describe-stacks --stack-name $(COMMON_STACK) --region $(COMMON_REGION) > /dev/null 2>&1; \
	if [ $$? -eq 0 ]; then \
        echo "=== updating cloudformation stack '$(COMMON_STACK)' in $(COMMON_REGION) ===" ; \
        aws cloudformation update-stack --stack-name $(COMMON_STACK) --template-body file://cfn/common.yml --capabilities CAPABILITY_IAM --region $(COMMON_REGION);  \
		if [ $$? -eq 0 ]; then \
			aws cloudformation wait stack-update-complete --stack-name $(COMMON_STACK) --region $(COMMON_REGION); \
		fi \
	else \
        echo "=== creating cloudformation stack '$(COMMON_STACK)' in $(COMMON_REGION) ==="; \
        aws cloudformation create-stack --stack-name $(COMMON_STACK) --template-body file://cfn/common.yml --capabilities CAPABILITY_IAM --region $(COMMON_REGION); \
        aws cloudformation wait stack-create-complete --stack-name $(COMMON_STACK) --region $(COMMON_REGION); \
	fi \

define get_stack_output
	$(eval $(1) := $(shell aws cloudformation describe-stacks --stack-name $(COMMON_STACK) --region $(COMMON_REGION) --query "Stacks[0].Outputs[?OutputKey=='$(2)'].OutputValue" --output text))
endef

cfn-outputs:
	$(call get_stack_output,MAILER_QUEUE,MailerQueue)
	$(call get_stack_output,MAILER_ROLE,MailerRole)
	$(call get_stack_output,POLICY_ROLE,PolicyRole)

mailer_file: cfn-outputs
	@mkdir -p .out/mailer/
	MAILER_FROM_ADDRESS=$(MAILER_FROM_ADDRESS) \
	MAILER_QUEUE=$(MAILER_QUEUE) \
	MAILER_ROLE=$(MAILER_ROLE) \
	COMMON_REGION=$(COMMON_REGION) \
	eval "echo \"$$(< mailer/mailer.yml)\"" > .out/mailer/mailer.yml

policy_files: cfn-outputs
	@mkdir -p .out/policies/
	@for f in policies/*.yml; do \
		echo .out/$$f; \
		MAILER_TO_ADDRESS=$(MAILER_TO_ADDRESS) \
		MAILER_QUEUE=$(MAILER_QUEUE) \
		eval "echo \"$$(< $$f)\"" > .out/$$f; \
	done

mailer: mailer_file
	cd mailer && python setup.py -q develop
	c7n-mailer -c .out/mailer/mailer.yml

$(POLICY_REGIONS): policy_files
	@echo "=== deploying policies to $@ ==="
	custodian run -c .out/policies/*.yml -s .out/ --assume $(POLICY_ROLE) --region $@

validate: cfn-validate mailer_file policy_files
	custodian validate .out/policies/*.yml

deploy: clean cfn mailer $(POLICY_REGIONS)

clean:
	rm -rf .out

.PHONY: default deps cfn mailer all clean policy_files mailer_file validate deploy