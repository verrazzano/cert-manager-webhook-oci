# Portions of the code in this file are derived from https://github.com/cert-manager/webhook-example/blob/master/Makefile
# Portions of the code in this file are derived from https://gitlab.com/dn13/cert-manager-webhook-oci/-/blob/1.1.0/Makefile

OS ?= $(shell go env GOOS)
ARCH ?= $(shell go env GOARCH)

GO ?= GO111MODULE=on go
GO_LDFLAGS ?= -s -w -extldflags -static

OUT := $(shell pwd)/_out

KUBE_VERSION=1.24.2

DEFAULT_RETRIES:=5

#
# Retry a command a parameterized amount of times.
#
define retry_cmd
    for i in `seq 1 $1`; do $2 && break; done
endef

define retry_docker_push
    $(call retry_cmd,${DEFAULT_RETRIES},docker push $1)
endef

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Construct the build argument based on current Architecture (ARM or AMD)
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	EXEC_DIR_PATH:= bin/linux_amd64
	BUILD_CMD:= go-build-linux-amd
	BUILD_CMD_DEBUG:= go-build-linux-amd-debug
	BASE_IMAGE ?= ghcr.io/verrazzano/verrazzano-base:v1.0.0-20230327155846-4653b27@sha256:e82f7e630719a9f5a7309c41773385b273ec749f0e1ded96baa1a3f7a7e576e0
else ifeq ($(ARCH),aarch64)
	EXEC_DIR_PATH:= bin/linux_arm64
	BUILD_CMD:= go-build-linux-arm
	BUILD_CMD_DEBUG:= go-build-linux-arm-debug
	BASE_IMAGE ?= ghcr.io/oracle/oraclelinux:8-slim
endif


# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

NAME ?= cert-manager-webhook-oci
REPO_NAME:=cert-manager-webhook-oci

CREATE_LATEST_TAG=0
DOCKER_IMAGE_TAG ?= local-$(shell git rev-parse --short HEAD)
SHORT_COMMIT_HASH ?= $(shell git rev-parse --short=8 HEAD)
KUBECONFIG ?= ${HOME}/.kube/config

ifndef DOCKER_IMAGE_FULLNAME
DOCKER_IMAGE_NAME ?= ${NAME}-dev
DOCKER_IMAGE_FULLNAME=${DOCKER_IMAGE_NAME}
ifeq ($(MAKECMDGOALS),$(filter $(MAKECMDGOALS),docker-push push-tag))
	ifndef DOCKER_REPO
		$(error DOCKER_REPO must be defined as the name of the docker repository where image will be pushed)
	endif
	ifndef DOCKER_NAMESPACE
		$(error DOCKER_NAMESPACE must be defined as the name of the docker namespace where image will be pushed)
	endif
endif
ifdef DOCKER_NAMESPACE
DOCKER_IMAGE_FULLNAME := ${DOCKER_NAMESPACE}/${DOCKER_IMAGE_FULLNAME}
endif
ifdef DOCKER_REPO
DOCKER_IMAGE_FULLNAME := ${DOCKER_REPO}/${DOCKER_IMAGE_FULLNAME}
endif
endif

$(shell mkdir -p "$(OUT)")
export TEST_ASSET_ETCD=_test/kubebuilder/bin/etcd
export TEST_ASSET_KUBE_APISERVER=_test/kubebuilder/bin/kube-apiserver
export TEST_ASSET_KUBECTL=_test/kubebuilder/bin/kubectl

.PHONY: rendered-manifest.yaml
rendered-manifest.yaml:
	helm template \
	    cert-manager-webhook-oci \
        --set image.repository=$(DOCKER_IMAGE_FULLNAME) \
        --set image.tag=$(DOCKER_IMAGE_TAG) \
		--namespace cert-manager \
        deploy/cert-manager-webhook-oci > "$(OUT)/rendered-manifest.yaml"

#
# Go build related tasks
#
.PHONY: go-build
go-build:
	$(GO) build \
		-ldflags "${GO_LDFLAGS}" \
		-o bin/$(shell uname)_$(shell uname -m)/${NAME} \
		main.go

.PHONY: go-build-linux-amd
go-build-linux-amd:
	GOOS=linux GOARCH=amd64 $(GO) build \
		-ldflags "-s -w ${GO_LDFLAGS}" \
		-o bin/linux_amd64/${NAME} \
		main.go

.PHONY: go-build-linux-amd-debug
go-build-linux-amd-debug:
	GOOS=linux GOARCH=amd64 $(GO) build \
		-ldflags "${GO_LDFLAGS}" \
		-o out/linux_amd64/${NAME} \
		main.go

.PHONY: go-build-linux-arm
go-build-linux-arm:
	GOOS=linux GOARCH=arm64 $(GO) build \
		-ldflags "-s -w ${GO_LDFLAGS}" \
		-o bin/linux_arm64/${NAME} \
		main.go

.PHONY: go-build-linux-arm-debug
go-build-linux-arm-debug:
	GOOS=linux GOARCH=arm64 $(GO) build \
		-ldflags "${GO_LDFLAGS}" \
		-o out/linux_arm64/${NAME} \
		main.go

.PHONY: docker-build
docker-build: $(BUILD_CMD) docker-build-common

.PHONY: docker-build-common
docker-build-common:
	@echo Building ${NAME} image ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
	docker build --pull \
		--build-arg BASE_IMAGE=${BASE_IMAGE} \
		--build-arg EXEC_NAME=${NAME} \
		--build-arg EXEC_DIR=${EXEC_DIR_PATH} \
		-t ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .

.PHONY: docker-push
docker-push: docker-build docker-push-common

.PHONY: docker-push-debug
docker-push-debug: docker-build-debug docker-push-common

.PHONY: docker-push-common
docker-push-common:
	docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_FULLNAME}:${DOCKER_IMAGE_TAG}
	$(call retry_docker_push,${DOCKER_IMAGE_FULLNAME}:${DOCKER_IMAGE_TAG})
ifeq ($(CREATE_LATEST_TAG), "1")
	docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${DOCKER_IMAGE_FULLNAME}:latest;
	$(call retry_docker_push,${DOCKER_IMAGE_FULLNAME}:latest);
endif
