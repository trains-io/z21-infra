# Versions
GO_VERSION          ?= 1.25.4
KUBECTL_VERSION     ?= v1.34.2
HELM_VERSION        ?= v4.0.0
KO_VERSION          ?= 0.18.0
KPT_VERSION         ?= v1.0.0-beta.58
NATS_SERVER_VERSION ?= v2.12.2
Z21SCAN_VERSION     ?= 0.0.4
Z21CLI_VERSION      ?= 0.0.3

BIN_DIR := $(CURDIR)/bin
GO_DIR  := $(CURDIR)

LOCAL_CLUSTER_NAME := dev

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(GO_DIR):
	mkdir -p $(GO_DIR)

GO      ?= go
K       ?= kubectl
HELM    ?= helm
KO      ?= ko
KPT     ?= kpt
NATS    ?= nats-server
Z21SCAN ?= z21scan
Z21CLI  ?= z21cli

TOOLS := $(GO) $(K) $(HELM) $(KO) $(KPT) $(NATS) $(Z21SCAN) $(Z21CLI)

.PHONY: all
all: tools kind env ## Download tools, launch kind, and generate env

############################
# TOOLS
############################
PHONY: tools
tools: $(TOOLS) ## Download tools (e.g. kubectl, kpt, ko, ...)

.PHONY: go
go: $(GO_DIR) ## Download go
	curl -fsSL -o /tmp/go.tar.gz https://go.dev/dl/go$(GO_VERSION).linux-amd64.tar.gz
	tar -xzf /tmp/go.tar.gz -C $(GO_DIR)

.PHONY: kubectl
kubectl: $(BIN_DIR) ## Download kubectl
	curl -fsSL -o $(BIN_DIR)/$@ https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl
	chmod +x $(BIN_DIR)/$@

.PHONY: helm
helm: $(BIN_DIR) ## Download helm
	curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-$(HELM_VERSION)-linux-amd64.tar.gz
	tar -xzf /tmp/helm.tar.gz -C /tmp
	mv /tmp/linux-amd64/helm $(BIN_DIR)/$@
	chmod +x $(BIN_DIR)/$@
	rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

.PHONY: ko
ko: $(BIN_DIR) ## Download ko
	curl -fsSL -o /tmp/ko.tar.gz https://github.com/ko-build/ko/releases/download/v${KO_VERSION}/ko_${KO_VERSION}_linux_x86_64.tar.gz
	tar -xzf /tmp/ko.tar.gz $@
	mv $@ $(BIN_DIR)/$@
	chmod +x $(BIN_DIR)/$@
	rm -rf /tmp/ko.tar.gz

.PHONY: kpt
kpt: $(BIN_DIR) ## Download kpt
	curl -fsSL -o $(BIN_DIR)/$@ https://github.com/kptdev/kpt/releases/download/v1.0.0-beta.59/kpt_linux_amd64
	chmod +x $(BIN_DIR)/$@

.PHONY: nats-server
nats-server: $(BIN_DIR) ## Download NATS server
	curl -fsSL https://binaries.nats.dev/nats-io/nats-server/v2@$(NATS_SERVER_VERSION) | sh
	mv $@ $(BIN_DIR)

.PHONY: z21scan
z21scan: $(BIN_DIR) ## Download z21scan
	curl -fsSL -o /tmp/z21scan.zip https://github.com/trains-io/z21scan/releases/download/v$(Z21SCAN_VERSION)/z21scan-$(Z21SCAN_VERSION)-linux-amd64.zip
	unzip /tmp/z21scan.zip z21scan -d $(BIN_DIR)
	rm -rf /tmp/z21scan.zip

.PHONY: z21cli
z21cli: $(BIN_DIR) ## Download z21cli
	curl -fsSL -o /tmp/z21cli.zip https://github.com/trains-io/z21cli/releases/download/v$(Z21CLI_VERSION)/z21cli-$(Z21CLI_VERSION)-linux-amd64.zip
	unzip /tmp/z21cli.zip z21cli -d $(BIN_DIR)
	rm -rf /tmp/z21cli.zip

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

	@echo "Installing fluentbit ..."
	@$(HELM) repo add fluent https://fluent.github.io/helm-charts || true
	@$(HELM) install fluent-bit fluent/fluent-bit 2>/dev/null || true

############################
# ENV
############################
.PHONY: env
env: ## Generate environment
	@echo "export PATH=$(BIN_DIR):$(GO_DIR)/go/bin:\$$PATH" > .env
	@echo "" >> .env
	@echo "# Run natscli inside kubernetes" >> .env
	@echo "alias nats=\"kubectl exec -it deployment/nats-box -- nats\"" >> .env

############################
# CLEAN UP
############################
.PHONY: teardown
teardown: ## Delete local KinD cluster
	@$(KIND) delete cluster -n $(LOCAL_CLUSTER_NAME) || true
	@$(HELM) repo remove nats || true
	@$(HELM) repo remove fluentbit || true

.PHONY: clean
clean: ## Remove tools
	rm -rf $(BIN_DIR)

.PHONY: mrproper
mrproper: teardown clean ## Remove tools, teardown local KinD cluster, and env
	rm -rf .env

.PHONY: help
help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'
