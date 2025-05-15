package Text::Table::HTML::DataTables;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

sub _encode {
    state $load = do { require HTML::Entities };
    my $val = shift;
    # encode_entities change 0 (false) to empty string so we need to filter the
    # value first
    if (!defined $val) {
        "";
    } elsif (!$val) {
        "$val";
    } else {
        HTML::Entities::encode_entities($val);
    }
}

sub _escape_uri {
    require URI::Escape;
    URI::Escape::uri_escape(shift, "^A-Za-z0-9\-\._~/:"); # : for drive notation on Windows
}

sub table {
    require HTML::Entities;
    require JSON::PP;

    my %params = @_;
    my $rows = $params{rows} or die "Must provide rows!";
    my $default_length = int($params{default_length} // 1000);
    my $library_link_mode = $params{library_link_mode} //
        $ENV{PERL_TEXT_TABLE_HTML_DATATABLES_OPT_LIBRARY_LINK_MODE} // 'local';

    my $max_index = _max_array_index($rows);

    # here we go...
    my @table;

    # load css/js
    push @table, "<html>\n";
    push @table, "<head>\n";

    push @table, qq(<title>).HTML::Entities::encode_entities($params{caption}).qq(</title>\n) if defined $params{caption};

    my $jquery_ver = '2.2.4';
    my $datatables_ver = '1.10.22';
    if ($library_link_mode eq 'embed') {
        require File::ShareDir;
        require File::Slurper;
        my $dist_dir = File::ShareDir::dist_dir('Text-Table-HTML-DataTables');
        my $path;

        $path = "$dist_dir/datatables-$datatables_ver/datatables.css";
        -r $path or die "Can't embed $path: $!";
        push @table, "<!-- embedding datatables.css -->\n<style>\n", File::Slurper::read_text($path), "\n</style>\n\n";

        $path = "$dist_dir/jquery-$jquery_ver/jquery-$jquery_ver.min.js";
        -r $path or die "Can't embed $path: $!";
        push @table, "<!-- embedding jquery.js -->\n<script>\n", File::Slurper::read_text($path), "\n</script>\n\n";


        $path = "$dist_dir/datatables-$datatables_ver/datatables.js";
        -r $path or die "Can't embed $path: $!";
        push @table, "<!-- embedding datatables.js -->\n<script>\n", File::Slurper::read_text($path), "\n</script>\n\n";

    } elsif ($library_link_mode eq 'local') {
        require File::ShareDir;
        my $dist_dir = File::ShareDir::dist_dir('Text-Table-HTML-DataTables');
        $dist_dir =~ s!\\!/!g if $^O eq 'MSWin32';
        push @table, qq(<link rel="stylesheet" type="text/css" href="file://)._escape_uri("$dist_dir/datatables-$datatables_ver/datatables.css").qq(">\n);
        push @table, qq(<script src="file://)._escape_uri("$dist_dir/jquery-$jquery_ver/jquery-$jquery_ver.min.js").qq("></script>\n);
        push @table, qq(<script src="file://)._escape_uri("$dist_dir/datatables-$datatables_ver/datatables.js").qq("></script>\n);
    } else {
        die "Unknown value for the 'library_link_mode' option: '$library_link_mode', please use one of local|embed";
    }

    push @table, '<script>';
    my $dt_opts = {
        dom => 'lQfrtip',
        buttons => ['colvis', 'print'],
    };
    push @table, 'var dt_opts = ', JSON::PP::encode_json($dt_opts), '; ';
    push @table, '$(document).ready(function() { ', (
        '$("table").DataTable(dt_opts); ',
        '$("select[name=DataTables_Table_0_length]").val('.$default_length.'); ', # XXX element name should not be hardcoded, and this only works for the first datatable
        '$("select[name=DataTables_Table_0_length]").trigger("change"); ',        # doesn't get triggered automatically by previous line
    ), '});';
    push @table, '</script>'."\n\n";
    push @table, "</head>\n\n";

    push @table, "<body>\n";
    push @table, "<table>\n";
    push @table, qq(<caption>).HTML::Entities::encode_entities($params{caption}).qq(</caption>\n) if defined $params{caption};

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
    push @table, "</body>\n\n";

    push @table, "</html>\n";

    return join("", grep {$_} @table);
}

# FROM_MODULE: PERLANCAR::List::Util::PP
# BEGIN_BLOCK: max
sub max {
    return undef unless @_; ## no critic: Subroutines::ProhibitExplicitReturnUndef
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

The datatables bundled in this distribution has the following characteristics:

=over

=item * Support negative search using dash prefix syntax ("-foo") a la Google

To search for table rows that contain "foo", "bar" (in no particular order) and
not "baz", you can enter in the search box:

 foo bar -baz

=back

The example shown in the SYNOPSIS generates HTML code like the following:

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

The C<table> function understands these parameters, which are passed as a hash:

=over

=item * rows (aoaos)

Takes an array reference which should contain one or more rows of data, where
each row is an array reference.

=item * caption

Optional. Str. If set, will output a HTML C<< <title> >> element in the HTML
head as well as table C<< <caption> >> element in the HTML body containing the
provided caption. The caption will be HTML-encoded.

=item * default_length

Integer, defaults to 1000. Set the default page size.

=item * library_link_mode

Str, defaults to C<local>. Instructs how to link or embed the JavaScript
libraries in the generated HTML page. Valid values include: C<local> (the HTML
will link to the local filesystem copy of the libraries, e.g. in the shared
distribution directory), C<cdn> (not yet implemented, the HTML will link to the
CDN version of the libraries), C<embed> (the HTML will embed the libraries
directly).

=back


=head1 ENVIRONMENT

=head2 PERL_TEXT_TABLE_HTML_DATATABLES_OPT_LIBRARY_LINK_MODE

String. Used to set the default for the C<library_link_mode> option.


=head1 SEE ALSO

L<Text::Table::HTML>

See also L<Bencher::Scenario::TextTableModules>.

L<https://datatables.net>

=cut
