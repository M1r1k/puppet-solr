# == Class: solr::config
# This class sets up solr install
#
# === Parameters
# - The $cores to create
#
# === Actions
# - Copies a new jetty default file
# - Creates solr home directory
# - Downloads solr 4.4.0, extracts war and copies logging jars
# - Creates solr data directory
# - Creates solr config file with cores specified
# - Links solr home directory to jetty webapps directory
#
class solr::config(
  $cores = 'UNSET',
) {
  include solr::params

  $jetty_home     = $::solr::params::jetty_home
  $solr_home      = $::solr::params::solr_home
  $solr_version   = $::solr::params::solr_version
  $file_name      = "solr-${solr_version}.war"
  $download_site  = 'http://repo1.maven.org/maven2/org/apache/solr/solr'

  #Copy the jetty config file
  file { '/etc/default/jetty':
    ensure  => file,
    source  => 'puppet:///modules/solr/jetty-default',
    require => Package['jetty'],
  }

  file { $solr_home:
    ensure    => directory,
    owner     => 'jetty',
    group     => 'jetty',
    require   => Package['jetty'],
  }

  # download only if solr.web is not present and .war file is not in /tmp:
  exec { 'solr-download':
    command   =>  "wget ${download_site}/${solr_version}/${file_name}",
    cwd       =>  '/tmp',
    creates   =>  "/tmp/${file_name}",
    onlyif    =>  "test ! -d ${solr_home}/${file_name} && test ! -f /tmp/${file_name}",
    timeout   =>  0,
    require   => File[$solr_home],
  }

  # have to copy logging jars separately from solr 4.3 onwards
  exec { 'copy-solr':
    path      =>  ['/usr/bin', '/usr/sbin', '/bin'],
    command   =>  "cp /tmp/${file_name} $solr_home",
    cwd       =>  $solr_home,
    onlyif    =>  "test ! -d ${solr_home}/${file_name}",
    require   =>  Exec['solr-download'],
  }

  file { '/var/lib/solr':
    ensure    => directory,
    owner     => 'jetty',
    group     => 'jetty',
    mode      => '0700',
    require   => Package['jetty'],
  }

  file { "${solr_home}/solr.xml":
    ensure    => 'file',
    owner     => 'jetty',
    group     => 'jetty',
    content   => template('solr/solr.xml.erb'),
    require   => File['/etc/default/jetty'],
  }

  file { "${jetty_home}/webapps/solr":
    ensure    => 'link',
    target    => $solr_home,
    require   => File["${solr_home}/solr.xml"],
  }

  solr::core { $cores:
    require   =>  File["${jetty_home}/webapps/solr"],
  }
}

