ARG DD_IMAGE_TAG=7.21.1
ARG CUDA_IMAGE_TAG=10.0-runtime-ubuntu18.04

FROM datadog/agent:${DD_IMAGE_TAG} AS datadog
ARG WITH_JMX
ARG DD_PYTHON_VERSION

FROM debian:bullseye-slim AS extract

ARG WITH_JMX
ARG DD_PYTHON_VERSION

ENV S6_VERSION v1.22.1.0

ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-amd64.tar.gz /output/s6.tgz
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-amd64.tar.gz.sig /tmp/s6.tgz.sig
RUN apt-get update \
 && apt-get install --no-install-recommends -y gpg gpg-agent curl ca-certificates \
 && curl https://keybase.io/justcontainers/key.asc | gpg --import \
 && gpg --verify /tmp/s6.tgz.sig /output/s6.tgz

FROM nvidia/cuda:${CUDA_IMAGE_TAG} AS release

ARG WITH_JMX
ARG DD_PYTHON_VERSION

ENV DOCKER_DD_AGENT=true \
    DD_PYTHON_VERSION=$PYTHON_VERSION \
    PATH=/opt/datadog-agent/bin/agent/:/opt/datadog-agent/embedded/bin/:$PATH \
    CURL_CA_BUNDLE=/opt/datadog-agent/embedded/ssl/certs/cacert.pem \
    # Pass envvar variables to agents
    S6_KEEP_ENV=1 \
    # Direct all agent logs to stdout
    S6_LOGGING=0 \
    # Exit container if entrypoint fails
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    # Allow readonlyrootfs
    S6_READ_ONLY_ROOT=1

# make sure we have recent dependencies
RUN apt-get update \
  # CVE-fixing time!
  && apt full-upgrade -y \
  # https://security-tracker.debian.org/tracker/CVE-2016-2779
  && rm -f /usr/sbin/runuser \
  # https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2018-6954
  && rm -f /usr/lib/x86_64-linux-gnu/libdb-5.3.so

# Install openjdk-11-jre-headless on jmx flavor
# Due to this bug https://bugs.openjdk.java.net/browse/JDK-8217766, we need to be able to
# pull from testing since this is the only place for now where a version > 11.0.4 is available.
# we leave testing in the sources to avoid dependencies conflict in custom images
RUN if [ -n "$WITH_JMX" ]; then echo "Pulling openjdk-11 from testing" \
 && echo "deb http://deb.debian.org/debian testing main" > /etc/apt/sources.list.d/testing.list \
 && apt-get update \
 && mkdir /usr/share/man/man1 \
 && apt-get install --no-install-recommends -y openjdk-11-jre-headless \
 && apt-get clean; fi

# cleaning up
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# same with COPY --from=extract /output/ /
COPY --from=extract /output/s6.tgz /
COPY --from=datadog /checks.d /checks.d/
COPY --from=datadog /conf.d /conf.d/
COPY --from=datadog /etc/datadog-agent /etc/datadog-agent/
COPY --from=datadog /etc/init.d /etc/init.d/
COPY --from=datadog /etc/ssl /etc/ssl
COPY --from=datadog /opt/datadog-agent /opt/datadog-agent/
COPY --from=datadog /var/log /var/log/


# S6 entrypoint, service definitions, healthcheck probe
COPY --from=datadog /etc/services.d/ /etc/services.d/
COPY --from=datadog /etc/cont-init.d/ /etc/cont-init.d/
#COPY --from=datadog ./src/probe.sh ./src/initlog.sh ./src/secrets-helper/readsecret.py /
COPY --from=datadog /probe.sh /initlog.sh /readsecret.py /

RUN tar xzf s6.tgz \
 && rm s6.tgz \
# Prepare for running without root
# - Create a dd-agent:root user and give it permissions on relevant folders
# - Remove the /var/run -> /run symlink and create a legit /var/run folder
# as some docker versions re-create /run from zero at container start
 && adduser --system --no-create-home --disabled-password --ingroup root dd-agent \
 && rm /var/run && mkdir -p /var/run/s6 \
 && chown -R dd-agent:root /etc/datadog-agent/ /etc/s6/ /var/run/s6/ /var/log/datadog/ \
 && chmod g+r,g+w,g+X -R /etc/datadog-agent/ /etc/s6/ /var/run/s6/ /var/log/datadog/ \
 && chmod 755 /probe.sh /initlog.sh \
 && chown root:root /readsecret.py \
 && chmod 500 /readsecret.py

RUN if [ ! -z "$PYTHON_VERSION" ]; then \
 ln -sfn /opt/datadog-agent/embedded/bin/python${PYTHON_VERSION} /opt/datadog-agent/embedded/bin/python \
 && ln -sfn /opt/datadog-agent/embedded/bin/python${PYTHON_VERSION}-config /opt/datadog-agent/embedded/bin/python-config \
 && ln -sfn /opt/datadog-agent/embedded/bin/pip${PYTHON_VERSION} /opt/datadog-agent/embedded/bin/pip ; \
 fi

COPY --from=datadog /etc/s6/init/init-stage3-original /etc/s6/init/init-stage3-original
COPY --from=datadog /etc/s6/init/init-stage3 /etc/s6/init/init-stage3
COPY --from=datadog /etc/s6/init/init-stage3-host-pid /etc/s6/init/init-stage3-host-pid

# for nvml
RUN /opt/datadog-agent/embedded/bin/pip install nvidia-ml-py3==7.352.0
COPY ./nvml.py /etc/datadog-agent/checks.d/nvml.py
COPY ./nvml.yaml.default /etc/datadog-agent/conf.d/nvml.yaml.default

EXPOSE 8125/udp 8126/tcp

HEALTHCHECK --interval=30s --timeout=5s --retries=2 \
  CMD ["/probe.sh"]

# Leave following directories RW to allow use of kubernetes readonlyrootfs flag
VOLUME ["/var/run/s6", "/etc/datadog-agent", "/var/log/datadog", "/tmp"]

CMD ["/init"]
