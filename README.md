# README #

Scripts for loading Metadata into Chado.


To load genome metadata:
  - files to load are in data/<genome>/
  - can be loaded directly from .xls file or from exported text files
  
  1. execute SQL in genome_prep.sql
  
  2. load ontologies:
       GenBank.obo, genome_metadata_structure.obo, MIxS_plant_metadata.obo
     put these in /usr/local/www/drupal7/files/obo/GenBank.obo (or prefered
     location). Tell Tripal cv load the files are in files/obo/<filename>,
     with no leading /.
       
  3. Load the data with LoadGenomeMetadata.pl
       Example:
         $ perl LoadGenomeMetadata.pl -t data/AraduMetadata/
       
