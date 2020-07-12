[global]
security = ADS
workgroup = {{ .DOMAIN }}
realm = {{ .REALM }}

log file = /var/log/samba/%m.log
log level = {{ .LOG_LEVEL }}

winbind use default domain = yes
