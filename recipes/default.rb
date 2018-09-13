
platform = node['platform']

include_recipe 'tar::default'

$pmaver = node['phpmyadmin']['version']
$aphome = node['apache']['home']
$adminuser = node['mysql']['user']
$adminpass = node['mysql']['password']
$dbhost = node['mysql']['host']

if platform == 'centos' || platform == 'fodora'
  package 'firewalld' do
    action :remove
  end
end

tar_extract "https://files.phpmyadmin.net/phpMyAdmin/#{$pmaver}/phpMyAdmin-#{$pmaver}-english.tar.gz" do
  target_dir "#{$aphome}/htdocs"
  creates "#{$aphome}/htdocs/phpMyAdmin-#{$pmaver}-english/config.sample.inc.php"
end

link "#{$aphome}/htdocs/phpMyAdmin" do
  to "#{$aphome}/htdocs/phpMyAdmin-#{$pmaver}-english"
  link_type :symbolic
end

template "#{$aphome}/htdocs/phpMyAdmin/config.inc.php" do
  source 'config.inc.php.erb'
  mode '0644'
  variables ({
    :hostname   => node['hostname'],
    :ipaddress  => node['ipaddress'],
    :pmauser    => node['phpmyadmin']['user'],
    :pmapass    => node['phpmyadmin']['password'],
    :pmaschema  => node['mysql']['schema'],
    :adminuser  => node['mysql']['user'],
    :adminpass  => node['mysql']['password'],
    :portnum    => node['mysql']['port'],
    :dbhost     => node['mysql']['host'],
  })
end

template '/tmp/pma.sql' do
  source 'pma.sql.erb'
  mode '0644'
  variables ({
    :pmauser    => node['phpmyadmin']['user'],
    :pmapass    => node['phpmyadmin']['password'],
    :pmaschema  => node['mysql']['schema'],
    :fqdn       => node['fqdn'],
    :dbhost     => node['mysql']['host'],
  })
end

cookbook_file '/tmp/create_tables.sql' do
  source 'create_tables.sql'
end

if node.chef_environment != 'remotedb'
  if platform == 'centos' || platform == 'fedora'
    service 'mariadb' do
      action :restart
    end
  elsif platform == 'ubuntu'
    service 'mysql' do
      action :restart
    end
  end
end

bash 'Configure phpmyadmin tables' do
  code <<-EOH
  mysql -u #{$adminuser} -p#{$adminpass} -h #{$dbhost} < /tmp/create_tables.sql
  touch /tmp/phpmyadmin-tables
  EOH
  action :run
  not_if { File.exist?('/tmp/phpmyadmin-tables') }
end

bash 'Create phpMyAdmin User' do
  code <<-EOH
  mysql -u #{$adminuser} -p#{$adminpass} -h #{$dbhost} < /tmp/pma.sql
  touch /tmp/pma-user
  EOH
  action :run
  not_if { File.exist?('/tmp/pma-user') }
end
