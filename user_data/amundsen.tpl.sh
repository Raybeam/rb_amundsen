#!/usr/bin/env bash
echo "NEO4J_ENDPOINT=${neo4j_endpoint}" >> /etc/environment
echo "NEO4J_PASSWORD=${neo4j_password}" >> /etc/environment
echo "ES_ENDPOINT=https://${elk_endpoint}:443" >> /etc/environment
echo "KIBANA_ENDPOINT=https://${elk_kibana_endpoint}:443" >> /etc/environment

tee -a /etc/systemd/system/metadata.service << END
[Unit]
Description=Amundsen metadata project
After=network.target

# I want to create a deploy/www-data user to do all of this
# The service needs to run in the www-data group
[Service]
User=ubuntu
Group=www-data

WorkingDirectory=/home/ubuntu/amundsenmetadatalibrary
Environment="PATH=/home/ubuntu/amundsenmetadatalibrary/bin"
Environment="CREDENTIALS_PROXY_PASSWORD=${neo4j_password}"
Environment="PROXY_HOST=neo4j://${neo4j_endpoint}"
ExecStart=/home/ubuntu/amundsenmetadatalibrary/bin/gunicorn --workers 3 --bind unix:metadata.sock -m 007 metadata_service.metadata_wsgi

[Install]
WantedBy=multi-user.target  
END

tee -a /etc/nginx/sites-available/metadata << END
server {
	listen 0.0.0.0:5002;

	location / {
		include proxy_params;
		proxy_pass http://unix:/home/ubuntu/amundsenmetadatalibrary/metadata.sock;
	}
}
END

tee -a /etc/systemd/system/search.service << END
[Unit]
Description=Amundsen search project
After=network.target

# I want to create a deploy/www-data user to do all of this
# The service needs to run in the www-data group
[Service]
User=ubuntu
Group=www-data

WorkingDirectory=/home/ubuntu/amundsensearchlibrary
Environment="PATH=/home/ubuntu/amundsensearchlibrary/bin"
Environment="ES_ENDPOINT=https://${elk_endpoint}:443"
Environment="SEARCH_SVC_CONFIG_MODULE_CLASS=search_service.config.ProdConfig"
ExecStart=/home/ubuntu/amundsensearchlibrary/bin/gunicorn --workers 3 --bind unix:search.sock -m 007 search_service.search_wsgi

[Install]
WantedBy=multi-user.target
END

tee -a /etc/nginx/sites-available/search << END
server {
	listen 0.0.0.0:5001;

	location / {
		include proxy_params;
		proxy_pass http://unix:/home/ubuntu/amundsensearchlibrary/search.sock;
	}
}
END

ln -s /etc/nginx/sites-available/metadata /etc/nginx/sites-enabled 
ln -s /etc/nginx/sites-available/search /etc/nginx/sites-enabled 