
ARG TERRAFORM_VERSION="1.0.4"

ARG TERRAGRUNT_VERSION="0.31.3"
ARG TERRAGRUNT_SHA256="7c79777b89a5cd5aab9ae30e33bbcb49b3b43c6c5277d1819c2387ae30277abb"

ARG TFLINT_VERSION="0.30.0"
ARG TFLINT_SHA256="6daa361a9f9bccb173c644ffd445fc71e7b649253808d6b76e3fac294a9de68d"

ARG TFSEC_VERSION="0.56.0"
ARG TFSEC_SHA256="2edbb9338d9c4879343d56e2b2b46b5f3a41104412f4c8710311e7b8639801cd"

ARG OPA_VERSION="v0.31.0"
ARG OPA_REPO="https://github.com/open-policy-agent/opa.git"

ARG CONFTEST_VERSION="v0.26.0"
ARG CONFTEST_REPO="https://github.com/open-policy-agent/conftest.git"

ARG GOGETTER_VERSION="v1.5.5"
ARG GOGETTER_REPO="https://github.com/hashicorp/go-getter.git"

ARG TERRAFORM_COMPLIANCE_VERSION="1.3.24"

FROM golang:alpine AS builder
ARG CONFTEST_VERSION
ARG CONFTEST_REPO
ARG OPA_VERSION
ARG OPA_REPO
ARG GOGETTER_VERSION
ARG GOGETTER_REPO
WORKDIR /go
RUN apk add --update --no-cache bash git openssh
RUN git clone ${GOGETTER_REPO} go-getter \
    && cd go-getter && git checkout ${GOGETTER_VERSION} \
    && go mod download \
    && go build -o /go/bin/go-getter ./cmd/go-getter/
RUN git clone ${CONFTEST_REPO} conftest \
    && cd conftest && git checkout ${CONFTEST_VERSION} \
    && go mod download \
    && CGO_ENABLED=0 go build -o /go/bin/conftest -ldflags="-w -s" main.go
RUN git clone ${OPA_REPO} opa \
    && cd opa && git checkout ${OPA_VERSION} \
    && go mod download \
    && go build -o /go/bin/opa .

FROM hashicorp/terraform:${TERRAFORM_VERSION}
ARG TERRAGRUNT_VERSION
ARG TERRAGRUNT_SHA256
ARG TFLINT_VERSION
ARG TFLINT_SHA256
ARG TFSEC_VERSION
ARG TFSEC_SHA256
ARG TERRAFORM_COMPLIANCE_VERSION

RUN apk add --update --no-cache bash git openssh curl jq unzip libxml2 libxslt make
RUN apk add --no-cache --virtual .build-deps \
        gcc \
        python3-dev \
        musl-dev \
        libxml2-dev \
        libxslt-dev \
    && apk add --no-cache \
        python3 py3-pip \
    && pip3 install --upgrade pip \
    && pip3 install awscli boto3 \
    && pip3 install terraform-compliance=="${TERRAFORM_COMPLIANCE_VERSION}" \
    && pip3 uninstall -y radish radish-bdd \
    && pip3 install radish radish-bdd \
    && pip3 install junit2html \
    && echo "==> Downloading terragrunt..." \
    && curl -vfSL https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt \
    && sha256sum /usr/local/bin/terragrunt \
    && echo "${TERRAGRUNT_SHA256}  /usr/local/bin/terragrunt" | sha256sum -c - \
    && chmod +x /usr/local/bin/terragrunt \
    && echo "==> Downloading tflint..." \
    && curl -vfSL https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip -o /tmp/tflint.zip \
    && sha256sum /tmp/tflint.zip \
    && echo "${TFLINT_SHA256}  /tmp/tflint.zip" | sha256sum -c - \
    && unzip /tmp/tflint.zip -d /usr/local/bin tflint \
    && chmod +x /usr/local/bin/tflint \
    && echo "==> Downloading tfsec..." \
    && curl -vfSL https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64 -o /usr/local/bin/tfsec \
    && sha256sum /usr/local/bin/tfsec \
    && echo "${TFSEC_SHA256}  /usr/local/bin/tfsec" | sha256sum -c - \
    && chmod +x /usr/local/bin/tfsec \
    && mkdir -p /code /reports \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /root/.cache

#
COPY --from=builder /go/bin/go-getter /usr/local/bin/go-getter
COPY --from=builder /go/bin/conftest /usr/local/bin/conftest
COPY --from=builder /go/bin/opa /usr/local/bin/opa
COPY  scripts/terraform-fmt-test /usr/local/bin/terraform-fmt-test
COPY  scripts/terragrunt-generate-plan /usr/local/bin/terragrunt-generate-plan

WORKDIR /code

ENTRYPOINT []
