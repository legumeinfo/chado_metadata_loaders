# Chado metadata scripts #

Scripts, data mappings and files, and ontologies for loading metadata into Chado.

*data/* contains files that have been loaded <br>
*obo/* contains ontologies need to support data mapping and describing metadata fields <br>
*schema/* contains information about the data mapping. 
**The data mapping diagram comes from MaizeGDB and is only approximate for the LIS genome metadata.**


**To load genome metadata:**
  - files to load are in data/\<genome\>/
  - can be loaded directly from .xls file or from exported text files
  
  1. execute SQL in genome_prep.sql
  
  2. load ontologies:
       GenBank.obo, genome_metadata_structure.obo, MIxS_plant_metadata.obo
     put these in /usr/local/www/drupal7/files/obo/GenBank.obo (or prefered
     location). Tell Tripal cv load the files are in files/obo/\<filename\>,
     with no leading /.
       
  3. Use the script `dumpSpreadsheet.pl` in the QTL loading scripts (legumeinfo/scripts-qtlloader) to dump 
     the contents of the spreadsheet into text files. Example: <br>
       `$ perl dumpSpreadsheet.pl data/ArahyTifrunnerMetadata.xlsx data/ArahyTifrunnerMetadata`

  3. Load the data with LoadGenomeMetadata.pl
       Example:<br>
         `$ perl LoadGenomeMetadata.pl -t data/AraduMetadata/`
       
