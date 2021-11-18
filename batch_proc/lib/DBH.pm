

package DummySth; use strict; use warnings; sub new  { my ($class, %args) = @_; my $self = {}; bless $self, $class; $self->{data} = $args{data}; $self->{num} = 0; return $self; } sub execute { my $self = shift; return 1; } sub fetchrow_hashref { my $self = shift; if ($self->{num}++ < 1) { return $self->{data}; } else { return undef; }} 1;


package DBH;

use strict;
use warnings;

use DBI;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{dryrun} = $args{dryrun} // 0;
    $self->{dryrun_data} = $args{dryrun_data} // {};
    $self->{debug} = $args{debug} // 0;
    $self->{logger} = $args{logger};

    $self->{use_transactions} = 0;

    if (not $self->{dryrun}) {
        my $dbh = DBI->connect("DBI:SQLite:dbname=$args{file}", "", "");
        $dbh->{AutoCommit} = 0 if $self->{use_transactions};
        $self->{dbh} = $dbh;
        $self->{do_count} = 0;
    }

    return $self;
}


sub prepare {
    my $self = shift;

    $self->printDebug(@_);

    if (not $self->{dryrun}) {
        return $self->{dbh}->prepare(@_);
    } else {
        return new DummySth(data => $self->{dryrun_data});
    }
}


sub do {
    my $self = shift;

    $self->printDebug(@_);

    if (not $self->{dryrun}) {
        $self->{dbh}->do(@_);
        if ($self->{use_transactions} and $self->{do_count}++ > 50) {
            $self->{dbh}->commit;
            $self->{do_count} = 0;
            $self->{logger}->debug("commit transaction");
        }
    }
}


sub tableExists {
    my $self = shift;
    my $table = shift;
    
    return 1 if $self->{dryrun};

    my $checkSql = "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'";
    my $sth = $self->prepare($checkSql);
    $sth->execute;
    my $row = $sth->fetchrow_hashref;
    return $row ? 1 : 0;
}


sub printDebug {
    my $self = shift;
    $self->{logger}->debug(join(", ", @_));
}


1;

