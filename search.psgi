#!/usr/bin/env perl

use strict;
use warnings;
use Encode qw(encode_utf8);
use Plack::Request;
use Plack::Builder;
use Plack::Response;
use Search::Elasticsearch;

use FindBin;
use lib "$FindBin::RealBin/lib";
use ES::Util qw(run);

chdir($FindBin::RealBin);

our $host = 'localhost:9200';
our $es   = Search::Elasticsearch->new( nodes => $host );
our $JSON = $es->transport->serializer;
my $url_re = qr{
    ^https?://[^/]+/guide/
    (.+?)                           # book
    (?:/(current|master|\d[^/]+))?  # version
    (/[^/]+)                        # remainder
    $}x;

builder {
    mount '/search/' => \&doc_search;
    mount '/status'  => \&status;
};

#===================================
sub status {
#===================================
    my $req = Plack::Request->new( shift() );
    my $result
        = eval { run(qw(git show --shortstat _index)); }
        || $@
        || 'Unknown error';
    return [ 200, [ 'Content-Type' => 'text/plain' ], [$result] ];

}

#===================================
sub doc_search {
#===================================
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $q        = $req->param('q');
    my $callback = $req->param('callback');

    my $ref = $env->{"HTTP_REFERER"} || '';
    my ( $book, $version );
    if ( $ref =~ /$url_re/ ) {
        $book    = $1;
        $version = $2;
    }
    $version ||= 'current';

    my $query = {
        filtered => {
            query => {
                multi_match => {
                    query => $q,

                    #type   => 'cross_fields',
                    fields => [
                        'title^2',        'title.content',
                        'title.shingles', 'title.ngrams',
                        'text',           'text.content',
                        'text.shingles',  'text.ngrams',
                    ],
                    minimum_should_match => '80%',
                    }

            },
            filter =>
                { bool => { must => [ { term => { version => $version } } ] } }
        },

    };
    if ($book) {
        push @{ $query->{filtered}{filter}{bool}{must} },
            { term => { "book.raw" => $book } };
    }
    else {
        $query = {
            function_score => {
                query     => $query,
                functions => [
                    {   filter => {
                            term =>
                                { "book.raw" => 'en/elasticsearch/reference' }
                        },
                        boost_factor => 1.5
                    }
                ]
            }
        };
    }

    my $result = $es->search(
        index   => 'docs',
        _source => [ 'title', 'abbr', 'url', 'path', 'book' ],
        body    => {
            query => $query,
            size  => 10,
        },
    );

    for ( @{ $result->{hits}{hits} } ) {
        $_->{fields} = delete $_->{_source};
    }
    my $json = $JSON->encode($result);

    $json = $callback . '(' . $json . ')'
        if $callback;

    return [ 200, [ 'Content-Type' => 'application/json' ], [$json] ];

}
