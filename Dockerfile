ARG BASE_IMAGE=ghcr.io/oracle/oraclelinux:8-slim
FROM $BASE_IMAGE AS build_base

ARG EXEC_NAME=cert-manager-webhook-oci
ARG EXEC_DIR=bin/linux_amd64
# ENV CERT_MANAGER_ENTRY_POINT=$EXEC_NAME

WORKDIR /workspace

# Copy the Go binary to the work directory
COPY ${EXEC_DIR}/${EXEC_NAME} .

FROM $BASE_IMAGE AS final

# Create the necessary user and group to run the image as user 1000
RUN groupadd -r webhook \
        && useradd --no-log-init -r -m -d /webhook -g webhook -u 1000 webhook \
        && mkdir /home/webhook \
        && chown -R 1000:webhook /home/webhook

COPY --from=build_base --chown=1000:webhook /workspace/${EXEC_NAME} /home/webhook/${EXEC_NAME}

COPY LICENSE SECURITY.md THIRD_PARTY_LICENSES.txt /licenses/

USER 1000

RUN ls -ltr /home/webhook/${EXEC_NAME}

ENTRYPOINT ["/home/webhook/cert-manager-webhook-oci"]
