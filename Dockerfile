# Use Ubuntu Disco as base. Debian doesn't contain Samba 4.10.
FROM ubuntu:focal-20200703

# Gucci version
ARG GUCCI_VERSION=1.2.2

# Install Samba and FreeRADIUS
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install samba=2:4.11.6+dfsg-0ubuntu1.3 winbind=2:4.11.6+dfsg-0ubuntu1.3 netcat=1.206-1ubuntu1 smbclient=2:4.11.6+dfsg-0ubuntu1.3 \
       freeradius=3.0.20+dfsg-3build1 freeradius-ldap=3.0.20+dfsg-3build1 \
       supervisor=4.1.0-1ubuntu1 rsyslog=8.2001.0-1ubuntu1 \
       wget=1.20.3-1ubuntu1 \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/samba/smb.conf

# Install Gucci templating engine
RUN wget -q https://github.com/noqcks/gucci/releases/download/${GUCCI_VERSION}/gucci-v${GUCCI_VERSION}-linux-amd64 && \
    chmod +x gucci-v${GUCCI_VERSION}-linux-amd64 && \
    mv gucci-v${GUCCI_VERSION}-linux-amd64 /usr/local/bin/gucci

# Change permissions of winbindd socket
RUN usermod -a -G winbindd_priv freerad
RUN chown root:winbindd_priv /var/lib/samba/winbindd_privileged/

# Copy config files
COPY files /

# Copy scripts and make them executable
COPY scripts/init.sh scripts/dcnotify.sh scripts/stop-supervisor.sh scripts/environment-validator.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init.sh /usr/local/bin/dcnotify.sh /usr/local/bin/stop-supervisor.sh /usr/local/bin/environment-validator.sh

# Expose FreeRADIUS port
EXPOSE 1812/udp

# Entrypoint
ENTRYPOINT ["/usr/local/bin/init.sh"]
