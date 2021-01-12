echo '* * * * * Installing search library'
cd ~/amundsensearchlibrary
source bin/activate
python setup.py install
deactivate

echo '* * * * * Installing metadata library'
cd ~/amundsenmetadatalibrary
source bin/activate
python setup.py install
deactivate

echo '* * * * * Installing frontend library'
cd ~/amundsenfrontendlibrary
source bin/activate
python setup.py install
deactivate
