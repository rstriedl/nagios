#
# Author:: Tim Smith <tsmith@chef.io>
# Cookbook:: nagios
# Recipe:: nginx
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

node.normal['nagios']['server']['web_server'] = 'nginx'

if node['nagios']['server']['stop_apache']
  service 'apache2' do
    action :stop
  end
end

package node['nagios']['server']['nginx_dispatch']['packages']

node['nagios']['server']['nginx_dispatch']['services'].each do |svc|
  service svc do
    action [ :enable, :start ]
  end
end

if platform_family?('rhel', 'fedora', 'amazon')
  node.normal['nagios']['server']['nginx_dispatch']['type'] = 'both'
end

include_recipe 'chef_nginx'

dispatch_type = node['nagios']['server']['nginx_dispatch']['type']

%w(default 000-default).each do |disable_site|
  nginx_site disable_site do
    enable false
    notifies :reload, 'service[nginx]'
  end
end

file File.join(node['nginx']['dir'], 'conf.d', 'default.conf') do
  action :delete
  notifies :reload, 'service[nginx]', :immediate
end

template File.join(node['nginx']['dir'], 'sites-available', 'nagios3.conf') do
  source 'nginx.conf.erb'
  mode '0644'
  variables(
    public_domain: node['public_domain'] || node['domain'],
    listen_port: node['nagios']['http_port'],
    https: node['nagios']['enable_ssl'],
    ssl_cert_file: node['nagios']['ssl_cert_file'],
    ssl_cert_key: node['nagios']['ssl_cert_key'],
    docroot: node['nagios']['docroot'],
    log_dir: node['nagios']['log_dir'],
    fqdn: node['fqdn'],
    nagios_url: node['nagios']['url'],
    chef_env: node.chef_environment == '_default' ? 'default' : node.chef_environment,
    htpasswd_file: File.join(node['nagios']['conf_dir'], 'htpasswd.users'),
    cgi: %w(cgi both).include?(dispatch_type),
    php: %w(php both).include?(dispatch_type)
  )
  if File.symlink?(File.join(node['nginx']['dir'], 'sites-enabled', 'nagios3.conf'))
    notifies :reload, 'service[nginx]', :immediately
  end
end

nginx_site 'nagios3.conf' do
  notifies :reload, 'service[nginx]'
end

node.default['nagios']['web_user'] = node['nginx']['user']
node.default['nagios']['web_group'] = node['nginx']['group']

# configure the appropriate authentication method for the web server
case node['nagios']['server_auth_method']
when 'openid'
  Chef::Log.fatal('OpenID authentication for Nagios is not supported on NGINX')
  Chef::Log.fatal("Set node['nagios']['server_auth_method'] attribute in your Nagios role")
  raise 'OpenID authentication not supported on NGINX'
when 'cas'
  Chef::Log.fatal('CAS authentication for Nagios is not supported on NGINX')
  Chef::Log.fatal("Set node['nagios']['server_auth_method'] attribute in your Nagios role")
  raise 'CAS authentivation not supported on NGINX'
when 'ldap'
  Chef::Log.fatal('LDAP authentication for Nagios is not supported on NGINX')
  Chef::Log.fatal("Set node['nagios']['server_auth_method'] attribute in your Nagios role")
  raise 'LDAP authentication not supported on NGINX'
else
  # setup htpasswd auth
  Chef::Log.info('Default method htauth configured in server.rb')
end

include_recipe 'nagios::server'
