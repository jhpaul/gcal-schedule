# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!

VAGRANTFILE_API_VERSION = '2'

box = 'arch64-base'
ram = '1024'
hostname = 'gcal-vagrant'
url = 'http://downloads.sourceforge.net/project/softcover-vagrant/arch64-base.box'
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|


  config.vm.network "forwarded_port", guest: 4567, host: 4567, auto_correct: true
  config.vm.box = box
  config.vm.hostname = hostname
  config.vm.box_url = url

  config.vm.provider "virtualbox" do |v|
    v.customize [
      'modifyvm', :id,
      # '--name', hostname ,
      '--memory', ram
    ]
  end


  config.vm.provision "shell", path: "provision.sh"


end
