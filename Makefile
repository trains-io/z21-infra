# Versions
GO_VERSION          ?= 1.25.4
KUBECTL_VERSION     ?= v1.34.2
HELM_VERSION        ?= v4.0.0
KO_VERSION          ?= 0.18.0
KPT_VERSION         ?= v1.0.0-beta.58
KB_VERSION          ?= v4.10.1
NATS_SERVER_VERSION ?= v2.12.2
Z21SCAN_VERSION     ?= 0.0.4
Z21CLI_VERSION      ?= 0.0.3

BIN_DIR := $(CURDIR)/bin
BUILD   := $(CURDIR)/build

KPT_FN_APPLY_SETTERS_IMG := ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2

LOCAL_CLUSTER_NAME := dev

$(BIN_DIR):
	@mkdir -p $@

$(BUILD):
	@mkdir -p $@

KIND    ?= $(BIN_DIR)/kind
GO      ?= $(BIN_DIR)/go/bin/go
K       ?= $(BIN_DIR)/kubectl
HELM    ?= $(BIN_DIR)/helm
KO      ?= $(BIN_DIR)/ko
KPT     ?= $(BIN_DIR)/kpt
KB      ?= $(BIN_DIR)/kubebuilder
NATS    ?= $(BIN_DIR)/nats-server
Z21SCAN ?= $(BIN_DIR)/z21scan
Z21CLI  ?= $(BIN_DIR)/z21cli

TOOLS := $(GO) \
		 $(K) \
		 $(HELM) \
		 $(KO) \
		 $(KPT) \
		 $(KB) \
		 $(NATS) \
		 $(Z21SCAN) \
		 $(Z21CLI)

.PHONY: all
all: tools kind manifest env ## Download tools, launch kind, build and apply manifests, and generate env

############################
# TOOLS
############################
PHONY: tools
tools: $(TOOLS) ## Download tools (e.g. kubectl, kpt, ko, ...)

.PHONY: go
go: $(GO) ## Download go
$(GO): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(GO_VERSION) ..."
	@curl -fsSL -o /tmp/go.tar.gz https://go.dev/dl/go$(GO_VERSION).linux-amd64.tar.gz
	@tar -xzf /tmp/go.tar.gz -C $(BIN_DIR)

.PHONY: kubectl
kubectl: $(K) ## Download kubectl
$(K): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(KUBECTL_VERSION) ..."
	@curl -fsSL -o $@ https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
	@chmod +x $@

.PHONY: helm
helm: $(HELM) ## Download helm
$(HELM): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(HELM_VERSION) ..."
	@curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-$(HELM_VERSION)-linux-amd64.tar.gz
	@tar -xzf /tmp/helm.tar.gz -C /tmp
	@mv /tmp/linux-amd64/helm $@
	@chmod +x $@
	@rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

.PHONY: ko
ko: $(KO) ## Download ko
$(KO): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(KO_VERSION) ..."
	@curl -fsSL -o /tmp/ko.tar.gz https://github.com/ko-build/ko/releases/download/v${KO_VERSION}/ko_${KO_VERSION}_linux_x86_64.tar.gz
	@tar -xzf /tmp/ko.tar.gz $$(basename $@)
	@mv $$(basename $@) $@
	@chmod +x $@
	@rm -rf /tmp/ko.tar.gz

.PHONY: kpt
kpt: $(KPT) ## Download kpt
$(KPT): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(KPT_VERSION) ..."
	@curl -fsSL -o $@ https://github.com/kptdev/kpt/releases/download/v1.0.0-beta.59/kpt_linux_amd64
	@chmod +x $@

.PHONY: kubebuilder
kubebuilder: $(KB) ## Download kubebuilder
$(KB): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(KB_VERSION) ..."
	@curl -fsSL -o $@ https://github.com/kubernetes-sigs/kubebuilder/releases/download/${KB_VERSION}/kubebuilder_linux_amd64
	@chmod +x $@

.PHONY: nats-server
nats-server: $(NATS) ## Download NATS server
$(NATS): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(NATS_SERVER_VERSION) ..."
	@curl -fsSL https://binaries.nats.dev/nats-io/nats-server/v2@$(NATS_SERVER_VERSION) | sh >/dev/null
	@mv $$(basename $@) $(BIN_DIR)

.PHONY: z21scan
z21scan: $(Z21SCAN) ## Download z21scan
$(Z21SCAN): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(Z21SCAN_VERSION) ..."
	@curl -fsSL -o /tmp/z21scan.zip https://github.com/trains-io/z21scan/releases/download/v$(Z21SCAN_VERSION)/z21scan-$(Z21SCAN_VERSION)-linux-amd64.zip
	@unzip /tmp/z21scan.zip z21scan -d $(BIN_DIR) >/dev/null
	@rm -rf /tmp/z21scan.zip

.PHONY: z21cli
z21cli: $(Z21CLI) ## Download z21cli
$(Z21CLI): | $(BIN_DIR)
	@echo "Downloading $$(basename $@) $(Z21CLI_VERSION) ..."
	@curl -fsSL -o /tmp/z21cli.zip https://github.com/trains-io/z21cli/releases/download/v$(Z21CLI_VERSION)/z21cli-$(Z21CLI_VERSION)-linux-amd64.zip
	@unzip /tmp/z21cli.zip z21cli -d $(BIN_DIR) >/dev/null
	@rm -rf /tmp/z21cli.zip

############################
# KIND
############################
.PHONY: kind
kind: ## Launch a local KinD cluster
	@echo "Creating local cluster \"$(LOCAL_CLUSTER_NAME)\" ..."
	@$(KIND) create cluster --name $(LOCAL_CLUSTER_NAME) 2>/dev/null || true
	@$(K) config use-context kind-$(LOCAL_CLUSTER_NAME)

	@echo "Installing NATS ..."
	@$(HELM) repo add nats https://nats-io.github.io/k8s/helm/charts/ || true
	@$(HELM) install nats nats/nats 2>/dev/null || true

.PHONY: manifest
manifest: $(BUILD) ## Build and apply k8s manifests for local deployment
	@echo "Building manifests with kpt ..."
	@rm -rf $(BUILD)/manifests
	@$(KPT) fn eval manifests/ \
		--image $(KPT_FN_APPLY_SETTERS_IMG) \
		-o $(BUILD)/manifests \
		-- z21-name=main \
		   z21-addr=${Z21_ADDR}

	@echo "Applying manifests ..."
	@$(K) apply -f $(BUILD)/manifests

############################
# ENV
############################
.PHONY: env
env: ## Generate environment
	@echo "export PATH=$(BIN_DIR):$(BIN_DIR)/go/bin:\$$PATH" > .env
	@echo "" >> .env
	@echo "# Run natscli inside kubernetes" >> .env
	@echo "alias nats=\"kubectl exec -it deployment/nats-box -- nats\"" >> .env

############################
# CLEAN UP
############################
.PHONY: teardown
teardown: ## Delete local KinD cluster
	@$(KIND) delete cluster -n $(LOCAL_CLUSTER_NAME) || true
	@$(HELM) repo remove nats

.PHONY: clean
clean: ## Remove tools and build files
	@rm -rf $(BIN_DIR)
	@rm -rf $(BUILD)

.PHONY: mrproper
mrproper: teardown clean ## Remove tools, teardown local KinD cluster, and env
	@rm -rf .env

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'
