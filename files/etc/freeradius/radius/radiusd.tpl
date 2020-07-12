# Process name
name = freeradius

# FreeRADIUS paths
prefix = /usr
exec_prefix = /usr
sysconfdir = /etc
localstatedir = /var
sbindir = ${exec_prefix}/sbin
logdir = /var/log/freeradius
raddbdir = /etc/freeradius/small
radacctdir = ${logdir}/radacct
confdir = ${raddbdir}
run_dir = ${localstatedir}/run/${name}
libdir = /usr/lib/freeradius
pidfile = ${run_dir}/${name}.pid 

# Client secret for access points
client_accesspoints_secret = {{ .ACCESS_POINT_SECRET }}

# TLS certificate for EAP
eap_tls_private_key_file = {{ .TLS_DIRECTORY }}/{{ .RADIUS_TLS_KEY_FILE }}
eap_tls_certificate_file = {{ .TLS_DIRECTORY }}/{{ .RADIUS_TLS_CERTIFICATE_FILE }}

# MSCHAP domain
mschap_winbind_domain = {{ .DOMAIN }}

# LDAP credentials
ldap_server = {{ .LDAP_SERVER }}
ldap_port = {{ .LDAP_PORT }}
ldap_username = {{ .LDAP_USERNAME }}
ldap_secret = {{ .LDAP_SECRET }}
ldap_bind_dn = {{ .LDAP_BIND_DN }}

# Should likely be ${localstatedir}/lib/radiusd
db_dir = ${raddbdir}

# Make Unlang use 2 backslashes instead of 4
correct_escapes = true

# Maximum processing time per request
max_request_time = 30

# Time until connection cleanup
cleanup_delay = 5

# Maximum number of requests the server keeps track of
max_requests = 65536

# Dont resolve hostnames
hostname_lookups = no

# Logging configuration
log {
    # Log to file
    destination = files

    # Colors are awesome!
    colourise = yes

    # File name
    file = ${logdir}/radius.log

    # How should be logged?
    syslog_facility = daemon

    # Log full user name
    stripped_names = no

    # Log auth requests
    auth = yes

    # Don't log passwords
    auth_badpass = no
    auth_goodpass = no

    # Message for when Simultaneous-Use is exceeded
    msg_denied = "You are already logged in - access denied"
}

# Check if user is already logged in
checkrad = ${sbindir}/checkrad

# Security configuration
security {
    # User and group of the process
    user = freerad
    group = freerad

    # No core dumps
    allow_core_dumps = no

    # Max. number of attributes per request to prohibit memory flooding attacks
    max_attributes = 200

    # Time to wait before sending a reject
    reject_delay = 1

    # Allow status requests
    status_server = yes
}

# Don't forward requests to other servers
proxy_requests  = no

# Include client accesspoint configuration
$INCLUDE clients.conf

# Thread pool configuration
thread pool {
    # Start 5 servers
    start_servers = 5

    # Max. number of servers
    max_servers = 32

    # Number of spare servers when required
    min_spare_servers = 3
    max_spare_servers = 10

    # Servers should never exit
    max_requests_per_server = 0

    # No limit for accounting requests
    auto_limit_acct = no
}

# Modules configuration
modules {
    # Load modules
    $INCLUDE mods/
}

# Load sites
$INCLUDE sites/

# Include Policies
policy {
    $INCLUDE policy.d/
}
