FROM alpine:3.6

# Alpine packages
RUN apk --no-cache \
    add \
        curl \
        bash \
        ca-certificates

# The Consul binary
ENV CONSUL_VERSION=1.0.1
RUN export CONSUL_CHECKSUM=eac5755a1d19e4b93f6ce30caaf7b3bd8add4557b143890b1c07f5614a667a68 \
    && export archive=consul_${CONSUL_VERSION}_linux_amd64.zip \
    && curl -Lso /tmp/${archive} https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${archive} \
    && echo "${CONSUL_CHECKSUM}  /tmp/${archive}" | sha256sum -c \
    && cd /bin \
    && unzip /tmp/${archive} \
    && chmod +x /bin/consul \
    && rm /tmp/${archive}

# Add Containerpilot and set its configuration
ENV CONTAINERPILOT_VER 3.5.1
ENV CONTAINERPILOT /etc/containerpilot.json5

RUN export CONTAINERPILOT_CHECKSUM=7ee8e59588b6b593325930b0dc18d01f666031d7 \
    && curl -Lso /tmp/containerpilot.tar.gz \
         "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz

# Add Prometheus exporter
RUN curl --fail -sL https://github.com/prometheus/consul_exporter/releases/download/v0.3.0/consul_exporter-0.3.0.linux-amd64.tar.gz |\
    tar -xzO -f - consul_exporter-0.3.0.linux-amd64/consul_exporter > /usr/local/bin/consul_exporter &&\
    chmod +x /usr/local/bin/consul_exporter

COPY node_exporter/node_exporter /usr/local/bin/node_exporter

# configuration files and bootstrap scripts
COPY etc/containerpilot.json5 etc/
COPY etc/consul.json etc/consul/
COPY bin/* /usr/local/bin/

# Put Consul data on a separate volume to avoid filesystem performance issues
# with Docker image layers. Not necessary on Triton, but...
VOLUME ["/data"]

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables
# for purposes of linking.
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 53 53/udp

#ENV GOMAXPROCS 2
ENV SHELL /bin/bash

CMD ["/usr/local/bin/containerpilot"]

HEALTHCHECK --interval=60s --timeout=10s --retries=3 CMD curl -f http://127.0.0.1:8500/ || exit 1

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.license="MPL-2.0" \
      org.label-schema.vendor="https://bitbucket.org/double16" \
      org.label-schema.name="Consul ${CONSUL_VERSION} with the Autopilot Pattern and Prometheus Monitoring" \
      org.label-schema.url="https://bitbucket.org/double16/autopilotpattern-consul" \
      org.label-schema.docker.dockerfile="Dockerfile" \
      org.label-schema.vcs-ref=$SOURCE_REF \
      org.label-schema.vcs-type='git' \
      org.label-schema.vcs-url="https://bitbucket.org/double16/autopilotpattern-consul.git"
