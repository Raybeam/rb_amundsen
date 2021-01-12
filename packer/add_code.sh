cd ~
git clone --branch 2.4.1 --depth 1 https://github.com/amundsen-io/amundsensearchlibrary.git
git clone --branch 3.0.0 --depth 1 https://github.com/amundsen-io/amundsenmetadatalibrary.git
git clone --branch 3.1.0 --depth 1 https://github.com/amundsen-io/amundsenfrontendlibrary.git
git clone --branch 4.0.4 --depth 1 https://github.com/amundsen-io/amundsendatabuilder.git

echo '* * * * * Adding search library'
cd ~/amundsensearchlibrary
python3 -m venv .
source bin/activate
sed '/^mypy==/d' requirements.txt > new_requirements.txt
mv new_requirements.txt requirements.txt
pip install -r requirements.txt
pip install gunicorn
pip install --upgrade werkzeug
deactivate

echo '* * * * * Adding metadata library'
cd ~/amundsenmetadatalibrary
python3 -m venv .
source bin/activate
sed '/^mypy==/d' requirements.txt > new_requirements.txt
mv new_requirements.txt requirements.txt
pip install -r requirements.txt
pip install gunicorn
deactivate

echo '* * * * * Adding frontend library'
cd ~/amundsenfrontendlibrary
python3 -m venv .
source bin/activate
sed '/^mypy==/d' requirements.txt > new_requirements.txt
mv new_requirements.txt requirements.txt
pip install -r requirements.txt
pip install gunicorn
deactivate

echo '* * * * * Adding data builder'
cd ~/amundsendatabuilder
python3 -m venv .
source bin/activate
sed '/^mypy==/d' requirements.txt > new_requirements.txt
mv new_requirements.txt requirements.txt
pip install -r requirements.txt
pip install snowflake-sqlalchemy
python setup.py install
deactivate
