#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use File::Find;
use File::chdir;
use File::Basename;
use GraphViz2;
use List::MoreUtils qw(uniq);

my ( $dir_to_search, $dependency ) = @ARGV;
my @gradle_dirs;
my %deps;

find( \&wanted, $dir_to_search );

for my $gradle_dir (@gradle_dirs) {
    local $CWD = $gradle_dir;    # now in /moo/baz

    my $project       = basename($gradle_dir);
    my $gradle_output = `gradle -q dependencyInsight --dependency $dependency`;

    $deps{$project} = gradle_output_to_direct_deps($gradle_output);
}

print Dumper( \%deps );

my ($graph) = GraphViz2->new(
    edge   => { color    => 'grey', arrowhead => 'normal' },
    global => { directed => 1 },

);

for my $project ( keys %deps ) {

    $graph->add_node( name => $project );

    my $deps = $deps{$project};

    for my $dep (@$deps) {
        $graph->add_edge( from => $project, to => $dep );
    }
}

$graph->run( format => "png", output_file => "$dependency.png" );

sub gradle_output_to_direct_deps {
    my ($gradle_output) = (@_);

    if ( $gradle_output =~ m/^No dependencies/ ) {
        return [];
    }

    my @lines = split /\n/, $gradle_output;
    my @deps;

    for ( my $i = 0 ; $i < scalar(@lines) ; $i++ ) {

        next unless $lines[$i] =~ m/compileClasspath/;
        my $line = $lines[ $i - 1 ];

        $line =~ s/\S+---//;
        $line =~ s/^\s*//;
        $line =~ s/ (selected by rule)//;
        my ( $group, $project, $version ) = split /:/, $line;
        push @deps, $project;
    }

    @deps = uniq @deps;
    
    return \@deps;
}

sub wanted {

    #$File::Find::dir is the current directory name,
    #$_ is the current filename within that directory
    #$File::Find::name is the complete pathname to the file.

    if ( $_ eq 'build.gradle' ) {
        push @gradle_dirs, $File::Find::dir;
    }
}

