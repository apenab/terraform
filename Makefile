WEBSITE_REPO=github.com/hashicorp/terraform-website
VERSION?="0.3.44"

# generate runs `go generate` to build the dynamically generated
# source files, except the protobuf stubs which are built instead with
# "make protobuf".
generate:
	go generate ./...

# We separate the protobuf generation because most development tasks on
# Terraform do not involve changing protobuf files and protoc is not a
# go-gettable dependency and so getting it installed can be inconvenient.
#
# If you are working on changes to protobuf interfaces you may either use
# this target or run the individual scripts below directly.
protobuf:
	bash scripts/protobuf-check.sh
	bash internal/tfplugin5/generate.sh
	bash plans/internal/planproto/generate.sh

fmtcheck:
	@sh -c "'$(CURDIR)/scripts/gofmtcheck.sh'"

website:
ifeq (,$(wildcard $(GOPATH)/src/$(WEBSITE_REPO)))
	echo "$(WEBSITE_REPO) not found in your GOPATH (necessary for layouts and assets), get-ting..."
	git clone https://$(WEBSITE_REPO) $(GOPATH)/src/$(WEBSITE_REPO)
endif
	$(eval WEBSITE_PATH := $(GOPATH)/src/$(WEBSITE_REPO))
	@echo "==> Starting core website in Docker..."
	@docker run \
		--interactive \
		--rm \
		--tty \
		--publish "4567:4567" \
		--publish "35729:35729" \
		--volume "$(shell pwd)/website:/website" \
		--volume "$(shell pwd):/ext/terraform" \
		--volume "$(WEBSITE_PATH)/content:/terraform-website" \
		--volume "$(WEBSITE_PATH)/content/source/assets:/website/docs/assets" \
		--volume "$(WEBSITE_PATH)/content/source/layouts:/website/docs/layouts" \
		--workdir /terraform-website \
		hashicorp/middleman-hashicorp:${VERSION}

website-test:
ifeq (,$(wildcard $(GOPATH)/src/$(WEBSITE_REPO)))
	echo "$(WEBSITE_REPO) not found in your GOPATH (necessary for layouts and assets), get-ting..."
	git clone https://$(WEBSITE_REPO) $(GOPATH)/src/$(WEBSITE_REPO)
endif
	$(eval WEBSITE_PATH := $(GOPATH)/src/$(WEBSITE_REPO))
	@echo "==> Testing core website in Docker..."
	-@docker stop "tf-website-core-temp"
	@docker run \
		--detach \
		--rm \
		--name "tf-website-core-temp" \
		--publish "4567:4567" \
		--volume "$(shell pwd)/website:/website" \
		--volume "$(shell pwd):/ext/terraform" \
		--volume "$(WEBSITE_PATH)/content:/terraform-website" \
		--volume "$(WEBSITE_PATH)/content/source/assets:/website/docs/assets" \
		--volume "$(WEBSITE_PATH)/content/source/layouts:/website/docs/layouts" \
		--workdir /terraform-website \
		hashicorp/middleman-hashicorp:${VERSION}
	$(WEBSITE_PATH)/content/scripts/check-links.sh "http://127.0.0.1:4567" "/" "/docs/providers/*"
	@docker stop "tf-website-core-temp"

# disallow any parallelism (-j) for Make. This is necessary since some
# commands during the build process create temporary files that collide
# under parallel conditions.
.NOTPARALLEL:

.PHONY: fmtcheck generate protobuf website website-test
