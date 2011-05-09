#!/usr/bin/env perl
use 5.12.2;
use warnings;
use LWP::UserAgent;
use WWW::Mechanize;
use HTML::TreeBuilder::XPath;
use File::Slurp;
use XML::Simple;

our $GENERALENQUIRY =
    'https://eservices.moreland.vic.gov.au/ePathway/Production/Web/GeneralEnquiry/EnquiryLists.aspx';

our $base_url =
'https://eservices.moreland.vic.gov.au/ePathway/Production/Web/GeneralEnquiry/';

# my $doc = fetch_doc();
my $doc = doc_from_file();
my $results = find_results($doc);
output_xml($results);

sub fetch_doc {
    my $mech = WWW::Mechanize->new;
    $mech->agent_alias('Windows Mozilla');
    $mech->get($GENERALENQUIRY);

    my %form = (
        'mDataGrid:Column0:Property' =>
            'ctl00$MainBodyContent$mDataList$ctl00$mDataGrid$ctl04$ctl00',
    );

    $mech->submit_form(
        with_fields => \%form,
        button => 'ctl00$MainBodyContent$mContinueButton',
    );

    say $mech->status;
    die("Bad HTTP status: " . $mech->status . "\n" . $mech->content . "\n")
        unless $mech->status == 200;

    my $content = $mech->content;
    # write_file('enquirylist.html', $content);

    my $doc = HTML::TreeBuilder::XPath->new;
    eval {
        $doc->parse_content($content);
    };
    if ($@) {
        die "Failed to parse HTML, errors were: $@\n";
    }

    return $doc;
}

sub doc_from_file {
    my $doc = HTML::TreeBuilder::XPath->new;
    $doc->parse_content(read_file('enquirylist.html'));
    return $doc;
}

sub find_results {
    my $doc = shift;
    my @results;
    my @nodes = $doc->findnodes(
'//table[@id="Table2"]/tr/td/div/table/tr/td/table/tr[@class="ContentPanel"]'
    );
    foreach my $node (@nodes) {
#        warn "first level node..";
#        warn "XML = " . $node->toString;
        my @href_nodes = $node->findnodes(
            'td/div[@class="ContentText"]/a'
        );
        my @span_nodes = $node->findnodes(
            'td/span[@class="ContentText"]'
        );
#        for my $td (@href_nodes, @span_nodes) {
#            say $td->toString;
#        }

        # Skip nodes that don't appear to be related to the list we want..
        next unless @href_nodes;
        next unless @span_nodes == 3;

        my $council_reference = flatten($href_nodes[0]);

        my $info_url = $href_nodes[0]->attr('href');

        my $date_received = flatten(shift @span_nodes);

        my $description = flatten(shift @span_nodes);

        my $address = flatten(shift @span_nodes);

        push(@results, {
            council_reference => $council_reference,
            info_url => $base_url . $info_url,
            date_received => date_to_iso($date_received),
            address => $address,
            comment_url => 'TODO XXX',
            date_scraped => date_scraped(),
        });
    }

    return \@results;
}

sub output_xml {
    my $results = shift;
    my $xml = XML::Simple->new(
        ForceArray => 1,
        NoAttr => 1,
        RootName => 'planning',
    );

    my $doc = {
        authority_name => "Moreland Council, VIC",
        authority_short_name => "Moreland",
        applications => {
            application => $results,
        }
    };

    say $xml->XMLout($doc);
}

sub date_scraped {
    my @time = localtime;
    return join('-', $time[5] + 1900, $time[4] + 1, $time[3]);
}

sub flatten {
    my $node = shift;
    my @children = $node->content_list;
    return join('', map { "$_" } @children);
}

sub date_to_iso {
    my $txt = shift;
    if ($txt =~ m{
            ^\s*
            (\d{1,2})
            /
            (\d{1,2})
            /
            (\d{2,4})
            \s*$
        }x
    ) {
        return "$3-$2-$1"
    }
}

