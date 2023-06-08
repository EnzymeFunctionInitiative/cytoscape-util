#!/bin/env perl

use strict;
use warnings;

use GD;


my $White = 16777215;


my $inputFile = $ARGV[0];
my $outputFile = $ARGV[1];

print "Need input file\n" and exit(1) if not $inputFile or not -f $inputFile;
print "Input file $inputFile is zero size\n" and exit(1) if not -s $inputFile;

GD::Image->trueColor(1);

print "Loading PNG $inputFile\n";
my $input = GD::Image->newFromPng($inputFile);
my ($width, $height) = $input->getBounds();


#my ($newWidth, $leftStart, $rightStart) = getNewWidth();
#my ($newHeight, $topStart, $bottomStart) = getNewHeight();
my ($newWidth, $newHeight, $leftStart, $rightStart, $topStart, $bottomStart) = getNewDim($width, $height, $input);


my $output = GD::Image->new($newWidth, $newHeight);

$output->copyResized($input, 0, 0, $leftStart, $topStart, $newWidth, $newHeight, $newWidth, $newHeight);

my $pngData = $output->png;


open my $outFh, ">", $outputFile or die "Unable to write to output $outputFile: $!";
binmode $outFh;
print $outFh $pngData;
close $outFh;

print "Finished\n";









sub getNewWidth {
    my $leftStart = -1;
    my $rightStart = -1;
    
    foreach my $x (1..$width) {
        foreach my $y (1..$height) {
            my $idx = $input->getPixel($x - 1, $y - 1);
            if ($idx != $White) {
                $leftStart = $x - 1;
                last;
            }
        }
        last if $leftStart > -1;
    }
    
    foreach my $x (1..$width) {
        foreach my $y (1..$height) {
            my $rightPx = $width - $x;
            my $idx = $input->getPixel($rightPx, $y - 1);
            if ($idx != $White) {
                $rightStart = $rightPx;
                last;
            }
        }
        last if $rightStart > -1;
    }
    
    $leftStart -= 10;
    $rightStart += 10;
    
    $leftStart = 0 if $leftStart < 0;
    $rightStart = $width - 1 if $rightStart < 0;
    
    if ($rightStart - $leftStart < 20) {
        $leftStart = 0;
        $rightStart = 20;
        $height = 20;
    }
    
    my $newWidth = $rightStart - $leftStart + 1;

    return ($newWidth, $leftStart, $rightStart);
}


sub getNewDim {
    my $width = shift;
    my $height = shift;
    my $input = shift;

    my $leftStart = -1;
    my $rightStart = -1;
    my $topStart = $height;
    my $bottomStart = -1;

    foreach my $x (1..$width) {
        foreach my $y (1..$height) {
            my $idx = $input->getPixel($x - 1, $y - 1);
            if ($idx != $White) {
                $leftStart = $x - 1 if $leftStart == -1;
                if ($y - 1 < $topStart) {
                    $topStart = $y - 1;
                }
                #$topStart = $y - 1 if $topStart == -1;
                last;
            }
        }
        # Need to scan entire image for the topStart
        #last if $leftStart > -1 and $topStart > -1;
    }
    
    foreach my $x (1..$width) {
        foreach my $y (1..$height) {
            my $rightPx = $width - $x;
            my $bottomPx = $height - $y;
            my $idx = $input->getPixel($rightPx, $bottomPx);
            if ($idx != $White) {
                $rightStart = $rightPx if $rightStart == -1;
                if ($bottomPx > $bottomStart) {
                    $bottomStart = $bottomPx;
                }
                #$bottomStart = $bottomPx if $bottomStart == -1;
                last;
            }
        }
        # Need to scan entire image for the bottomStart
        #last if $rightStart > -1 and $bottomStart > -1;
    }
    
    $leftStart -= 10;
    $rightStart += 10;
    $topStart -= 10;
    $bottomStart += 10;
    
    $leftStart = 0 if $leftStart < 0;
    $rightStart = $width - 1 if $rightStart < 0;

    $topStart = 0 if $topStart < 0;
    $bottomStart = $height - 1 if $bottomStart < 0;
    
    if ($rightStart - $leftStart < 20) {
        $leftStart = 0;
        $rightStart = 20;
        $height = 20;
    }

    if ($bottomStart - $topStart < 20) {
        $topStart = 0;
        $bottomStart = 20;
        $height = 20;
    }
    
    my $newWidth = $rightStart - $leftStart + 1;
    my $newHeight = $bottomStart - $topStart + 1;

    return ($newWidth, $newHeight, $leftStart, $rightStart, $topStart, $bottomStart);
}


