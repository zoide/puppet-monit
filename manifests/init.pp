# $Id: init.pp 4806 2011-11-21 19:04:07Z uwaechte $
# Writtenby: udo.waechter@uni-osnabrueck.de
#
# _Class:_ monit
#
# Enables the monit daemon.
# *Note:* At least one monit::process must be defined in order
# for the daemon to work.
# Another note:
# The +template("monit/monitrc.erb")+ uses two variables:
# +$LOCAL_SMTP+ and +$ROOT_MAIL+
# that should be defined somewhere.
#
# This module was tested with Debian (Etch) and Ubuntu (Hardy).
#
# _Parameters:_
#
# _Actions:_
#   Installs the monit package and configures it.
#
# _Requires:_
#
# _Sample Usage:_
#   +include monit+
#
class monit ($ensure = 'present', $runinterval = 60) {
  $monitetc = $kernel ? {
    "Linux"  => "/etc/monit",
    "Darwin" => "/opt/local/etc/monit"
  }
  $monitddir = "${monitetc}/monitrc.d"
  $monitservice = $kernel ? {
    "Linux"  => "monit",
    "Darwin" => "com.mmonit.monit"
  }

  Monit::Process {
    require => File["${monitddir}"] }

  package { "monit":
    ensure => $ensure ? {
      'present' => 'latest',
      default   => $ensure,
    }
  }

  # some variables
  File {
    require => Package["monit"],
    owner   => 'root',
  }

  file { ["${monitetc}", "${monitddir}"]:
    ensure => $ensure ? {
      "present" => "directory",
      default   => "absent",
    },
    mode   => 0700,
  }

  file { "${monitetc}/monitrc":
    content => template("monit/monitrc.erb"),
    mode    => 0600,
    notify  => Service["${monitservice}"],
    ensure  => $ensure,
  }

  service { "${monitservice}":
    ensure    => $ensure ? {
      "present" => true,
      default   => false,
    },
    hasstatus => false,
    subscribe => File["${monitetc}/monitrc"],
  }

  case $kernel {
    "Linux" : {
      $startup = $ensure ? {
        "present" => 'yes',
        default   => 'no'
      }

      file { "/etc/default/monit":
        content => template("monit/etc_default_monit.erb"),
        mode    => 0600,
        notify  => Service["${monitservice}"],
      }
    }
  }

  # _Define:_ monit::process
  # Manage a process (a.k.a daemon) with monit.
  #
  # _Parameters:_
  #   $namevar
  #   - The process's name
  #   $process_name
  #   - defaults to namevar
  #   $pidfile
  #   - The absolute path to the pidfile of the daemon, defaults to "/var/run/namevar.pid"
  #   $start
  #   - Action needed to start the daemon. Defaults to "/etc/init.d/namevar start"
  #   $stop
  #   - Action needed to stop the daemon. Defaults to "/etc/init.d/namevar stop"
  #   $additional
  #   - Additional entries for this process, see http://mmonit.com/monit/documentation/monit.html
  #   $ensure
  #   - {"present","absent"} whether or not this process should be monitored
  #
  # _Sample Usage:_
  # 1. +monit::process{"cron": }+
  #       - creates /etc/monit/conf.d/cron.conf
  #       +check process cron
  # 	     with pidfile "/var/run/crond.pid"
  # 	     start program = "/etc/init.d/cron start"
  # 	     stop program  = "/etc/init.d/cron stop"
  # 	     if 2 restarts within 5 cycles then timeout+
  #
  # 1. +monit::process{"syslogd":
  #   start => "/etc/init.d/sysklogd start",
  #         stop => "/etc/init.d/sysklogd stop",
  #    }+
  # - creates /etc/monit/conf.d/syslogd.conf
  #       +check process syslogd
  # 	      with pidfile "/var/run/syslogd.pid"
  # 	      start program = "/etc/init.d/sysklogd start"
  # 	      stop program  = "/etc/init.d/sysklogd stop"
  # 	      if 2 restarts within 5 cycles then timeout+
  #
  define process ($process_name = '', $pidfile = '', $start = '', $stop = '', $additional = '', $ensure = 'present') {
    if defined(Class['monit']) {
      case $kernel {
        'Linux' : {
          $process_name_real = $process_name ? {
            ""      => $name,
            default => $process_name,
          }
          $process_pidfile_real = $pidfile ? {
            ""      => "/var/run/${process_name_real}.pid",
            default => $pidfile,
          }
          $start_real = $start ? {
            ""      => "/etc/init.d/${process_name_real} start",
            default => $start,
          }
          $stop_real = $stop ? {
            ""      => "/etc/init.d/${process_name_real} stop",
            default => $stop,
          }

          file { "${monit::monitddir}/${process_name_real}.conf":
            ensure  => $ensure,
            content => template('monit/process.erb'),
            owner   => root,
            mode    => 0600,
            notify  => Service['monit'],
          }
        }
      }

    }
  }
}
