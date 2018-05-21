#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use REST::Client;
use JSON;
use Getopt::Long;

#create releases from the master branch, where a repo has dev and master

my $token = $ENV{GITHUB_TOKEN};

my $release_name;
  GetOptions ('release_name=s' => \$release_name);;

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

    my $releases_url = $repo->{releases_url};
    $releases_url =~ s/{\/id}//;

    my $repo_name = $repo->{name};

    my $branches_url = $repo->{branches_url};
    $branches_url =~ s/{\/branch}//;

    my $dev_branch    = request("$branches_url/$dev_branch_name");
    my $master_branch = request("$branches_url/$master_branch_name");

    if ( exists $dev_branch->{message} || exists $master_branch->{message} ) {
        print "$repo_name not eligible$/";
    }
    else {
        print "$repo_name eligible$/";

        my $releases = request($releases_url);
        my %release_names = map { ($_->{name} => 1, $_->{tag_name} => 1) } @$releases;
        print Dumper ( \%release_names );
        
        if ($release_names{$release_name}){
          print "already have release $release_name for $repo_name$/";
          next;
        }
        exit;

        my $release_body = {
            tag_name         => $release_name,
            target_commitish => 'master',
            name             => $release_name,
            body             => '',
            draft            => JSON::false,
            prerelease       => JSON::true,
        };

        my $release_json = encode_json($release_body);

        my $post_response = $client->POST( $releases_url, $release_json, $headers );

        if ( $post_response->responseCode() ne '201' ) {
            print STDERR "Release NOT created!$/";
            print STDERR Dumper($post_response);
            exit;
        }
        else {
            print "Created $repo_name\t$release_json$/;";
        }

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
