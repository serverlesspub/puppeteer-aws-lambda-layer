ORG := serverles.pub
DEPLOYMENT_BUCKET_NAME := desole-packaging
BASE_NAME := puppeteer
STACK_NAME := $(BASE_NAME)-layer
PACKAGE := aws-lambda-$(STACK_NAME)
DEPLOYMENT_KEY := $(shell echo $(BASE_NAME)-$$RANDOM.zip)


SOURCES=$(shell find src/)

clean:
	rm -rf build

build/local-chromium.zip: docker/Dockerfile $(SOURCES)
	mkdir -p build
	docker build -t $(ORG)/$(PACKAGE) -f docker/Dockerfile src
	rm -rf build/nodejs build/local-chromium.zip
	# https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html#configuration-layers-path
	
	docker run -d $(ORG)/$(PACKAGE) > build/container_id
	docker cp `cat build/container_id`:/task build/nodejs
	docker stop `cat build/container_id`
	cd build/nodejs/node_modules/puppeteer && zip -ry ../../../local-chromium.zip .local-chromium 
	rm -rf build/nodejs/node_modules/puppeteer/.local-chromium

build/layer.zip: build/local-chromium.zip
	cd build && zip -ry layer.zip nodejs local-chromium.zip

# cloudformation has no support for packaging layers yet, so need to do this manually
#
build/output.yml: build/layer.zip cloudformation/template.yml
	aws s3 cp build/layer.zip s3://$(DEPLOYMENT_BUCKET_NAME)/$(DEPLOYMENT_KEY)
	sed "s:DEPLOYMENT_BUCKET_NAME:$(DEPLOYMENT_BUCKET_NAME):;s:DEPLOYMENT_KEY:$(DEPLOYMENT_KEY):" cloudformation/template.yml > build/output.yml

deploy: build/output.yml
	aws cloudformation deploy --template-file build/output.yml --stack-name $(STACK_NAME)
	aws cloudformation describe-stacks --stack-name $(STACK_NAME) --query Stacks[].Outputs[].OutputValue --output text

