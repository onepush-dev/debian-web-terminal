# Debian 12 (bookworm) web terminal: ttyd (browser) + OpenSSH + tmux, one persistent session.
ARG DEBIAN_IMAGE=debian:bookworm-20261027@sha256:d74df7598108a173a621eda4d58a2adbf850b2d9a9d81bc2cca1a6c21174a880
FROM ${DEBIAN_IMAGE}

ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-server tmux sudo tini ca-certificates curl wget git nano vim-tiny less htop \
      procps iproute2 iputils-ping dnsutils unzip zip jq rsync bash-completion locales tzdata man-db \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
 && echo "${TTYD_SHA256}  /usr/local/bin/ttyd" | sha256sum -c - \
 && chmod 755 /usr/local/bin/ttyd \
 && mkdir -p /run/sshd \
 && rm -f /etc/ssh/ssh_host_* \
 && useradd -m -s /bin/bash -G sudo -u 1000 debian \
 && cp -a /home /opt/home-skel

COPY railway/sshd_config /etc/ssh/sshd_config.d/10-railway.conf
COPY railway/tmux.conf /etc/tmux.conf
COPY --chmod=755 railway/auto-tmux.sh /etc/profile.d/zz-auto-tmux.sh
COPY --chmod=755 railway/entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 7681 2222
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
