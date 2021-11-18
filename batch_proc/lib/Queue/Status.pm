

package Queue::Status;

use strict;
use warnings;

use constant STATE_RUN => "R";
use constant STATE_PENDING => "PD";


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    # Linux grep pattern style
    $self->{job_pat} = $args{job_prefix};
    $self->{queue} = $args{queue};

    return $self;
}


sub load {
    my $self = shift;

    my ($jobs, $jobNames) = $self->loadByPattern($self->{job_pat});
    $self->{jobs} = $jobs;
    $self->{job_names} = $jobNames;
}


sub loadByPattern {
    my $self = shift;
    my $pattern = shift;

    my $cmd = "/usr/bin/squeue -h -o '%A,%j,%t,%N,%M,%P' | grep $self->{queue} | grep '$pattern'";
    my $output = `$cmd`;

    my @lines = split(m/[\r\n]+/s, $output);

    my %jobNames;
    my %jobs;
    foreach my $line (@lines) {
        my ($jid, $name, $state, $nodeName, $runtime) = split(m/,/, $line);
        $name =~ s/^$pattern\-?(.*?)$/$1/;
        $runtime = parseRuntime($runtime);
        $jobs{$jid} = {name => $name, state => $state, node => $nodeName, runtime => $runtime};
        $jobNames{$name} = $jid;
    }

    return (\%jobs, \%jobNames);
}


sub getRunningJobs {
    my $self = shift;
    return $self->getJobsFilter(STATE_RUN);
}
sub getPendingJobs {
    my $self = shift;
    return $self->getJobsFilter(STATE_PENDING);
}
sub getJobsFilter {
    my $self = shift;
    my $state = shift;
    my %jobs;
    foreach my $jobName (keys %{ $self->{job_names} }) {
        my $jid = $self->{job_names}->{$jobName};
        if ($self->{jobs}->{$jid}->{state} eq $state) {
            $jobs{$jid} = $self->{jobs}->{$jid};
        }
    }
    return \%jobs;
}


sub parseRuntime {
    my $runtime = shift;
    my $days = 0;
    if ($runtime =~ m/^(\d+)-\d/) {
        $days = $1;
    }
    $runtime =~ s/^(\d+)-(.*)$/$2/;
    my @p = split(m/:/, $runtime);
    my $hh = $#p == 2 ? shift @p : 0;
    my ($mm, $ss) = @p;
    $runtime = $days * 86400 + $hh * 3600 + $mm * 60 + $ss;
    return $runtime;
}


sub getJobStatus {
    my $self = shift;
    my $jid = shift;
    $jid = $self->getProperJid($jid);
    return $self->{jobs}->{$jid};
}


sub getAllJobIds {
    my $self = shift;
    return [keys %{$self->{jobs}}];
}


sub getProperJid {
    my $self = shift;
    my $jid = shift;
    
    if ($jid =~ m/^\d+$/) {
        return $jid;
    }
    # $jid is a name not numeric ID
    else {
        $jid = $self->{job_names}->{$jid};
        return ($jid ? $jid : 0);
    }
}


sub computeJobStats {
    my $self = shift;
    my $jid = shift;
    $jid = $self->getProperJid($jid);

    my $output = `/usr/bin/sacct -n -o JobID,State,MaxRSS,Elapsed -j $jid`;
    my @lines = split(m/[\r\n]+/s, $output);
    my $ram = 0;
    my $runtime = 0;
    if (scalar @lines > 1) {
        my ($jid, $state, $usage, $elapsed) = split(m/\s+/, $lines[1]);
        if ($state eq "COMPLETED") {
            $usage =~ s/\D+$//;
            $usage *= 1024;
            $ram = $usage;
            $runtime = parseRuntime($elapsed);
        }
    }

    $self->{jobs}->{$jid}->{ram} = $ram;
    $self->{jobs}->{$jid}->{runtime} = $runtime;

    return $self->{jobs}->{$jid};
}


1;

