pacman -Sy
pacman -S ruby git --noconfirm
sudo -u vagrant gem install google-api-client
export PATH=$PATH:/home/vagrant/.gem/ruby/2.1.0/bin
sudo -u vagrant echo export PATH=$PATH:/home/vagrant/.gem/ruby/2.1.0/bin >> /home/vagrant/.bashrc
