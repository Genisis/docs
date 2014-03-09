package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture_merged tee_merged);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(run $Opts build_chunked build_single sha_for timestamp);
our $Opts      = {};

our $HTML_Header = <<'HTML';
<!DOCTYPE html>
<!--[if lt IE 7]>      <html class="no-js lt-ie9 lt-ie8 lt-ie7"> <![endif]-->
<!--[if IE 7]>         <html class="no-js lt-ie9 lt-ie8"> <![endif]-->
<!--[if IE 8]>         <html class="no-js lt-ie9"> <![endif]-->
<!--[if gt IE 8]><!--> <html class="no-js"> <!--<![endif]-->
HTML

#===================================
sub build_chunked {
#===================================
    my ( $index, $dest, %opts ) = @_;

    fcopy( 'resources/styles.css', $index->parent )
        or die "Couldn't copy <styles.css> to <" . $index->parent . ">: $!";

    my $chunk   = $opts{chunk} || 0;
    my $build   = $dest->parent;
    my $version = $opts{version} || 'test build';
    my $multi   = $opts{multi} || 0;
    my $lenient = $opts{lenient} || '';

    my $output = run(
        'a2x', '-v', '--icons',
        '-d'              => 'book',
        '-f'              => 'chunked',
        '-a'              => 'showcomments=1',
        '--xsl-file'      => 'resources/website_chunked.xsl',
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '--xsltproc-opts' => "--stringparam chunk.section.depth $chunk",
        '--xsltproc-opts' => "--stringparam local.book.version '$version'",
        '--xsltproc-opts' =>
            "--stringparam local.book.multi_version '$multi'",
        '--destination-dir=' . $build,
        ( $lenient ? '-L' : () ),
        $index
    );

    $index->parent->file('styles.css')->remove;

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    if (@warn) {
        $lenient
            ? warn join "\n", @warn
            : die join "\n", @warn;
    }

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $build->children
        or die "Couldn't find chunk dir in <$build>";

    to_html5($chunk_dir);

    $dest->rmtree;
    rename $chunk_dir, $dest
        or die "Couldn't move <$chunk_dir> to <$dest>: $!";

    sense_widget( $index->parent, $dest );

}

#===================================
sub build_single {
#===================================
    my ( $index, $dest, %opts ) = @_;

    my $toc = $opts{toc} ? 'book toc' : '';
    my $type    = $opts{type}    || 'book';
    my $lenient = $opts{lenient} || '';
    my $version = $opts{version} || 'test build';
    my $multi   = $opts{multi}   || 0;

    fcopy( 'resources/styles.css', $index->parent )
        or die "Couldn't copy <styles.css> to <" . $index->parent . ">: $!";

    my $output = run(
        'a2x', '-v', '--icons',
        '-f'              => 'xhtml',
        '--xsl-file'      => 'resources/website.xsl',
        '-d'              => $type,
        '--asciidoc-opts' => '-fresources/es-asciidoc.conf',
        '-a'              => 'showcomments=1',
        '--xsltproc-opts',
        "--stringparam generate.toc '$toc'",
        '--xsltproc-opts' => "--stringparam local.book.version '$version'",
        '--xsltproc-opts' =>
            "--stringparam local.book.multi_version '$multi'",
        '--destination-dir=' . $dest,
        ( $lenient ? '-L' : () ),
        $index
    );

    $index->parent->file('styles.css')->remove;

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    if (@warn) {
        $lenient
            ? warn join "\n", @warn
            : die join "\n", @warn;
    }

    to_html5($dest);
    sense_widget( $index->parent, $dest );
}

#===================================
sub sense_widget {
#===================================
    my ( $source, $dest ) = @_;
    my $snippets = $source->subdir('snippets');
    return unless -e $snippets;

    fcopy( 'resources/sense_widget.html', $dest )
        or die "Couldn't copy <sense_widget.html> to <$dest>: $!";

    $dest = $dest->subdir('snippets');
    rcopy( $snippets, $dest )
        or die "Couldn't copy <$snippets> to <$dest>: $!";

}

#===================================
sub to_html5 {
#===================================
    my $dir = shift;
    for my $file ( $dir->children ) {
        next if $file->is_dir or $file->basename !~ /\.html$/;
        my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $contents =~ s/\s+xml:lang="[^"]*"//g;
        $contents =~ s/^<\?xml[^>]+>\n//;
        $contents =~ s/^<!DOCTYPE[^>]+>\n?<html>/$HTML_Header/;
        $contents =~ s/\s+$//;
        $contents .= "\n";
        $file->spew( iomode => '>:utf8', $contents );
    }
}

#===================================
sub run (@) {
#===================================
    my @args = @_;
    my ( $out, $ok );
    if ( $Opts->{verbose} ) {
        say "Running: @args";
        ( $out, $ok ) = tee_merged { system(@args) == 0 };
    }
    else {
        ( $out, $ok ) = capture_merged { system(@args) == 0 };
    }

    die "Error executing: @args\n$out"
        unless $ok;

    return $out;
}

#===================================
sub sha_for {
#===================================
    my $rev = shift;
    my $sha = eval { run 'git', 'rev-parse', $rev } || '';
    chomp $sha;
    return $sha;
}

#===================================
sub timestamp {
#===================================
    my ( $sec, $min, $hour, $mday, $mon, $year ) = gmtime();
    $year += 1900;
    $mon++;
    sprintf "%04d-%02d-%02dT%02d:%02d:%02d+00:00", $year, $mon, $mday, $hour,
        $min, $sec;
}

1
