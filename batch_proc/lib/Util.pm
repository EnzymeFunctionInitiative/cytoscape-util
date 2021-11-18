
package Util;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cluster_id_sort);


sub cluster_id_sort {
    my ($a, $b) = @_;
    $a =~ s%^.*(cluster[\-0-9]+)$%$1%;
    $b =~ s%^.*(cluster[\-0-9]+)$%$1%;
    my @a = split(m/-/, $a);
    my @b = split(m/-/, $b);
    my $maxi = $#a > $#b ? $#b : $#a;
    for (my $i = 1; $i <= $maxi; $i++) {
        my $cmp = $a[$i] <=> $b[$i];
        return $cmp if $cmp;
    }
    return 0 if $#a == $#b;
    return $#a > $#b;
}


1;

