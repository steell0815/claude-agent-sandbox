# mitmproxy with our policy addon baked in.
# Same image is used for both the `proxy-init` (CA bootstrap) and `proxy`
# services; the bootstrap path is selected via compose entrypoint override.

FROM mitmproxy/mitmproxy:11.0.2

USER root
RUN mkdir -p /var/log/proxy /etc/proxy \
 && chown -R mitmproxy:mitmproxy /var/log/proxy /etc/proxy
USER mitmproxy

COPY --chown=mitmproxy:mitmproxy policy.py /etc/proxy/policy.py
COPY --chown=mitmproxy:mitmproxy bootstrap-ca.sh /usr/local/bin/bootstrap-ca.sh

ENTRYPOINT ["mitmdump", \
  "--listen-port", "8080", \
  "-s", "/etc/proxy/policy.py", \
  "--set", "confdir=/home/mitmproxy/.mitmproxy", \
  "--set", "stream_large_bodies=10m"]
