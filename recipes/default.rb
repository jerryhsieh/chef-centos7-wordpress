# coding: utf-8
#
# Cookbook Name:: wordpress
# Recipe:: default
#
# Copyright (C) 2018 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#
group node['wordpress']['group']

user node['wordpress']['user'] do
  group node['wordpress']['group']
  system true
  shell '/bin/bash'
  home "/home/#{ node['wordpress']['user'] }"
  manage_home true
  password "$1$AEX3vuXK$o9ZWPtzyTLu7yMfABquYc0"
end

yum_package 'wget' do
  action :install
end

package 'epel-release' do
 action :install
end

yum_package 'nginx' do
  action :install
end

service 'nginx' do
  action [ :enable, :start]
end

execute 'mysql-community-repo' do
 command 'yum -y localinstall http://repo.mysql.com/mysql80-community-release-el7-1.noarch.rpm'
 action :run
end

execute 'mysql-community-server' do
  command 'yum -y --enablerepo=mysql80-community install mysql-community-server'
  action :run
end

# sudo grep 'temporary password' /var/log/mysqld.log
#  myql -u root -p
#  ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass4!';

# bash 'secure install' do
#   user 'root'
#   cwd '/tmp'
#   code <<-EOH
#      mysql_secure_installation
#      send '/r'
#      send 'Y/r'
#      send '#{node['mysql']['tmppwd']}/r'
#      send '#{node['mysql']['tmppwd']}/r'
#      send 'Y/r'    
#      send 'Y/r'
#      send 'Y/r'
#      send 'Y/r'
#   EOH
# end


service 'mysqld' do
  action [:enable, :start]
end

# install php-fpm
package ["php-fpm", "php-mysql", "php-cli"] do
  action :install
end

service 'php-fpm' do
  action [:enable, :start]
end

# generate wordpress virtual machine
template "#{node['nginx']['dir']}/conf.d/#{node['wordpress']['config']}" do
          source "wordpress.conf.erb"
          notifies :restart, "service[nginx]"
end


# yum install development tools
package [ "bison", "byacc", "cscope", "ctags", "cvs", "diffstat", "doxygen", "flex", "gcc", "gcc-c++", "gcc-gfortran", "gettext" ] do
  action :install
end

package ["indent", "intltool", "libtool", "patch", "patchutils", "rcs", "redhat-rpm-config", "rpm-build", "subversion", "swig", "systemtap" ] do
  action :install
end

# require by emacs 25
package ["ncurses-devel",  "gnutls-devel",  "libxml2-devel",  "automake",  "autoconf", "texinfo"] do
  action :install
end

# required by git
package ["curl-devel", "expat-devel",  "gettext-devel", "openssl-devel",  "zlib-devel", "perl-ExtUtils-MakeMaker"] do
  action :install
end

# build emacs 25 from source
bash "install emacs" do
  user 'root'
  cwd '/tmp'
  code <<-EOH
     wget http://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-emacs-25.3.tar.gz
     tar xzvf emacs-emacs-25.3.tar.gz
     cd emacs-emacs-25.3
     ./autogen.sh
     ./configure -–with-x-toolkit=no -–with-xpm=no -–with-jpeg=no -–with-png=no -–with-gif=no -–with-tiff=no
     make -j4 -sw &> /dev/null
     make install
     EOH
  not_if { ::File.exists?("/usr/local/bin/emacs") }
end

# build git from source
bash "install git" do
  user 'root'
  cwd '/tmp'
  code <<-EOH
       wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.17.0.tar.gz
       tar xzvf git-2.17.0.tar.gz
       cd git-2.17.0
       make prefix=/usr/local/git all
       make prefix=/usr/local/git install
       echo 'export PATH=$PATH:/usr/local/git/bin' >> /etc/bashrc
       source /etc/bashrc
  EOH
  not_if { ::File.exists?("/usr/local/git/bin/git") }
end
