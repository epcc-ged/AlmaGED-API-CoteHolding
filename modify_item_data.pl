#!/usr/bin/perl
################################################################################
# SCRIPT modify_item_data.pl
# DESCRIPTION : ce script lit en entrée des fichiers xml contenant la 
# notice d'une holding. Il en modifie l'information de façon à y inscrire une
# cote fournie en entrée.
# SORTIE : un fichier par holding.
################################################################################
use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ 
	level => $TRACE, 
	file => ":utf8> modify_item_data.log" 
});
use XML::Twig;

my $adresse_api = 'https://api-eu.hosted.exlibrisgroup.com/almaws/v1/bibs/mms_id/holdings/holding_id/';
# Création d'un dictionnaire faisant correspondre les codes-barres et les descriptions
# ####################################################################################
my %id2cote;
my ($entry_file, $APIKEY) = @ARGV;
if (not defined $entry_file or not defined $APIKEY) {
	  die "Indiquez en entrée (1)un fichier contenant les informations holdings avec la cote cible et (2) la clef API";
}
else {
    TRACE "Fichier traité : $entry_file\n";
}
open ( FILE_IN, "<", $entry_file) || die "Le fichier $entry_file est manquant\n";
binmode FILE_IN, ":utf8";
while (<FILE_IN>)
{ 
	chomp;
	my ($holding, $mms, $cote) = split /\|/;
	# Si jamais un code barre apparaît deux fois, on n'a pas le choix : il faut
	# écraser avec la dernière valeur trouvée.
	# #########################################################################
	$id2cote{$holding."-".$mms} = $cote; 
}
close(FILE_IN);

my $mms_id;
my $holding_id;

# Main
{
	# Traitement des exemplaires concernées un par un.
	# ################################################
	my $repertoire = "./items-xml/";
	opendir my($rep), $repertoire;
	my @files = readdir $rep;
  foreach my $FILE_NAME (@files) 
	{
		if (($FILE_NAME ne '..') and ($FILE_NAME ne '.') and ($FILE_NAME ne 'traites') and ($FILE_NAME ne 'log'))
		{
		  my $fichier_xml = $repertoire . $FILE_NAME;
		  TRACE "Fichier traité : $fichier_xml\n";
			# J'extrais le MMS ID du nom du fichier
			# J'extrais le HOLDING ID du nom du fichier
			# Le nom de fichier est structuré ainsi holdingId-MMSId.tmp
			# On repère la position du . : il faudra s'arrêter juste avant, car on comptera les positions après le - qui entraîne un décalage d'une place dans le compte
			my $position_fin = index($FILE_NAME, '.');
			$position_fin -= 1;
			my $position_debut = index($FILE_NAME, '-');
			# pour extraire, le MMS, on commence juste après le -
			$mms_id = substr($FILE_NAME, $position_debut+1, $position_fin-$position_debut);
			$holding_id = substr($FILE_NAME, 0, $position_debut);
			TRACE "--> MMS ID : $mms_id\n"; 
			TRACE "--> HOLDING ID : $holding_id\n";
	    # Lecture des informations récupérées d'Alma. C'est un arbre XML.
	    # ###############################################################
	    my $twig= new XML::Twig( 
				    output_encoding => 'UTF-8',
		        twig_handlers =>                 
		          { 
								subfield => \&subfield
							}                             
            );                               

	    $twig->parsefile($fichier_xml);

			# Construction de l'ordre API à envoyer à Alma.
			# #############################################

			# $twig->print(pretty_print=>'indented');
      my $sortie = $twig->sprint;               # C'est le XML a envoyer dans Alma après les modifications
			$sortie =~ s/"/\\"/g;                     # Il faut y protéger les double quotes
			$sortie =~ s/\n//g;                       # et y retirer les \n.
			my $temp_adresse_api = $adresse_api;
			$temp_adresse_api =~ s/mms_id/$mms_id/g;           # Mettre l'identifiant de la bib dans l'appel API
			$temp_adresse_api =~ s/holding_id/$holding_id/g;   # Mettre l'identifiant holding dans l'appel API

			my $ordre_api = 'curl -X PUT "'. $temp_adresse_api . '?apikey=' . $APIKEY . '" -H  "accept: application/xml" -H  "Content-Type: application/xml" -d "';
			$ordre_api = $ordre_api . $sortie . "\" > log/modified" . $FILE_NAME . ".log";
			#TRACE "--> Ordre API à envoyer à Alma : $ordre_api\n";

			# Enregistrement de l'ordre dans un fichier.
			# ##########################################
	    open (my $file_out, ">", "./items-xml-modified/modified-".$FILE_NAME) || die "Impossible d'ouvrir le fichier de sortie temporaire\n";
			binmode $file_out, ":utf8";
			print $file_out $ordre_api;
	    close($file_out);
    }
  }
}

# Récupération du holding id et écriture de la cote temporaire
# ############################################################
sub subfield {
	my ($twig, $subfield_data)= @_;
	if ($subfield_data->att_exists("code")) {
		# On repère la cote et on la modifie, sinon on ne fait rien
		if ($subfield_data->att("code") eq "h") {
	    my $cote_finale = $id2cote{$holding_id."-".$mms_id};
	    TRACE "--> Cote finale écrite : $cote_finale";
			$subfield_data->set_text($cote_finale);
		}
	}
}
 
# Récupération du mms_id
# ##########################################################
sub bib_data {
	my ($twig, $bib_data)= @_;
	$mms_id = $bib_data->first_child("mms_id")->text();
}
