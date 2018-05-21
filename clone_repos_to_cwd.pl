#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use REST::Client;
use JSON;

my $token = $ENV{GITHUB_TOKEN};

my $org_name    = 'EMBL-EBI-SUBS';
my $branch_name = 'dev';

my $dry_run = 0;

my $client = REST::Client->new();

my $headers = {};
if ($token) {
    $headers->{Authorization} = "token $token";
}
my ( $remaining_requests, $limit_reset_time ) = rate_limits();

my $repos = request_repos("https://api.github.com/orgs/$org_name/repos");

for my $repo (@$repos) {

    #print $repo->{name}.$/;
    next if $repo->{archived};

    # print "not archived$/";
    next unless $repo->{default_branch} eq $branch_name;

    #print "has right default branch$/";
    my $repo_name = $repo->{name};

    my $ssh_url = $repo->{ssh_url};

    my $cmd = "git clone $ssh_url";

    if ($dry_run) {
        print $cmd. $/;
    }
    else {
        system($cmd);
    }
}

sub rate_limits {
    my $rate_response =
      $client->GET( "https://api.github.com/rate_limit", $headers );
    my $rate_info          = decode_json( $rate_response->responseContent() );
    my $remaining_requests = $rate_info->{resources}{core}{remaining};
    my $limit_reset_time   = $rate_info->{resources}{core}{reset};
    return ( $remaining_requests, $limit_reset_time );
}

sub request_repos {
    my ($url) = @_;
    if ( $remaining_requests == 0 ) {
        my $time = time;
        while ( $time < $limit_reset_time ) {
            sleep $time - $limit_reset_time;
        }
        ( $remaining_requests, $limit_reset_time ) = rate_limits();
    }
    my $response = $client->GET( $url, $headers );

    $remaining_requests--;
    my $repo_list = decode_json( $response->responseContent() );

    my $link_header = $client->responseHeader('link');
    my @link_elements = split /,\w?/, $link_header;

    for my $link_element (@link_elements) {
        if ( $link_element =~ m/<(.+)>; rel="next"/ ) {
            my $next_page_content = request_repos($1);
            $repo_list = [ @$repo_list, @$next_page_content ];
        }
    }

    return $repo_list;
}
