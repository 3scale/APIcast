# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "centos/stream8"
  config.vm.box_url = "https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-Vagrant-8-latest.x86_64.vagrant-libvirt.box"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network "private_network", type: 'dhcp'

  config.vm.network "forwarded_port", guest: 8080, host: 8080, auto_correct: true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
  end

  config.vm.provider "libvirt" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
  end

  # Disable default sync folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # View the documentation for the provider you are using for more
  # information on available options.
  config.vm.synced_folder ".", "/opt/app-root", type: 'rsync',
    rsync__exclude: %w[lua_modules .git .vagrant node_modules t/servroot t/servroot* .cpanm],
    rsync__args: %w[--verbose --archive --delete -z --links ]

  config.vm.provision "shell", path: 'script/install/centos.sh'
  config.vm.provision "shell", path: 'script/install/openresty.sh'
  config.vm.provision "shell", path: 'script/install/luarocks.sh'
  config.vm.provision "shell", path: 'script/install/utilities.sh'

end
