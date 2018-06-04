#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use REST::Client;
use JSON;

#which of our repos need a pull reques to bring master in line with dev

my $token = $ENV{GITHUB_TOKEN};

my $org_name           = 'EMBL-EBI-SUBS';
my $dev_branch_name    = 'dev';
my $master_branch_name = 'master';

my $client = REST::Client->new();

my $headers = {};
if ($token) {
    $headers->{Authorization} = "token $token";
}
my ( $remaining_requests, $limit_reset_time ) = rate_limits();

my $repos = request("https://api.github.com/orgs/$org_name/repos");

for my $repo (@$repos) {
    next if $repo->{archived};

    my $repo_name = $repo->{name};

    my $comparison = request(
        "https://api.github.com/repos/$org_name/$repo_name/compare/$master_branch_name...$dev_branch_name"
    );

    unless ( exists $comparison->{message}
        && $comparison->{message} eq 'Not Found' )
        {
      my $status = $comparison->{status} || 'NO COMPARISON STATUS';
      my $comp_url = "https://github.com/$org_name/$repo_name/compare/$master_branch_name...$dev_branch_name?expand=1";
      print "$repo_name\t$status\t$comp_url$/";
    }

}

sub rate_limits {
    my $rate_response =
      $client->GET( "https://api.github.com/rate_limit", $headers );
    my $rate_info = decode_json( $rate_response->responseContent() );
    my $remaining_requests = $rate_info->{resources}{core}{remaining};
    my $limit_reset_time   = $rate_info->{resources}{core}{reset};
    return ( $remaining_requests, $limit_reset_time );
}

sub request {
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
    return decode_json( $response->responseContent() );
}
