[Unit]
Description=Tidal Connect Docker Service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
WorkingDirectory=${PWD}/Docker/
Type=oneshot
RemainAfterExit=yes

#ExecStartPre=docker-compose pull --quiet
ExecStart=docker-compose up -d

ExecStop=docker-compose down

#ExecReload=docker-compose pull --quiet
ExecReload=docker-compose up -d

[Install]
WantedBy=multi-user.target
