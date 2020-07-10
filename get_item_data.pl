#!/usr/bin/perl
################################################################################
# SCRIPT get_item_data.pl
# DESCRIPTION : ce script lit en entrée un fichier a séparateur | contenant 
# - Un holding id
# - Un MMS id
# - Une cote
# Il envoie un ordre API à Alma pour récupérer des informations sur la holding
# correspondante.
# ENTREE : nom du fichier tabulé ; clef API
# SORTIE : un fichier par holding 
################################################################################
use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ 
	level => $TRACE, 
	file => ":utf8> get_item_data.log" 
});

# Main
{

	my ($entry_file, $APIKEY) = @ARGV;
	if (not defined $entry_file or not defined $APIKEY) {
    die "Indiquez en entrée (1) le fichier d'entrée pour les holdings et (2) la clef API";
	}

	open ( FILE_IN, "<", $entry_file) || die "Le fichier $entry_file est manquant\n";
	binmode FILE_IN, ":utf8";
	while(<FILE_IN>)
	{
		# Découpage d'une ligne pour extraire le code-barre et la description.
		my $ligne = $_ ;
		chomp($ligne);
		my ($holding,$mms,$cote) = split(/\|/, $ligne);

		# Ecrire un appel API pour récupérer les informations sur l'item. On ignore certains codes-barres néanmoins.
    open ( FILE_OUT, ">", "./items-xml-get/wget-items-" . $holding . "-" . $mms . ".tmp") || die "Impossible d'ouvrir le fichier de sortie temporaire\n";
    binmode FILE_OUT, ":utf8";
		print FILE_OUT "wget -O - -o /dev/null 'https://api-eu.hosted.exlibrisgroup.com/almaws/v1/bibs/" . $mms . "/holdings/" . $holding . "?apikey=" . $APIKEY  . "' > ../items-xml/" . $holding . "-" . $mms . ".tmp" . "\n";
		TRACE "Holding id $holding MMS id $mms traité\n";
    close(FILE_OUT);
	}
close(FILE_IN);
}

