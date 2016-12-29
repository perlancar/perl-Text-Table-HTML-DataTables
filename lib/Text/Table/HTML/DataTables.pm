package Text::Table::HTML::DataTables;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

sub _encode {
    state $load = do { require HTML::Entities };
    HTML::Entities::encode_entities(shift);
}

sub _escape_uri {
    require URI::Escape;
    URI::Escape::uri_escape(shift, "^A-Za-z0-9\-\._~/");
}

sub table {
    require File::ShareDir;

    my %params = @_;
    my $rows = $params{rows} or die "Must provide rows!";

    my $max_index = _max_array_index($rows);

    my $dist_dir = File::ShareDir::dist_dir('Text-Table-HTML-DataTables');

    # here we go...
    my @table;

    # load css/js
    push @table, qq(<link rel="stylesheet" type="text/css" href="file://)._escape_uri("$dist_dir/datatables-1.10.13/css/jquery.dataTables.min.css").qq(">\n);
    push @table, qq(<script src="file://)._escape_uri("$dist_dir/jquery-2.2.4/jquery-2.2.4.min.js").qq("></script>\n);
    push @table, qq(<script src="file://)._escape_uri("$dist_dir/datatables-1.10.13/js/jquery.dataTables.min.js").qq("></script>\n);
    push @table, '<script>$(document).ready(function() { $("table").DataTable(); });</script>'."\n\n";

    push @table, "<table>\n";

    # then the data
    my $i = -1;
    foreach my $row ( @{ $rows }[0..$#$rows] ) {
        $i++;
        my $in_header;
        if ($params{header_row}) {
            if ($i == 0) { push @table, "<thead>\n"; $in_header++ }
            if ($i == 1) { push @table, "<tbody>\n" }
        } else {
            if ($i == 1) { push @table, "<tbody>\n" }
        }
        push @table, join(
	    "",
            "<tr>",
	    (map {(
                $in_header ? "<th>" : "<td>",
                _encode($row->[$_] // ''),
                $in_header ? "</th>" : "</td>",
            )} 0..$max_index),
            "</tr>\n",
	);
        if ($i == 0 && $params{header_row}) {
            push @table, "</thead>\n";
        }
    }

    push @table, "</tbody>\n";
    push @table, "</table>\n";

    return join("", grep {$_} @table);
}

# FROM_MODULE: PERLANCAR::List::Util::PP
# BEGIN_BLOCK: max
sub max {
    return undef unless @_;
    my $res = $_[0];
    my $i = 0;
    while (++$i < @_) { $res = $_[$i] if $_[$i] > $res }
    $res;
}
# END_BLOCK: max

# return highest top-index from all rows in case they're different lengths
sub _max_array_index {
    my $rows = shift;
    return max( map { $#$_ } @$rows );
}

1;
#ABSTRACT: Generate HTML table with jQuery and DataTables plugin

=for Pod::Coverage ^(max)$

=head1 SYNOPSIS

 use Text::Table::HTML::DataTables;

 my $rows = [
     # header row
     ['Name', 'Rank', 'Serial'],
     # rows
     ['alice', 'pvt', '123<456>'],
     ['bob',   'cpl', '98765321'],
     ['carol', 'brig gen', '8745'],
 ];
 print Text::Table::HTML::DataTables::table(rows => $rows, header_row => 1);


=head1 DESCRIPTION

This module is just like L<Text::Table::HTML>, except the HTML code will also
load jQuery (L<http://jquery.com>) and the DataTables plugin
(L<http://datatables.net>) from the local filesystem (distribution shared
directory), so you can filter and sort the table in the browser.

The example shown in the SYNOPSIS generates the following table:

 <link rel="stylesheet" type="text/css" href="file:///home/ujang/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/auto/share/dist/Text-Table-HTML-DataTables/datatables-1.10.13/css/jquery.dataTables.min.css">
 <script src="file:///home/ujang/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/auto/share/dist/Text-Table-HTML-DataTables/jquery-2.2.4/jquery-2.2.4.min.js"></script>
 <script src="file:///home/ujang/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/auto/share/dist/Text-Table-HTML-DataTables/datatables-1.10.13/js/jquery.dataTables.min.js"></script>
 <script>$(document).ready(function() { $("table").DataTable(); });</script>

 <table>
 <thead>
 <tr><th>Name</th><th>Rank</th><th>Serial</th></tr>
 </thead>
 <tbody>
 <tr><td>alice</td><td>pvt</td><td>12345</td></tr>
 <tr><td>bob</td><td>cpl</td><td>98765321</td></tr>
 <tr><td>carol</td><td>brig gen</td><td>8745</td></tr>
 </tbody>
 </table>


=head1 FUNCTIONS

=head2 table(%params) => str


=head2 OPTIONS

The C<table> function understands these arguments, which are passed as a hash.

=over

=item * rows (aoaos)

Takes an array reference which should contain one or more rows of data, where
each row is an array reference.

=back


=head1 SEE ALSO

L<Text::Table::HTML>

See also L<Bencher::Scenario::TextTableModules>.

=cut
