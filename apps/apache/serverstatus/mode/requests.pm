###############################################################################
# Copyright 2005-2013 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an timeelapsedutable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting timeelapsedutable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Author : Simon BOMM <sbomm@merethis.com>
#
# Based on De Bodt Lieven plugin
####################################################################################

package apps::apache::serverstatus::mode::requests;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use apps::apache::serverstatus::mode::libconnect;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
            {
            "hostname:s"        => { name => 'hostname' },
            "port:s"            => { name => 'port' },
            "proto:s"           => { name => 'proto', default => "http" },
            "credentials"       => { name => 'credentials' },
            "username:s"        => { name => 'username' },
            "password:s"        => { name => 'password' },
            "proxyurl:s"        => { name => 'proxyurl' },
            "warning:s"         => { name => 'warning' },
            "critical:s"        => { name => 'critical' },
            "warning-bytes:s"   => { name => 'warning_bytes' },
            "critical-bytes:s"  => { name => 'critical_bytes' },
            "timeout:s"         => { name => 'timeout', default => '3' },
            });
    return $self;
}

sub check_options {

    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warning-bytes', value => $self->{option_results}->{warning_bytes})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning-bytes threshold '" . $self->{option_results}->{warning_bytes} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-bytes', value => $self->{option_results}->{critical_bytes})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical-bytes threshold '" . $self->{option_results}->{critical_bytes} . "'.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{hostname})) {
        $self->{output}->add_option_msg(short_msg => "Please set the hostname option");
        $self->{output}->option_exit();
    }

    if (defined($self->{option_results}->{credentials} && (!defined($self->{option_results}->{username}) || !defined($self->{option_results}->{password})))) {
        $self->{output}->add_option_msg(short_msg => "You need to set --username= and --password= options when --credentials is used");
        $self->{output}->option_exit();
    }

}

sub run {

    my ($self, %options) = @_;
        
    my $webcontent = apps::apache::serverstatus::mode::libconnect::connect($self);
    
    my @webcontentarr = split("\n", $webcontent);
    my $i = 0;
    my ($rPerSec, $rPerSecSfx, $bPerSec, $bPerSecSfx, $bPerReq, $bPerReqSfx);

    while (($i < @webcontentarr) && ((!defined($rPerSec)) || (!defined($bPerSec)) || (!defined($bPerReq)))) {
        if ($webcontentarr[$i] =~ /([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/sec\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/second\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/request/) {
            ($rPerSec, $rPerSecSfx, $bPerSec, $bPerSecSfx, $bPerReq, $bPerReqSfx) = ($webcontentarr[$i] =~ /([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/sec\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/second\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/request/);
        }
        $i++;
    }
    
    if ($bPerReqSfx eq 'kB') {
        $bPerReq = $bPerReq * 1024;
    } elsif ($bPerReqSfx eq 'mB') {
        $bPerReq = $bPerReq * 1024 * 1024;
    } elsif ($bPerReqSfx eq 'gB') {
        $bPerReq = $bPerReq * 1024 * 1024 * 1024;
    }

    if ($bPerSecSfx eq 'kB') {
        $bPerSec = $bPerSec * 1024;
    } elsif ($bPerSecSfx eq 'mB') {
        $bPerSec = $bPerSec * 1024 * 1024;
    } elsif ($bPerSecSfx eq 'gB') {
        $bPerSec = $bPerSec * 1024 * 1024 * 1024;
    }

    my $exit1 = $self->{perfdata}->threshold_check(value => $rPerSec, threshold => [ { label => 'critical', 'exit_litteral' => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
    my $exit2 = $self->{perfdata}->threshold_check(value => $bPerReq, threshold => [ { label => 'critical-bytes', 'exit_litteral' => 'critical' }, { label => 'warning-bytes', exit_litteral => 'warning' } ]);

    my $exit = $self->{output}->get_most_critical(status => [ $exit1, $exit2 ]);

    $self->{output}->output_add(severity => $exit,
                                short_msg => sprintf("RequestPerSec: %f  BytesPerSecond: %d BytesPerRequest: %d", $rPerSec, $bPerSec, $bPerReq));
    $self->{output}->perfdata_add(label => "requestPerSec",
                                  value => $rPerSec,
                                  unit => $rPerSecSfx,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical')
                                  );
    $self->{output}->perfdata_add(label => "bytesPerSec",
                                  value => $bPerSec,
                                  unit => 'B');
    $self->{output}->perfdata_add(label => "bytesPerRequest",
                                  value => $bPerReq,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-bytes'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-bytes'),
                                  unit => 'B');

    $self->{output}->display();
    $self->{output}->exit();

}

1;

__END__

=head1 MODE

Check Apache WebServer Request statistics

=over 8

=item B<--hostname>

IP Addr/FQDN of the webserver host

=item B<--port>

Port used by Apache

=item B<--proxyurl>

Proxy URL if any

=item B<--proto>

Specify https if needed

=item B<--timeout>

Threshold for HTTP timeout

=item B<--warning>

Warning Threshold for Request per seconds

=item B<--critical>

Critical Threshold for Request per seconds

=item B<--warning-bytes>

Warning Threshold for Bytes Per Request

=item B<--critical-bytes>

Critical Threshold for Bytes Per Request

=back

=cut
