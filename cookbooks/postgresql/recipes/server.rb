#/postgresql.conf.
# Cookbook Name:: postgresql
# Recipe:: server
#
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright 2009-2011, Opscode, Inc.
# Portions Copyright (c) 2012 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# randomly generate postgres password
node.set_unless[:postgresql][:password][:postgres] = secure_password
node.save unless Chef::Config[:solo]

case node[:postgresql][:version]
when "8.3"
  node.default[:postgresql][:ssl] = "off"
when "8.4"
  node.default[:postgresql][:ssl] = "true"
end

# Include the right "family" recipe for installing the server
# since they do things slightly differently.
case node.platform
when "redhat", "centos", "fedora", "suse", "scientific", "amazon"
  include_recipe "postgresql::server_redhat"
when "debian", "ubuntu"
  include_recipe "postgresql::server_debian"
end

template "#{node[:postgresql][:dir]}/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  notifies :restart, resources(:service => "postgresql"), :immediately
end

template "#{node[:postgresql][:dir]}/pg_hba.conf" do
  source "pg_hba.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  notifies :reload, resources(:service => "postgresql"), :immediately
end

execute "assign-postgres-password" do
  user "postgres"
  cwd "/var/lib/pgsql"
  command %Q{
    echo "ALTER ROLE postgres ENCRYPTED PASSWORD '#{node[:postgresql][:password][:postgres]}';" | psql
  }
  action :run
end