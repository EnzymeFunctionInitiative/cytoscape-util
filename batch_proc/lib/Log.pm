
package Log;

use strict;
use warnings;

use POSIX qw(strftime);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;
    $self->{dry_run} = $args{dry_run} // 0;
    $self->{debug} = $args{debug} // 0;

    $self->{file} = $args{file} // "";
    if ($args{file}) {
        open my $fh, ">>", $args{file};
        $self->{fh} = $fh;
    } else {
        my $fh = \*STDOUT;
        $self->{fh} = $fh;
    }

    return $self;
}


sub print_fmt {
    my $self = shift;
    my $dt = getDateTime();
    $self->{fh}->print($dt, " ", join("", @_), "\n");
}


sub print {
    my $self = shift;
    $self->print_fmt("        ", @_);
}


sub debug {
    my $self = shift;
    $self->print_fmt("[DEBUG] ", @_) if $self->{debug} or $self->{dry_run};
}


sub error {
    my $self = shift;
    $self->print_fmt("[ERROR] ", @_);
}


sub warning {
    my $self = shift;
    $self->print_fmt("[WARN]  ", @_);
}


sub getDateTime {
    return strftime("%F %T:%S", localtime);
}


1;

