#!/usr/bin/env perl
# Extract some geolocation data from the iPhone consolidated.db
# (/private/var/root/Library/Caches/locationd/consolidated.db)
# and generate a KML file compatible with Google Earth.
#
# Tables of interest are CellLocation and WifiLocation.
# This file only exists on iOS 4.0 or later.
#
# by gammy 

use strict;
use warnings;

use DBI;
use Geo::GoogleEarth::Pluggable;

die "Usage: $0 <consolidated.db>\n" if @ARGV == 0;
my $DB = pop @ARGV;
die "\"$DB\" is not a file\n" if ! -f "$DB";

my $dbh = DBI->connect("dbi:SQLite:$DB") or die "$!";
my $kml = new Geo::GoogleEarth::Pluggable;
my $kml_cells = $kml->Folder(name => "Cell towers");
my $kml_aps   = $kml->Folder(name => "Access points");
my $kml_style_cells = $kml->IconStyle(
color => {	red   => 0, 
		green => 255,
		blue  => 0},
href  => "http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png");

my $kml_style_aps   = $kml->IconStyle(
color => {	red   => 0, 
		green => 0,
		blue  => 255},
href  => "http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png");

my $skip = 0;
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

	#next if ++$skip % 1 == 0;

	my $desc = sprintf("MAC: %s (partial)\n".
			   "Timestamp: %s\n".
			   "Horizontal accuracy: %s\n".
			   "Confidence: %s\n",
			   $mac, $ts, $h, $c);

	$kml_aps->Point(name        => "AP",
			description => $desc,
			lat         => $lat,
			lon         => $long,
			style       => $kml_style_aps);

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

	#next if ++$skip % 8 == 0;

	my $desc = sprintf("MCC: %s\n".
			   "MNC: %s\n".
			   "LAC: %s\n".
			   "CI: %s\n".
			   "Timestamp: %s\n".
			   "Horizontal accuracy: %s\n".
			   "Confidence: %s\n",
			   $mcc, $mnc, $lac, $ci, $ts, $h, $c);

	$kml_cells->Point(name        => "Cell",
			  description => $desc,
			  lat         => $lat,
			  lon         => $long,
			  style       => $kml_style_cells);
	
}

print "Storing to file..\n";
open F, '>', "out.kml" or die "$!";
print F $kml->render;
close F;
