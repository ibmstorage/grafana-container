# Build stage 1

FROM registry.redhat.io/rhel8/go-toolset:1.13 AS builder

COPY grafana /grafana

ENV IMPORT_PATH=github.com/grafana/grafana
ENV GOPATH=/grafana

WORKDIR /grafana
RUN \
    mv -f vendor src && \
    mkdir -p "src/$IMPORT_PATH" && \
    rm -rf "src/$IMPORT_PATH" && \
    ln -s /grafana "src/$IMPORT_PATH" && \
    ls -l "/grafana/src/$IMPORT_PATH"

WORKDIR /grafana

ENV GOFLAGS="-mod=vendor"

RUN go run build.go -dev build

# Build stage 2
FROM registry.redhat.io/ubi8/ubi:latest

# Update the image to get the latest CVE updates
RUN yum update -y --setopt=install_weak_deps=False

ENV PATH=/usr/share/grafana/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning"

COPY plugins.tar /plugins.tar

RUN rm -rf $GF_PATHS_HOME && mkdir -p $GF_PATHS_HOME
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
RUN groupadd -r -g 472 grafana
RUN useradd -r -u 472 -g grafana -d /etc/grafana -s /sbin/nologin -c "Grafana Dashboard" grafana

RUN mkdir -p "$GF_PATHS_HOME/.aws" && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    chown -R grafana:grafana "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" && \
    chmod 775 "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" /run.sh && \
    tar -C / -xvf /plugins.tar && \
    rm -f /plugins.tar

EXPOSE 3000

USER grafana
WORKDIR /
ENTRYPOINT [ "/run.sh" ]

# Build specific labels
LABEL maintainer="Boris Ranto <branto@redhat.com>"
LABEL com.redhat.component="grafana-container"
LABEL version=4
LABEL name="grafana"
LABEL description="Red Hat Ceph Storage 4 Grafana container"
LABEL summary="Provides the Grafana container on RHEL 8 for Red Hat Ceph Storage 4."
LABEL io.k8s.display-name="Grafana on RHEL 8"
LABEL io.openshift.tags="rhceph ceph dashboard grafana"
LABEL cpe=cpe:/a:redhat:ceph_storage:4.3::el8
