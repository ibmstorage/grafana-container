# Build stage 1

ARG BASE_IMAGE=registry.redhat.io/ubi9/go-toolset:latest

FROM ${BASE_IMAGE} AS builder

# Grafana tends to use the fodlers from the root directory.
USER root

COPY grafana /grafana

WORKDIR /grafana

ENV GOFLAGS="-mod=vendor"

RUN go run -mod vendor build.go -dev build

# Build stage 2
FROM registry.redhat.io/ubi10-minimal:latest

# Update the image to get the latest CVE updates
RUN microdnf update -y

ENV PATH=/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/usr/share/grafana/plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

RUN rm -rf $GF_PATHS_HOME && mkdir -p $GF_PATHS_HOME
COPY --from=builder /grafana/bin/grafana /usr/bin/grafana
COPY --from=builder /grafana/bin/grafana-server /usr/bin/grafana-server
COPY --from=builder /grafana/bin/grafana-cli /usr/bin/grafana-cli
COPY --from=builder /grafana/conf $GF_PATHS_HOME/conf/
COPY --from=builder /grafana/docs $GF_PATHS_HOME/docs/
COPY --from=builder /grafana/public $GF_PATHS_HOME/public/
COPY --from=builder /grafana/scripts $GF_PATHS_HOME/scripts/

RUN rm -rf /etc/grafana && mkdir -p /etc/grafana
COPY --from=builder /grafana/conf/sample.ini $GF_PATHS_CONFIG
COPY --from=builder /grafana/conf/ldap.toml /etc/grafana/ldap.toml
COPY ./run.sh /run.sh

# Create grafana user/group
RUN microdnf install -y shadow-utils
RUN groupadd -r -g 472 grafana
RUN useradd -r -u 472 -g grafana -d /etc/grafana -s /sbin/nologin -c "Grafana Dashboard" grafana

# Unpack plugins and update permissions
RUN mkdir -p "$GF_PATHS_HOME/.aws" && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_PROVISIONING/notifiers" \
             "$GF_PATHS_PROVISIONING/plugins" \
             "$GF_PATHS_PROVISIONING/access-control" \
             "$GF_PATHS_PROVISIONING/alerting" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" "$GF_PATHS_PROVISIONING" && \
    chmod -R 775 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" "$GF_PATHS_PROVISIONING" /run.sh

RUN mkdir /licenses
COPY ./licenses /licenses

EXPOSE 3000

USER grafana
WORKDIR /
ENTRYPOINT [ "/run.sh" ]

# Build specific labels
LABEL maintainer="Nizamudeen A <nia@redhat.com>"
LABEL com.redhat.component="grafana-container"
LABEL version="12.4.2"
LABEL name=rhceph/grafana-rhel10
LABEL description="Red Hat Ceph Storage Grafana container"
LABEL summary="Grafana container on RHEL 10 for Red Hat Ceph Storage"
LABEL io.k8s.display-name="Grafana on RHEL 10"
LABEL io.k8s.description="grafana-container"
LABEL io.openshift.tags="rhceph ceph dashboard grafana"
LABEL cpe=cpe:/a:redhat:ceph_storage:9.1::el10

# Z-stream indicator
LABEL Z-VERSION="9.1z1"
