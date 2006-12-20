#!/usr/bin/perl -w

# This script takes one file in stdin:
# the database of wires
# it generates a .ini file for reading by the wiring.c code

use strict;
use integer;

my $prefix = shift @ARGV;

# We must fill in some things
my %dx;
my %dy;
my %otherend;
my %type;
my %dir;
my %sit;

#wires ultimately are numbered
my %nums;
my @wires;


#define WIRE_NUM_NEUTRAL 32

my @det_dir = ( "WIRE_DIRECTION_NEUTRAL",
		"N",  "WN",  "NW",  "W",  "WS",   "SW",  "S",   "SE",
		"ES",  "E",   "EN",   "NE",  "DN",   "UP" );

my @det_sit = ( "WIRE_SITUATION_NEUTRAL",
		"BEG", "A", "B", "MID", "C", "D", "END" );

my @det_type = ( "WIRE_TYPE_NEUTRAL",
		 "DOUBLE", "HEX",    "OMUX",    "BX", "BY",
		 "BX_PINWIRE", "BY_PINWIRE",    "CE", "CIN",    "CLK",
		 "COUT",    "DX", "DY",    "F1", "F2", "F3", "F4",
		 "F1_PINWIRE", "F2_PINWIRE", "F3_PINWIRE", "F4_PINWIRE",
		 "F5", "FX", "FXINA", "FXINB",    "G1", "G2", "G3",
		 "G4",    "G1_PINWIRE", "G2_PINWIRE", "G3_PINWIRE",
		 "G4_PINWIRE",    "GCLK",    "GCLKC_GCLKB",
		 "GCLKC_GCLKL", "GCLKC_GCLKR", "GCLKC_GCLKT",
		 "GCLKH_GCLK_B",    "GCLKH_GCLK",    "LH", "LV",
		 "SHIFTIN", "SHIFTOUT", "SR",    "TBUF", "TBUS",
		 "TI", "TOUT", "TS",    "VCC_PINWIRE",    "WF1_PINWIRE",
		 "WF2_PINWIRE", "WF3_PINWIRE", "WF4_PINWIRE",
		 "WG1_PINWIRE", "WG2_PINWIRE", "WG3_PINWIRE",
		 "WG4_PINWIRE",    "X", "XB", "XQ",    "Y", "YB", "YQ",
		 "NR_WIRE_TYPE");

my %type_h;
my %dir_h;
my %sit_h;

&array_to_hash(\%type_h,\@det_type);
&array_to_hash(\%dir_h,\@det_dir);
&array_to_hash(\%sit_h,\@det_sit);

#convert these to hashes




