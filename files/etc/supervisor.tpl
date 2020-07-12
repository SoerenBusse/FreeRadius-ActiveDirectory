[unix_http_server]
file=/var/run/supervisor.sock

[supervisord]
nodaemon=true

[program:rsyslog]
startsecs = 0
autostart = true
autorestart = true
command = /usr/sbin/rsyslogd -n

[program:winbindd]
startsecs = 0
autostart=true
autorestart = true
command = /usr/sbin/winbindd {{ .WINBINDD_DEBUG }} --no-process-group -F -l /log/

[program:freeradius]
startsecs = 2
autostart=true
autorestart = true
command = /usr/sbin/freeradius -f {{ .FREERADIUS_DEBUG }} -d /etc/freeradius/radius -l /log/freeradius.log

[program:dcnotify]
startsecs = 0
autostart=true
autorestart = true
command = /usr/local/bin/dcnotify.sh -p {{ .POLL_INTERVALL }} -d {{ .TLS_DIRECTORY }} supervisorctl restart freeradius
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0

[eventlistener:process-watcher]
command=/usr/local/bin/stop-supervisor.sh
events=PROCESS_STATE_EXITED, PROCESS_STATE_FATAL

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
