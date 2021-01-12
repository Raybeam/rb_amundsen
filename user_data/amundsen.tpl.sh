#!/usr/bin/env bash
echo "NEO4J_ENDPOINT=neo4j://${neo4j_endpoint}" >> /etc/environment
echo "NEO4J_PASSWORD=${neo4j_password}" >> /etc/environment
echo "ES_ENDPOINT=https://${elk_endpoint}:443" >> /etc/environment
echo "KIBANA_ENDPOINT=https://${elk_kibana_endpoint}:443" >> /etc/environment
echo "FRONTEND_SVC_CONFIG_MODULE_CLASS=amundsen_application.config.ProdConfig" >> /etc/environment

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
Environment="METADATA_SVC_CONFIG_MODULE_CLASS=metadata_service.config.ProdConfig"
Environment="NEO4J_ENDPOINT=bolt://${neo4j_endpoint}"
Environment="NEO4J_PASSWORD=${neo4j_password}"
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
Environment="SEARCH_SVC_CONFIG_MODULE_CLASS=search_service.config.ProdConfig"
Environment="ES_ENDPOINT=https://${elk_endpoint}:443"
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

tee -a /etc/systemd/system/frontend.service << END
[Unit]
Description=Amundsen frontend project
After=network.target

# I want to create a deploy/www-data user to do all of this
# The service needs to run in the www-data group
[Service]
User=ubuntu
Group=www-data

WorkingDirectory=/home/ubuntu/amundsenfrontendlibrary
Environment="PATH=/home/ubuntu/amundsenfrontendlibrary/bin"
Environment="FRONTEND_SVC_CONFIG_MODULE_CLASS=amundsen_application.config.ProdConfig"
ExecStart=/home/ubuntu/amundsenfrontendlibrary/bin/gunicorn --workers 3 --bind unix:frontend.sock -m 007 amundsen_application.wsgi

[Install]
WantedBy=multi-user.target
END

tee -a /etc/nginx/sites-available/frontend << END
server {
	listen 0.0.0.0:5000;

	location / {
		include proxy_params;
		proxy_pass http://unix:/home/ubuntu/amundsenfrontendlibrary/frontend.sock;
	}
}
END

ln -s /etc/nginx/sites-available/metadata /etc/nginx/sites-enabled 
ln -s /etc/nginx/sites-available/search /etc/nginx/sites-enabled 
ln -s /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled 

sudo systemctl start metadata.service
sudo systemctl enable metadata.service
sudo systemctl start search.service
sudo systemctl enable search.service
sudo systemctl start frontend.service
sudo systemctl enable frontend.service

sudo service nginx restart