while (<STDIN>) {
    chomp;
    my $wire = $_;
    my $mdx = 0;
    my $mdy = 0;
    my $end;

    my $wtype = "WIRE_TYPE_NEUTRAL";
    my $wsit = "WIRE_SITUATION_NEUTRAL";
    my $wdir = "WIRE_DIRECTION_NEUTRAL";

    # all kind of wires ! This is sooooo cool
    # doubles & hexes
    if (m/^(.*_?)([ENSW])([26])(BEG|A|B|MID|C|D|END)([0-9])$/) {
	my $prefix = $1;
	my $orientation = $2;
	my $length = $3;
	my $step = 0;
	my $middle = $4;
	my $rank = $5;

	if ($length == 6) {
	    # HEX
	    # A, B, C, D only makes sense with hex
	    my %step_ref = ("BEG" => 0,
			    "A" => 1,
			    "B" => 2,
			    "MID" => 3,
			    "C" => 4,
			    "D" => 5,
			    "END" => 6);
	    $step = $step_ref{$middle};
	    $wtype = "HEX";
	} else {
	    #DOUBLE
	    my %step_ref = ("BEG" => 0,
			    "MID" => 1,
			    "END" => 2);
	    $step = $step_ref{$middle};
	    $wtype = "DOUBLE";
	}

	$wsit = $middle;

	$mdx = &dx_of_dir($orientation);
	$mdy = &dy_of_dir($orientation);
	$mdx = $mdx * $step;
	$mdy = $mdy * $step;

	$end = $prefix.$orientation.$length."BEG".$rank;
	&register_wire($wire, $mdx, $mdy, $end, $wtype, $wsit, $orientation);
	next;
    }

    #double / hexes with some jumping around
    if (m/^(.*_?)([ENSW])(6)END_([ENSW])([0-9])$/) {
	my $prefix = $1;
	my $orientation = $2;
	my $suborientation = $4;
	my $length = $3;
	my $step = 0;
	my $rank = $5;

	$wtype = "HEX";
	$wsit = "END";

	$step = $length;

	$mdx = &dx_of_dir($orientation);
	$mdy = &dy_of_dir($orientation);
	$mdx = $mdx * $step;
	$mdy = $mdy * $step;

	my $m2dx = &dx_of_dir($orientation);
	my $m2dy = &dy_of_dir($orientation);
	$mdx += $m2dx;
	$mdy += $m2dy;

	$end = $prefix.$orientation.$length."BEG".$rank;
	&register_wire($wire, $mdx, $mdy, $end, $wtype, $wsit, $orientation);
	next;
    }

    #start omuxes
    if (m/^OMUX[0-9]*$/) {
	#well, there's the start, aren't they
	$wtype = "OMUX";
	&register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
	next;
    }

    #end omuxes
    if (m/^OMUX_([NWSE]*)([0-9]*)$/) {
	my $orientation = $1;
	my $rank = $2;

	my $mdx = &dx_of_dir($orientation);
	my $mdy = &dy_of_dir($orientation);

	$wtype = "OMUX";

	$end = "OMUX".$rank;
	&register_wire($wire, $mdx, $mdy, $end, $wtype, $wsit, $orientation);
	next;
    }

    #many others
    if (m/^([FG])([1-4])_B([0-3])/) {
	#local wires
	&register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
	next;
    }

    if (m/^([XY])([BQ]?)([0-3])/) {
	#local wires
	&register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
	next;
    }

    if (m/^B([XY])([0-3])/) {
	#local wires
	&register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
	next;
    }

    if (m/^.*_?L([VH])([0-9]*)/) {
	&register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
	#long wires. Not sure what to do: fall through
	next;
    }

    print STDERR "Warning, unmatched wire $wire\n";
    &register_wire($wire, 0, 0, $wire, $wtype, $wsit, $wdir);
}

sub dx_of_dir() {
    my $dir = shift;

    if ($dir =~ m/E/) {
	return 1;
    }
    if ($dir =~ m/W/) {
	return -1;
    }
    return 0;
}

sub dy_of_dir() {
    my $dir = shift;

    if ($dir =~ m/S/) {
	return 1;
    }
    if ($dir =~ m/N/) {
	return -1;
    }
    return 0;
}

#sort the wires in string order
@wires = sort (@wires);

#assign them their number
my $i = 0;
my $wire;
foreach $wire (@wires) {
    $nums{$wire} = $i;
    $i++;
}

&dump_ini;

sub register_wire() {
    my $wire = shift;
    my $dx = shift;
    my $dy = shift;
    my $end = shift;

    my $wtype = shift;
    my $wsit = shift;
    my $wdir = shift;

    # Type is not redundant
    my $type = shift;
    # dir is redundant with dx, dy
    my $dir = shift;
    # sit is redundant with type + dx, dy, I think
    my $sit = shift;

    # in case we found nothing, only give a number to the thing and backoff
    push @wires, $wire;
    $dx{$wire} = $dx;
    $dy{$wire} = $dy;
    $otherend{$wire} = $end;

    # XXX These need to be filled
    $type{$wire} = $type_h{$wtype};
    $dir{$wire} = $dir_h{$wdir};
    $sit{$wire} = $sit_h{$wsit};

}

sub array_to_hash() {
    my $r_hash = shift;
    my @array = @{(shift)};
    my $i = 0;
    my $elem;

    foreach $elem (@array) {
	$$r_hash{$elem} = $i;
#	print "$elem has number $i";
	$i++;
    }
}

#TODO: add some information there, about the min bit, the max bit,
#the red/black coloring, what else -- maybe in C.

sub dump_ini {
    my $output;
    for $output (@wires) {
	print "[$output]\n";
	print "ID=$nums{$output}\n";
	print "DX=$dx{$output}\n";
	print "DY=$dy{$output}\n";
	if (defined $nums{$otherend{$output}}) {
	    print "EP=$nums{$otherend{$output}}\n";
	}
	else {
#	    print "EP=unknown_$otherend{$output}\n";
	    print "EP=$nums{$output}\n";
	}
	print "TYPE=$type{$output}\n";
	print "DIR=$dir{$output}\n";
	print "SIT=$sit{$output}\n";
    }
}
