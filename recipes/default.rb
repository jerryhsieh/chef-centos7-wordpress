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

package ["kernel-headers", "kernel-devel"] do
  action :install
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
  command 'yum -y update'
  action :run
end

execute 'mysql-community-server' do
  command 'yum -y --enablerepo=mysql80-community install mysql-community-server'
  action :run
end

service 'mysqld' do
  action [:enable, :start]
end

#
# Required by `database` cookbook MySQL resources:, doesn't work, manually do mysql_secure_installation
# mysql2_chef_gem 'default' do
#   action :install
# end

# connection_info = {
#   :host     => '127.0.0.1',
#   :username => 'root',
#   :password => 'Jerry001!'
# }

#
# first time temp password use grep 'temporary password' /var/log/mysqld.log
#
# mysql_database 'mysql_secure_installation' do
#   connection connection_info
#   database_name 'mysql'
#   sql <<-EOH
#       CREATE USER 'Jerry'@'localhost' IDENTIFIED BY 'password';
#       CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
#       GRANT ALL ON wordpress.* TO 'Jerry'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';    # current bug in mysql 8
#       FLUSH PRIVILEGES;
#       EXIT;   
#   EOH
#   action :query
# end

# install php-fpm
package ["php-fpm", "php-mysql", "php-cli", "php-gd"] do
  action :install
end

template "#{node['php-fpm']['dir']}/#{node['php-fpm']['config']}" do
  source "www.conf.erb"
  notifies :restart, "service[php-fpm]"
end

service 'php-fpm' do
  action [:enable, :start]
end

# create /var/www directory
directory '/var/www/wordpress' do
  owner 'nginx'
  group 'nginx'
  mode '0755'
  recursive true
  action :create
end

# file '/var/www/wordpress/index.php' do
#   content "<?php phpinfo(); ?>"
#   owner 'nginx'
#   group 'nginx'
#   mode '0755'  
# end

#
# manully update /etc/php-fpm.d/www.cnf
# for user, group set to nginx
# and link to unix:/var/run/php-fpm/www.sock  in stead of port
#

template "#{node['nginx']['dir']}/conf.d/#{node['wordpress']['config']}" do
  source "wordpress.conf.erb"
  notifies :restart, 'service[nginx]'
end

# generate wordpress /wordpress location
template "#{node['nginx']['dir']}/default.d/#{node['wordpress']['config']}" do
          source "wordpress.location.erb"
          notifies :restart, "service[nginx]"
end

# for other php location
template "#{node['nginx']['dir']}/default.d/#{node['php']['config']}" do
  source "php.location.erb"
  notifies :restart, "service[nginx]"
end


#
# install wordpress
#
bash "install wordpress" do
  user 'root'
  cwd '/tmp'
  code <<-EOH
       wget https://wordpress.org/latest.tar.gz
       tar zxf latest.tar.gz
       cp -avr wordpress/* /var/www/wordpress/
       mkdir /var/www/wordpress/wp-content/uploads
       chown -R nginx:nginx /var/www/wordpress/
       chmod -R 755 /var/www/wordpress/
  EOH
  not_if { ::File.exists?("/var/www/wordpress/wp-config.php") }
end

#
# wordpress selinux security issue
bash "change selinux" do
   user 'root'
   code <<-EOH
        chcon -t httpd_sys_content_t /var/www/wordpress -R
        chcon -t httpd_sys_rw_content_t /var/www/wordpress/wp-config.php
        chcon -t httpd_sys_rw_content_t /var/www/wordpress/wp-content -R
   EOH
end



# yum install development tools
package [ "bison", "byacc", "cscope", "ctags", "cvs", "diffstat", "doxygen", "flex", "gcc", "gcc-c++", "gcc-gfortran", "gettext" ] do
  action :install
end

package ["indent", "intltool", "libtool", "patch", "patchutils", "rcs", "redhat-rpm-config", "rpm-build", "subversion", "swig", "systemtap" ] do
  action :install
end

# require by emacs 
package ["ncurses-devel",  "gnutls-devel",  "libxml2-devel",  "automake",  "autoconf", "texinfo", "libacl-devel"] do
  action :install
end

# required by git
package ["curl-devel", "expat-devel",  "gettext-devel", "openssl-devel",  "zlib-devel", "perl-ExtUtils-MakeMaker"] do
  action :install
end

# build emacs 26 from source
bash "install emacs" do
  user 'root'
  cwd '/tmp'
  code <<-EOH
     wget http://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-emacs-26.1.tar.gz
     tar xzvf emacs-emacs-26.1.tar.gz
     cd emacs-emacs-26.1
     ./autogen.sh
     ./configure --with-gnutls --without-ns --without-x --without-dbus --without-gconf --without-libotf --without-m17n-flt --without-gpm --with-xml2
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
       wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.17.1.tar.gz
       tar xzvf git-2.17.1.tar.gz
       cd git-2.17.1
       make prefix=/usr/local/git all
       make prefix=/usr/local/git install
       echo 'export PATH=$PATH:/usr/local/git/bin' >> /etc/bashrc
       source /etc/bashrc
  EOH
  not_if { ::File.exists?("/usr/local/git/bin/git") }
end

# git clone emacs
git '/home/vagrant/.emacs.d' do
  user 'vagrant'
  repository 'https://github.com/jerryhsieh/.emacs.d.git'
  revision 'master'
  action :sync
end
