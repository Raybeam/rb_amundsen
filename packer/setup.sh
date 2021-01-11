sleep 10 

apt-get dist-upgrade -y
apt-get update -y

sleep 10 
apt-get -y install curl wget git vim apt-transport-https ca-certificates python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools python3-venv npm nginx

usermod -a -G www-data ubuntu 

