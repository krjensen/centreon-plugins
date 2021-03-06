#
# Copyright 2017 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
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

package notification::foxbox::mode::alert;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::http;

# use Data::Dumper;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, no_performance => 1);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(
        arguments => {
            "username:s"    => { name => 'username', default => 'centreon' },
            "password:s"    => { name => 'password' },
            "from:s"        => { name => 'from',     default => 'centreon' },
            "proto:s"       => { name => 'proto',    default => 'http' },
            "sendpage:s"    => { name => 'sendpage', default => '/source/send_sms.php' },
            "phonenumber:s" => { name => 'phonenumber' },
            "hostname:s"    => { name => 'hostname' },
            "texto:s"       => { name => 'texto' },
            "timeout:s"     => { name => 'timeout',  default => 10 },
        }
    );

    $self->{http} = centreon::plugins::http->new(output => $self->{output});

    return $self;
}

sub check_options {
    my ($self, %options) = @_;

    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{password})) {
        $self->{output}
            ->add_option_msg(short_msg => "You need to set --username= and --password= option");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{hostname})) {
        $self->{output}->add_option_msg(short_msg => "Please set the --hostname option");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{phonenumber})) {
        $self->{output}->add_option_msg(short_msg => "Please set the --phonenumber option");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{texto})) {
        $self->{output}->add_option_msg(short_msg => "Please set the --texto option");
        $self->{output}->option_exit();
    }

    $self->{http}->set_options(%{ $self->{option_results} });
}

sub run {
    my ($self, %options) = @_;

    my ($ua, $html_page, $response, $status_code, $litteral_code);

    my $url
        = $self->{option_results}->{proto} . '://'
        . $self->{option_results}->{hostname}
        . $self->{option_results}->{sendpage};

    $ua = LWP::UserAgent->new;
    $ua->timeout($self->{option_results}->{timeout});

    $response = $ua->post(
        $url,
        [   "username" => $self->{option_results}->{username},
            "pwd"      => $self->{option_results}->{password},
            "from"     => $self->{option_results}->{from},
            "nphone"   => $self->{option_results}->{phonenumber},
            "testo"    => $self->{option_results}->{texto},
            "nc"       => $url,
        ]
    );

    if ($response->{_rc} != 200) {
        $status_code   = $self->{output}->{errors}->{UNKNOWN};
        $litteral_code = $self->{output}->{errors_num}->{$status_code};
        $self->{output}->output_add(
            severity  => $litteral_code,
            short_msg => 'ERROR: ' . $response->{_msg}
        );
    }
    else {
        $html_page = $response->{_content};
        if ($html_page =~ /p class="(\w+)"/g) {
            if ($1 eq "confneg") {
                $status_code   = $self->{output}->{errors}->{UNKNOWN};
                $litteral_code = $self->{output}->{errors_num}->{$status_code};
                $self->{output}->output_add(
                    severity  => $litteral_code,
                    short_msg => 'ERROR: Unable to send SMS'
                );
            }
            else {
                $status_code   = $self->{output}->{errors}->{OK};
                $litteral_code = $self->{output}->{errors_num}->{$status_code};
            }
        }
        else {
            $status_code   = $self->{output}->{errors}->{UNKNOWN};
            $litteral_code = $self->{output}->{errors_num}->{$status_code};
            $self->{output}->output_add(
                severity  => $litteral_code,
                short_msg => 'ERROR: Unknown page output'
            );
        }
    }
    $self->{output}->display();
    $self->{output}->exit(exit_litteral => $litteral_code);
}

1;

__END__

=head1 MODE

Send SMS with Foxbox API.

=over 8

=item B<--hostname>

url of the Foxbox Server.

=item B<--sendpage>

The path describes a specific resource. (Default: /source/send_sms.php)

=item B<--username>

Specify username for API authentification (Default: centreon).

=item B<--password>

Specify password for API authentification (Required).

=item B<--proto>

Specify http or https protocol. (Default: http)

=item B<--phonenumber>

Specify phone number (Required).

=item B<--texto>

Specify the content of your SMS message (Required).

=item B<--from>

Specify the sender. It should NOT start with a number and have a max of 11 characters (Default: centreon).

=item B<--timeout>

Timeout in seconds for the command (Default: 10).

=back

=cut
