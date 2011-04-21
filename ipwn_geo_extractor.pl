#!/usr/bin/env perl
# Extract some geolocation data from the iPhone consolidated.db
# (/private/var/root/Library/Caches/locationd/consolidated.db)
# and generate a KML file compatible with Google Earth.
#
# Tables of interest are CellLocation and WifiLocation.
# This file only exists on iOS 4.0 or later.
# by gammy

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Geo::GoogleEarth::Document;

die "Usage: $0 <consolidated.db>\n" if @ARGV == 0;
my $DB = pop @ARGV;
die "\"$DB\" is not a file\n" if ! -f "$DB";

my $dbh = DBI->connect("dbi:SQLite:$DB") or die "$!";
my $kml = new Geo::GoogleEarth::Document;

my $res;
my %count;

$count{$_} = $dbh->selectrow_array("SELECT count(*) FROM $_") 
	for qw/CellLocation WifiLocation/;

$count{total} = $count{CellLocation} + $count{WifiLocation};

printf("%6d Cells\n%6d APs\n(%d total)\n\n",
      $count{CellLocation},
      $count{WifiLocation},
      $count{total});

print "Reading Cell locations..\n";
$res = $dbh->selectall_arrayref("SELECT
					MAC, 
					Timestamp,
					Latitude,
					Longitude,
					HorizontalAccuracy,
					Confidence
				FROM
					WifiLocation");
foreach(@$res) {
	my($mac, $ts, $lat, $long, $h, $c) = @$_;
	$kml->Placemark(name => $mac,
			lat  => $lat,
			lon  => $long);
}

print "Reading Wifi locations..\n";
$res = $dbh->selectall_arrayref("SELECT
					MCC, 
					MNC,
					LAC,
					CI,
					TimeStamp,
					Latitude,
					Longitude,
					HorizontalAccuracy,
					Confidence
				FROM
					CellLocation");
foreach(@$res) {
	my($mcc, $mnc, $lac, $ci, $ts, $lat, $long, $h, $c) = @$_;
	my $name = "Cell [MCC=$mcc,MNC=$mnc,LAC=$lac,CI=$ci]";
	$kml->Placemark(name => $name,
			lat  => $lat,
			lon  => $long);
}

print "Storing to file..\n";
open F, '>', "out.kml" or die "$!";
print F $kml->render;
close F;
