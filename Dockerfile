
ARG TERRAFORM_VERSION="0.12.29"

ARG TERRAGRUNT_VERSION="0.24.1"
ARG TERRAGRUNT_SHA256="3f83d225d1335dc02a20fa604ee3ea7f14efcd68e952b902652b7287eed8c18b"

ARG TFLINT_VERSION="0.19.1"
ARG TFLINT_SHA256="cbc01d58a9c4471b9c0b39507a298bdb0fa06d6c48facb578dc8eddf022dbbd2"

ARG TFSEC_VERSION="0.25.0"
ARG TFSEC_SHA256="e5dfd73a286d8c57abce2545ac178ce76ec8e12fb13056039d85f7b250417c26"

ARG CONFTEST_VERSION="0.20.0"
ARG CONFTEST_SHA256="6647697fd811daa3fcd0777654181b5ad4d7dda67dcab358a01fc821801bc0a1"

ARG TERRAFORM_COMPLIANCE_VERSION="1.3.4"

FROM golang:alpine AS builder
WORKDIR /go
RUN apk add --update --no-cache bash git openssh
RUN go get -v github.com/hashicorp/go-getter/cmd/go-getter || true
RUN cd /go && go install -v github.com/hashicorp/go-getter/cmd/go-getter

FROM hashicorp/terraform:${TERRAFORM_VERSION}

ARG TERRAGRUNT_VERSION
ARG TERRAGRUNT_SHA256
ARG TFLINT_VERSION
ARG TFLINT_SHA256
ARG TFSEC_VERSION
ARG TFSEC_SHA256
ARG CONFTEST_VERSION
ARG CONFTEST_SHA256
ARG TERRAFORM_COMPLIANCE_VERSION

RUN apk add --update --no-cache bash git openssh curl jq unzip
RUN apk add --no-cache --virtual .build-deps \
        gcc \
        python3-dev \
        musl-dev \
    && apk add --no-cache \
        python3 py3-pip \
    && pip3 install awscli boto3 \
    && echo "==> Downloading terragrunt..." \
    && curl -vfSL https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt \
    && sha256sum /usr/local/bin/terragrunt \
    && echo "${TERRAGRUNT_SHA256}  /usr/local/bin/terragrunt" | sha256sum -c - \
    && chmod +x /usr/local/bin/terragrunt \
    && echo "==> Downloading tfsec..." \
    && curl -vfSL https://github.com/liamg/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64 -o /usr/local/bin/tfsec \
    && sha256sum /usr/local/bin/tfsec \
    && echo "${TFSEC_SHA256}  /usr/local/bin/tfsec" | sha256sum -c - \
    && chmod +x /usr/local/bin/tfsec \
    && echo "==> Downloading conftest..." \
    && curl -vfSL https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz -o /tmp/conftest.tar.gz \
    && sha256sum /tmp/conftest.tar.gz \
    && echo "${CONFTEST_SHA256}  /tmp/conftest.tar.gz" | sha256sum -c - \
    && tar -C /usr/local/bin -xvzf /tmp/conftest.tar.gz conftest \
    && chmod +x /usr/local/bin/conftest \
    && echo "==> Downloading tflint..." \
    && curl -vfSL https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip -o /tmp/tflint.zip \
    && sha256sum /tmp/tflint.zip \
    && echo "${TFLINT_SHA256}  /tmp/tflint.zip" | sha256sum -c - \
    && unzip /tmp/tflint.zip -d /usr/local/bin tflint \
    && chmod +x /usr/local/bin/tflint \
    && pip install --upgrade pip \
    && pip install terraform-compliance=="${TERRAFORM_COMPLIANCE_VERSION}" \
    && pip uninstall -y radish radish-bdd \
    && pip install radish radish-bdd \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/*

#
COPY --from=builder /go/bin/go-getter /usr/local/bin/go-getter

WORKDIR /apps

ENTRYPOINT []
