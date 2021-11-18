

package Queue::Actions;

use strict;
use warnings;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{queue} = $args{queue};
    $self->{dry_run} = $args{dry_run} // 0;
    $self->{logger} = $args{logger};

    return $self;
}


sub submitJob {
    my $self = shift;
    my $outFile = shift;

    if ($self->{dry_run}) {
        $self->{logger}->print("sbatch $outFile\n");
        return 1;
    } else {
        my $output = `sbatch $outFile`;
        chomp $output;
        (my $jid = $output) =~ s/^.*?(\d+)\s*$/$1/;
        return $jid;
    }
}


sub cancelJob {
    my $self = shift;
    my @jobs = @_;

    my $scancel = sub {
        my $jid = $_[0];
        if ($self->{dry_run}) {
            $self->{logger}->print("scancel $jid\n");
        } else {
            `scancel $_[0]`;
        }
    };
    foreach my $jobId (@jobs) {
        if (ref $jobId eq "ARRAY") {
            map { &$scancel($_); } @$jobId;
        } else {
            &$scancel($jobId);
        }
    }
}


sub createScript {
    my $self = shift;
    my %args = @_;

    open my $fh, ">", $args{file} or die "Unable to write to script file $args{file}$!";
    print $fh $self->getHeader(%args);
    foreach my $command (@{ $args{commands} }) {
        print $fh $command, "\n";
    }
    close $fh;
}


sub getHeader {
    my $self = shift;
    my %args = @_;

    my $header = <<HDR;
#!/bin/bash
#SBATCH --partition=$self->{queue}
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --mem=$args{mem}gb
#SBATCH --job-name="$args{name}"
#SBATCH --kill-on-invalid-dep=yes
#SBATCH -o $args{file}.stdout.%j
#SBATCH -e $args{file}.stderr.%j
HDR
    
    $header .= "#SBATCH --nodelist=$args{node}\n" if $args{node};
    $header .= "\n";

    return $header;
}


1;

