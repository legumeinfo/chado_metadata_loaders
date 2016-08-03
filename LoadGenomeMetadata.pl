# file: LoadGenomeMetadata.pl
#
# purpose: load spreadsheets based on GenBank_genome_submission.xlsx template.
#
# TODOs:
#   - set a master project via an option that provides the master project name.
#
# history:
#  02/13/16  eksc  created
#  02/19/16  eksc  modified for completely revised data collection template

use strict;
use Carp;
use DBI;
use Spreadsheet::ParseXLSX;
use Encode;
use File::Basename;
use Getopt::Std;
use Data::Dumper;

# load local lib library
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use lib dirname(rel2abs($0));
use metadata_lib;

my $warn = <<EOS
  Usage:
    $0 [opts] input-file/dir
      -x load from one Excel spreadsheet [default]
      -t load from directory containing tabular files
EOS
;

  # Get options
  my $load_excel = 1;
  my $load_tab = 0;
  my %cmd_opts = ();
  getopts("xt", \%cmd_opts);
  if (defined($cmd_opts{'x'})) {$load_excel = 1; $load_tab = 0;}
  if (defined($cmd_opts{'t'})) {$load_excel = 0; $load_tab = 1;}
  
  my $input = $ARGV[0];
  die $warn if (!$input);

  # these are the possible worksheets/file prefixes
  my @worksheet_names = ('BioProject', 'Project_extended', 'BioSample', 
                         'Sample_extended', 'WGS', 'Assembly', 'Assembly_stats', 
                         'Annotation');

  my $data;
  if ($load_excel) {
    $data = readSpreadsheet($input);
  }
  else {
    $data = readTableFiles($input);
  }
  
  require('dbconnect.pl');
  my $connect_str = &getConnectString; # (defined in dbconnect.pl)
  print "\nUsing this database connection: [$connect_str]. Continue? (y/n) ";
  my $resp = <STDIN>;
  chomp $resp;
  if ($resp ne 'y') {
    print "\nQuitting.\n\n";
    exit;
  }

  # Get connected to db
  my $dbh = &connectToDB;
  if (!$dbh) {
    print "\nUnable to connect to database.\n\n";
    exit;
  }
  else {
    my $sth = $dbh->prepare('SET SEARCH_PATH=chado');
    $sth->execute();
  }

  # An unpleasant hack because some stock information is in BioProject, but
  #   need the title from the source_mat_derived_id field from Project_extended
  #   to create the stock record.
  my %stock_info;
  
  eval {
    # Project information covers the project itself and the subject
    my $project_id = loadBioProjectData($data, \%stock_info, $dbh);
print "project_id: $project_id\n";
    my $stock_id = loadExtendedProjectData($data, $project_id, \%stock_info, $dbh);
print "stock_id: $stock_id\n";
    
    # Sample information describes the actual material that was sequence
    my $nd_experiment_id = loadBioSampleData($data, $project_id, $stock_id, $dbh);
print "nd_experiment_id: $nd_experiment_id\n";
    loadExtendedSampleData($data, $project_id, $stock_id, $nd_experiment_id, $dbh);
    
    # Assembly information describes the assembly process and outcome
    my $analysis_id = loadWGSData($data, $project_id, $stock_id, $nd_experiment_id, $dbh);
print "analysis_id: $analysis_id\n";
    loadAssemblyData($data, $project_id, $stock_id, $nd_experiment_id, $analysis_id, $dbh);
    loadAssemblyStatsData($data, $analysis_id, $dbh);
  
    # commit if we get this far
    $dbh->commit;
    $dbh->disconnect();
  };
  if ($@) {
    print "\n\nTransaction aborted because $@\n\n";
    # now rollback to undo the incomplete changes
    # but do it in an eval{} as it may also fail
    eval { $dbh->rollback };
  }

  
  
################################################################################
################################################################################

sub loadBioProjectData {
  my ($data, $stock_inforef, $dbh) = @_;
  
  my $project_id;

  my $dataset = $data->{'BioProject'};
  my @header = keys(%{$dataset->[0]});

  if (dataVerified('BioProject', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading BioProject data...\n";
    # NOTE: although looping over rows, not set up for multiple BioProjects per 
    #       spreadsheet.
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      $project_id = loadBioProject($dataset->[$row], $stock_inforef, $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }

  return $project_id;
}#loadBioProjectData


sub loadExtendedProjectData {
  my ($data, $project_id, $stock_inforef, $dbh) = @_;
  
  my $stock_id;

  my $dataset = $data->{'Project_extended'};
  my @header = keys(%{$dataset->[0]});

  if (dataVerified('Project_extended', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading Project_extended data...\n";
    # NOTE: although looping over rows, not set up for multiple Project_extended  
    #       records per spreadsheet.
print "\n\nAll rows:\n" . Dumper($dataset);
    for (my $row=0; $row<(scalar @$dataset); $row++) {
print "\n\nWork on this row:\n" . Dumper($dataset->[$row]);
      $stock_id = loadExtendedProject($project_id, $dataset->[$row], $stock_inforef, $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }

  return $stock_id;
}#loadExtendedProjectData


sub loadBioSampleData {
  my ($oBook, $project_id, $stock_id, $dbh) = @_;

  my $nd_experiment_id;
  
  my $dataset = $data->{'BioSample'};
  my @header = keys(%{$dataset->[0]});

  if (dataVerified('BioSample', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading BioSample data...\n";
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      $nd_experiment_id = loadBioSample($project_id, $stock_id, $dataset->[$row], $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }

  return $nd_experiment_id;
}#loadBioSampleData


sub loadExtendedSampleData {
  my ($data, $project_id, $stock_id, $nd_experiment_id, $dbh) = @_;
  
  my $stock_id;

  my $dataset = $data->{'Sample_extended'};
  my @header = keys(%{$dataset->[0]});
  
  if (dataVerified('Subject', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading Sample_extended data...\n";
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      loadExtendedSample($project_id, $stock_id, $nd_experiment_id, $dataset->[$row], $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }
}#loadExtendedSampleData


sub loadAssemblyData {
  my ($data, $project_id, $stock_id, $nd_experiment_id, $analysis_id, $dbh) = @_;
  
  my $dataset = $data->{'Assembly'};
  my @header = keys(%{$dataset->[0]});
print "Assembly headers:\n" . Dumper(@header);
print "Assembly data:\n" . Dumper($dataset );
  
  if (dataVerified('Assembly', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading data...\n";
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      $analysis_id = loadAssembly($project_id, $stock_id, $nd_experiment_id, $analysis_id, $dataset->[$row], $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }

  return $analysis_id;
}#loadAssemblyData


sub loadAssemblyStatsData {
  my ($data, $analysis_id, $dbh) = @_;
  
  my $dataset = $data->{'Assembly_stats'};
  my @header = keys(%{$dataset->[0]});

  if (dataVerified('Assembly_stats', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading data...\n";
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      loadAssemblyStats($analysis_id, $dataset->[$row], $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }
}#loadAssemblyStatsData


sub loadWGSData {
  my ($data, $project_id, $stock_id, $nd_experiment_id, $dbh) = @_;
  
  my $analysis_id;
  
  my $dataset = $data->{'Sample_extended'};
  my @header = keys(%{$dataset->[0]});
    
  if (dataVerified('WGS', \@header, $dataset, $dbh)) {
    my $row_count = 0;
    print "\nLoading WGS data...\n";
    for (my $row=0; $row<(scalar @$dataset); $row++) {
      $analysis_id = loadWGS($project_id, $nd_experiment_id, $stock_id, $dataset->[$row], $dbh);
      $row_count++;
    }#each row
    print "  loaded $row_count rows.\n";
  }

  return $analysis_id;
}#loadWGSData



################################################################################
#                             supporting functions                             #
################################################################################

sub decodeSourceMatId {
  my $source_mat_id = $_[0];
  my ($accession, $source);
print "decode [$source_mat_id]\n";
  
  if ($source_mat_id =~ /acc:(.*?);/) {
    $accession = $1;
print "found accession: [$accession]\n";
  }
  if ($source_mat_id =~ /source:(.*?);/) {
    $source = $1;
print "found source: [$source]\n";
  }
  
  if (!$accession && !$source) {
    print "ERROR: unable to decode source_mat_id. \n";
    print "       Format should be 'acc:<accession>;source:<source>;'\n";
    print "       But was '$source_mat_id'\n";
    exit;
  }
  
  return ($accession, $source);
}#decodeSourceMatId


sub getAllSpreadsheetRows {
  my $worksheet = @_[0];
  my ($row_min, $row_max) = $worksheet->row_range();
  
  return ($row_min..$row_max);
}#getAllSpreadsheetRows


sub isNull {
  my $value = $_[0];
  return (!$value || uc($value) eq 'NULL');
}#isNull


sub loadAnalysis {
  my ($dbh) = @_;
print "loadAnalysis is not yet implemented.\n";
exit;
  # NOTE: a property of type 'analysis_visibility' must be attached and have
  #       the value 'show'
  # NOTE: a property of type 'analysis_type' and value 'gene model functional 
  #       annotation' must be attached.
}#loadAnalysis


sub loadAssembly {
  my ($project_id, $stock_id, $nd_experiment_id, $analysis_id, $data_rowref, $dbh) = @_;
print Dumper($data_rowref);

  updateAnalysisMethod($analysis_id, $data_rowref->{'seq_meth'}, 'n/a', $dbh);

  createAnalysisProp($analysis_id, $data_rowref->{'seq_service_provider'}, 'seq_service_provider', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'nucl_acid_ext'}, 'nucl_acid_ext', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'nucl_acid_amp'}, 'nucl_acid_amp', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'library_ID'}, 'library_ID', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'library_type'}, 'library_type', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'lib_size'}, 'lib_size', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'lib_reads_seqd'}, 'lib_reads_seqd', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'lib_const_meth'}, 'lib_const_meth', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'lib_vector'}, 'lib_vector', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'lib_screen'}, 'lib_screen', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'mid', 'mid'}, $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'adapters'}, 'adapters', $dbh);  
  createAnalysisProp($analysis_id, $data_rowref->{'pcr_cond'}, 'pcr_cond', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'seq_hardware'}, 'seq_hardware', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'seq_chemistry'}, 'seq_chemistry', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'seq_chemistry_version'}, 'seq_chemistry_version', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'seq_quality_check'}, 'seq_quality_check', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'chimera_check'}, 'chimera_check', $dbh);
print "Loading finishing_strategy: [" . $data_rowref->{'finishing_strategy'} . "]\n";
  createAnalysisProp($analysis_id, $data_rowref->{'finishing_strategy'}, 'finishing_strategy', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'genome_alignment'}, 'genome_alignment', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'release_date'}, 'release_date', $dbh);
}#loadAssembly


sub loadAssemblyStats {
  my ($analysis_id, $data_rowref, $dbh) = @_;
  
  createAnalysisProp($analysis_id, $data_rowref->{'cegs'}, 'cegs', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'perc_genome_organelle_orthologs'}, 'perc_genome_organelle_orthologs', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'aligned_seq_optical'}, 'aligned_seq_optical', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'aligned_seq'}, 'aligned_seq', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'gap_num', 'gap_num'}, $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'assembly_size'}, 'assembly_size', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'scaffold_genome_coverage'}, 'scaffold_genome_coverage', $dbh);
  
  createAnalysisProp($analysis_id, $data_rowref->{'total_gap_length'}, 'total_gap_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'total_psuedomolecule_length'}, 'total_psuedomolecule_length', $dbh); 
#TODO: don't know what this is
#  createAnalysisProp($analysis_id, 'scaffold_coverage', 'scaffold_coverage', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'scaff_num'}, 'scaff_num', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'perc_seq_scaffold'}, 'perc_seq_scaffold', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'perc_seq_unscaffold'}, 'perc_seq_unscaffold', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'total_scaff_length'}, 'total_scaff_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'longest_scaff'}, 'longest_scaff', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'shortest_scaff'}, 'shortest_scaff', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N50_scaff_length'}, 'N50_scaff_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N50_scaff_count'}, 'N50_scaff_count', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N90_scaff_length'}, 'N90_scaff_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N90_scaff_count'}, 'N90_scaff_count', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'mean_scaff_length'}, 'mean_scaff_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'median_scaff_length'}, 'median_scaff_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'scaff_ns', 'scaff_ns'}, $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'contig_num', 'contig_num'}, $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'ave_contigs_per_scaff'}, 'ave_contigs_per_scaff', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'total_contig_length'}, 'total_contig_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'longest_contig'}, 'longest_contig', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'shortest_contig'}, 'shortest_contig', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'mean_contig_length'}, 'mean_contig_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'median_contig_length'}, 'median_contig_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N50_contig_length'}, 'N50_contig_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N50_contig_count'}, 'N50_contig_count', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N90_contig_length'}, 'N90_contig_length', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'N90_contig_count'}, 'N90_contig_count', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'contig_ns'}, 'contig_ns', $dbh);
}#loadAssemblyStats


=cut unused
sub loadExperimentPub {
  my ($experiment_id, $pubstr, $type, $dbh) = @_;
  my ($sql, $sth, $row);
  
  return if (!$pubstr || $pubstr eq '');
  
  # pubstr might be a PMID, DOI or URL
  my $db;
  if ($pubstr =~ /^\d+$/) {
    $db = 'PMID';
  }
  elsif ($pubstr =~ /^doi:/) {
    $db = 'DOI';
  }
  elsif ($pubstr =~ /^http:\/\//) {
    $db = undef;
  }
print "Experiment publicastion is in db [$db]\n";
  
  if (!$db) {
    createExperimentProp($experiment_id, $pubstr, 'ref_biomaterial', $dbh);
  }
  else {
    createExperimentDbxref($experiment_id, $pubstr, $db, $dbh);
  }
}#loadExperimentPub
=cut


sub loadGeoLocation {
  my ($geo_locationstr, $geo_lat, $geo_lon, $geo_alt, $dbh) = @_;
  my ($sql, $row);
  
  my ($geo_lat_clause, $geo_lon_clause, $geo_alt_clause);
  if ((!$geo_locationstr || $geo_locationstr eq '') &&
      (!$geo_lat || $geo_lat eq '') &&
      (!$geo_lon || $geo_lon eq '') &&
      (!$geo_alt || $geo_alt eq '')) {
    return;
  }
  
  my $nd_geolocation_id = createGeoLocation($geo_locationstr, 
                                            $geo_lat, $geo_lon, $geo_alt, $dbh);
  
  return $nd_geolocation_id;
}#loadGeoLocation


sub loadBioProject {
  my ($data_rowref, $stock_inforef, $dbh) = @_;
  my %data_row = %$data_rowref;

#TODO: implement this as an option with master project name
#  my $master_project_id = getProject($data_row{'Genome'}, $dbh);
#  if (!$master_project_id) {
#    my $desc = 'Genome sequencing project.';
#    $master_project_id = createProject($data_row{'Genome'}, $desc, $dbh);
#  }
#  createProjectRelationship($project_id, $master_project_id, 'is_a', $dbh);

  # Create a project record for this genome assembly project
  my $project_id = createProject($data_row{'project_title'}, '', $dbh);
 createProjectProp($project_id, 'Genome assembly', 'project_type', $dbh, 'genbank');
  
  # Project attributes
  createProjectProp($project_id, $data_row{'project_description'}, 'project_description', $dbh, 'SEQmeta');
  createProjectProp($project_id, $data_row{'locus_tag'}, 'annotation_prefix', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'release_date'}, 'release_date', $dbh, 'SEQmeta');
  createProjectProp($project_id, $data_row{'grants'}, 'funding', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'consortium'}, 'consortium', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'consortium_URL'}, 'consortium_URL', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'data_provider'}, 'data_provider', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'data_provider_URL'}, 'data_provider_URL', $dbh, 'genbank');
print "Load submitting information: [".$data_row{'submitting_organization'}."], [".$data_row{'submitting_organization_URL'}."]\n";
  createProjectProp($project_id, $data_row{'submitting_organization'}, 'submitting_organization', $dbh, 'genbank');
  createProjectProp($project_id, $data_row{'submitting_organization_URL'}, 'submitting_organization_URL', $dbh, 'genbank');

  # Handle project publication
  loadProjectPub($project_id, $data_row{'publication_PMID'}, 'PMID', $dbh);
print "Load publication DOI: [" . $data_row{'publication_DOI'} . "]\n";
  loadProjectPub($project_id, $data_row{'publication_DOI'}, 'DOI', $dbh);

  # Database-specific items
  if ($data_row{'MaizeGDB_reference_ID'}) {
    createProjectProp($project_id, $data_row{'MaizeGDB_reference_ID'}, 'mgdb_reference', $dbh, 'maizegdb');
  }
  
  # Collect target information to be saved as a stock record
  $stock_inforef->{'organism_id'}          = getOrganism($data_row{'organism_name'}, $dbh);
print "\nOrganism name: " . $data_row{'organism_name'} . "\n";
  $stock_inforef->{'cultivar'}             = $data_row{'cultivar'};
  $stock_inforef->{'target_description'}   = $data_row{'target_description'};
  $stock_inforef->{'disease'}              = $data_row{'disease'};
  $stock_inforef->{'habitat'}              = $data_row{'habitat'};
  $stock_inforef->{'biomaterial_provider'} = $data_row{'biomaterial_provider'};

  return $project_id;
}#loadBioProject


sub loadBioSample {
  my ($project_id, $stock_id, $data_rowref, $dbh) = @_;
  my %data_row = %$data_rowref;

  # Set the geolocation. 
  #   Note that 'lat' and 'lon' are set from 'lat_lon' in verification code.
  my $geolocation_id = loadGeoLocation($data_rowref->{'geo_location'}, 
                                       $data_rowref->{'lat'}, $data_row{'lon'},
                                       $data_rowref->{'alt_elv'}, $dbh);

  my $nd_experiment_id = createExperiment($project_id, $geolocation_id, 'biosample', $dbh);
  attachExperimentProject($nd_experiment_id, $project_id, $dbh);
  
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_name'},     'sample_name', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_title'},    'sample_title', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_type'},     'sample_type', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_description'}, 'sample_description', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'body_phenotype'},  'body_phenotype', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'collected_by'},    'collected_by', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'collection_date'}, 'collection_date', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'biomaterial_provider'}, 'biomaterial_provider', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'age'},             'age', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'cell_line'},       'cell_line', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'cell_type'},       'cell_type', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'culture_collection'}, 'culture_collection', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'disease'},         'disease', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'disease_stage'},   'disease_stage', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'genotype'},        'genotype', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'growth_protocol'}, 'growth_protocol', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'population'},      'population', $dbh);

  # Extract OBO terms, if any
  my @OBO_terms = extractOBO($data_rowref->{'developmental_stage'});
  foreach my $OBO_term (@OBO_terms) {
    print "Loading OBO terms not tested.\n";
    exit;
    my ($namespace, $accession) = split /:/, $OBO_term;
    my $dbxref_id = getDbXref($accession, $namespace);
    attachExperimentDbXref($nd_experiment_id, $dbxref_id, $dbh);
  }
  # Attach the whole string as a property, OBO terms and all
  createExperimentProp($nd_experiment_id, $data_rowref->{'developmental_stage'}, 'developmental_stage', $dbh);

  # Attach nd_experiment record for the sample to its stock
  attachExperimentStock($nd_experiment_id, $stock_id, $dbh);
  
  return $nd_experiment_id;
}#loadBioSample


sub loadExtendedProject {
  my ($project_id, $data_rowref, $stock_inforef, $dbh) = @_;
  my %data_row = %$data_rowref;

  # Add extended project data
  createProjectProp($project_id, $data_row{'investigation_type'}, 'investigation_type', $dbh);
  createProjectProp($project_id, $data_row{'project_PI'}, 'project_PI', $dbh);
  createProjectProp($project_id, $data_row{'contributors'}, 'contributors', $dbh);
  createProjectProp($project_id, $data_row{'project_start_date'}, 'project_start_date', $dbh);
  createProjectProp($project_id, $data_row{'extrachrom_elements'}, 'extrachrom_elements', $dbh);
  createProjectProp($project_id, $data_row{'estimated_size'}, 'estimated_size', $dbh);
  createProjectProp($project_id, $data_row{'ancestral_data'}, 'ancestral_data', $dbh);
  createProjectProp($project_id, $data_row{'source_mat_id'}, 'source_mat_id', $dbh);
  createProjectProp($project_id, $data_row{'source_mat_derived_id'}, 'source_mat_derived_id', $dbh);
  createProjectProp($project_id, $data_row{'age'}, 'age', $dbh);
  createProjectProp($project_id, $data_row{'height'}, 'height', $dbh);
  createProjectProp($project_id, $data_row{'length'}, 'length', $dbh);
  
  # Database-specific items
  if ($data_row{'MaizeGDB_browser_URL'}) {
    createProjectProp($project_id, $data_row{'MaizeGDB_browser_URL'}, 'MaizeGDB_browser_URL', $dbh, 'maizegdb');
  }
  if ($data_row{'MaizeGDB_reference_ID'}) {
    createProjectProp($project_id, $data_row{'MaizeGDB_reference_ID'}, 'MaizeGDB_reference_ID', $dbh, 'maizegdb');
  }

  createProjectDbxref($project_id, 
                      $data_row{'bioproject_accession'}, 
                      'GenBank:BioProject', $dbh);

  # Find/create stock record to represent subject
  my ($stock_id, $dbxref_id);

  # Is there an accession in the source_mat_id?
  my $dbxref;
  if ($data_rowref->{'source_mat_id'} =~ /(PI\s+\d+)/) {
    my $pi_num = $1;
    $dbxref_id = createDbXref($pi_num, 'PI', $dbh);
  }
  if (!$dbxref_id) { $dbxref_id = 'NULL' };
  
  my $name = ($data_rowref->{'infraspecific_name'} 
                && $data_rowref->{'infraspecific_rank'})
           ? $data_rowref->{'infraspecific_rank'} . ':' . $data_rowref->{'infraspecific_name'}
           : $data_rowref->{'source_mat_id'};
  if ($data_rowref->{'subspecific_genetic_lineage'}) {
    $name .= ' (' . $data_rowref->{'subspecific_genetic_lineage'} . ')';
  }
  
  # Extract information from the source_mat_id field
  my ($stock_name, $source_name) = decodeSourceMatId($data_rowref->{'source_mat_id'});
print "Decoded source_mat_id into '$stock_name', '$source_name'\n";
  
  # Get/create stock record
  $stock_id = createStock($stock_name, $stock_name, 'Accession', 
                          $stock_inforef->{'organism_id'}, $dbxref_id, $dbh);
  # Indicate that this stock has been sampled
  createStockProp($stock_id, '', 'sampled_stock', $dbh, 'genome_metadata_structure');

#TODO: decide what to do with source information

  # Also save source_mat_id as a property (might decide to use a different 
  #   uniquename down the road).
  createStockProp($stock_id, $data_rowref->{'source_mat_id'}, 'source_mat_id', $dbh);
  
  createStockProp($stock_id, $stock_inforef->{'cultivar'},             'infraspecific_name', $dbh);
  createStockProp($stock_id, $stock_inforef->{'target_description'},   'subject_description', $dbh);
  createStockProp($stock_id, $stock_inforef->{'disease'},              'disease', $dbh);
  createStockProp($stock_id, $stock_inforef->{'habitat'},              'habitat', $dbh);
  createStockProp($stock_id, $stock_inforef->{'biomaterial_provider'}, 'biomaterial_provider', $dbh);
  
  # Database-specific items
  if ($data_row{'MaizeGDB_browser_URL'}) {
    createStockProp($stock_id, $data_rowref->{'MaizeGDB_browser_URL'},  'MaizeGDB_browser_URL', $dbh, 'maizegdb');
  }
  if ($data_row{'MaizeGDB_browser_URL'}) {
    createStockProp($stock_id, $data_rowref->{'MaizeGDB_reference_ID'}, 'MaizeGDB_reference_ID', $dbh, 'maizegdb');
  }
  if ($data_row{'MaizeGDB_browser_URL'}) {
    createStockProp($stock_id, $data_rowref->{'MaizeGDB_stock_ID'},     'MaizeGDB_stock_ID', $dbh, 'maizegdb');
  }

  return $stock_id;
}#loadExtendedProject


sub loadExtendedSample {
  my ($project_id, $stock_id, $nd_experiment_id, $data_rowref, $dbh) = @_;
  my %data_row = %$data_rowref;
  
  createExperimentProp($nd_experiment_id, $data_rowref->{'ref_biomaterial'},        'ref_biomaterial', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'body_phenotype'},         'body_phenotype', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_temperature'},     'sample_temperature', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_storage_duration'},'sample_storage_duration', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'sample_storage_location'},'sample_storage_location', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'depth'},                  'depth', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'env_biome'},              'env_biome', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'env_feature'},            'env_feature', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'env_material'},           'env_material', $dbh);
  createExperimentProp($nd_experiment_id, $data_rowref->{'treatment'},              'treatment', $dbh);

  # Handle BioSample accession
  my $dbxref_id = createDbXref($data_rowref->{'biosample_id'}, 'GenBank:BioSample', $dbh);
  attachExperimentDbXref($nd_experiment_id, $dbxref_id, $dbh);
}#loadExtendedSample


sub loadProjectPub {
  my ($project_id, $pubstr, $db, $dbh) = @_;
  
  return if (!$pubstr || $pubstr eq '');
  
  my $dbxref_id = createDbXref($pubstr, $db, $dbh);;
  attachProjectDbXref($project_id, $dbxref_id, $dbh);  
}#loadProjectPub


sub loadWGS {
  my ($project_id, $nd_experiment_id, $stock_id, $data_rowref, $dbh) = @_;
  my %data_row = %$data_rowref;

  my $analysis_id;

  my $analysis_id = createAnalysis($data_rowref->{'assembly_name'},
                                   $data_rowref->{'assembly'},
                                   '', '', $dbh);
  createAnalysisProp($analysis_id, 'Genome assembly', 'analysis_type', $dbh, 'tripal_analysis');
  createProjectAnalysis($project_id, $analysis_id, $dbh);

  my $dbxref_id = createDbXref($data_rowref->{'BioProject'}, 'GenBank:BioProject', $dbh);
  attachAnalysisDbXref($analysis_id, $dbxref_id, $dbh);

  my $dbxref_id = createDbXref($data_rowref->{'BioSample'}, 'GenBank:BioSample', $dbh);
  attachAnalysisDbXref($analysis_id, $dbxref_id, $dbh);
  
  createAnalysisProp($analysis_id, $data_rowref->{'Assembly_date'},    'assembly_date', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'Assembly_methods'}, 'assembly_methods', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'Assembly_name'},    'assembly_name', $dbh);
  createAnalysisProp($analysis_id, $data_rowref->{'genome_coverage'},  'genome_coverage', $dbh, 'genbank');
  
  return $analysis_id;
}#loadWGS


sub openSpreadsheet {
  my ($spreadsheet) = @_;
  
  if (!(-e $spreadsheet)) {
    print "\nERROR: Unable to open spreadsheet ($spreadsheet)$warn\n\n";
    return 0;
  }
  
  # Open spreadsheet
  my $parser = Spreadsheet::ParseXLSX->new;
  print "Open $spreadsheet...\n";
  my $workbook = $parser->parse($spreadsheet);
  print "    ...done\n";
  if (!defined $workbook) {
    die $parser->error(), ".\n";
  }
  
  return $workbook;
}#openSpreadsheet


sub readSpreadsheet {
  my ($spreadsheet, $dbh) = @_;
  
  my @data;

  my $workbook = openSpreadsheet($spreadsheet);
  if (!$workbook) {
    return 0;
  }
  
  my %data;
  foreach my $worksheet_name (@worksheet_names) {
    my $worksheet = $workbook->worksheet($worksheet_name);
    next if (!$worksheet);
  
    my @data_rows;
    my @rows = getAllSpreadsheetRows($worksheet);
    my @headers;
    my $cell;
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    foreach my $row ($row_min .. $row_max) {
      my %data_row;
      my $check_cell = $worksheet->get_cell($rows[$row], 0);
      next if ($check_cell && $check_cell->value() =~ /^#/);
      
      if (!@headers) {
        for my $col ($col_min .. $col_max) {
          $cell = $worksheet->get_cell($rows[$row], $col);
          if ($cell && $cell->value() ne '') {
            my $header = $cell->value();
            $header =~ s/\*//;
            push @headers, $header;
          }
        }
        $col_max = scalar @headers;
      }#get column names
    
      else {
        my $empty_row = 1;
        for my $col ($col_min .. $col_max) {
          if ($cell = $worksheet->get_cell($rows[$row], $col)) {
            if ($cell->value() ne '') {
              $empty_row = 0;
            }
            
#TODO: all verification functions here
  
            # put the value in a hash for later use
            $data_row{$headers[$col]} = $cell->value();
          }
        }#each column
        
        if (!$empty_row) {
          push @data_rows, {%data_row};
        }
      }#process one row
    }#each row
    
    $data{$worksheet_name} = [@data_rows];
  }#each worksheet
  
  return \%data;
}#readSpreadsheet


sub readTableFiles {
  my $input = $_[0];
  
  my %data;
  
  foreach my $worksheet_name (@worksheet_names) {
    my $file = "$input/$worksheet_name.txt";
    my @rows;
    my @heads;
    if (!(-e $file)) {
      print "File $file not found. Skipping.\n";
      next;
    }
    
    open IN, "<$file" or die "\nUnable to open $file: $1\n\n";
    my $count = 1;
    while (<IN>) {
      my %data_row;
      
      next if (/^#/);
      chomp;chomp;
      
      if (!@heads) {
        @heads = readTableHeads($_);
      }
      else {
        my @fields = split /\t/;
        next if ((scalar @fields) == 0);
# Unsure how to handle this as often this is okay
#        if ((scalar @fields) < (scalar @heads)) {
#          print "WARNING: Row $count of $file has too few fields. Skipping. \n";
#          next;
#        }
        
        for (my $i=0; $i<(scalar @heads); $i++) {
          if ($fields[$i] ne '' && $fields[$i] ne 'NULL') {
            $data_row{$heads[$i]} = $fields[$i];
          }
        }
      }#read columns
      
      if ((scalar keys %data_row) > 0) {
        push @rows, {%data_row};
      }
      
      $count++;
    }#each line
    close IN;
    
    $data{$worksheet_name} = [@rows];
  }#each file
  

  return \%data;
}#readTableFiles


sub readTableHeads {
  my $row = $_[0];
  if ($row) {
    chomp;chomp;
    my @heads = split /\t/, $row;
    for (my $i=0;$i<=$#heads; $i++) {
       $heads[$i] =~ s/\*//;
    }
    return @heads;
  }
  else {
    return undef;
  }
}#readTableHeads


sub verifyRow {
  my ($worksheet, $row, $rows_ref, $dbh) = @_;
  my ($msg);
  
  my $verified = 1;
  
  ###### Check BioProject worksheet #####
  if ($worksheet eq 'BioProject') {
    if ($rows_ref->[$row]->{'publication_PMID'} 
          && $rows_ref->[$row]->{'publication_DOI'}) {
      print "ERROR: $row: Provide either the PMID or the DOI for the publication, not both.\n";
      $verified = 0;
    }#check publication_PMID
    
    # warn if project already loaded
    if (getProject($rows_ref->[$row]->{'project_title'})) {
      $msg = "WARRNING: $row: the BioProject " 
           . $rows_ref->[$row]->{'project_title'} 
           . " has already been loaded. Do you want to update?";
      exit if (promptUser($msg) ne 'y');
    }
    
    # warn if it looks like there should be master project
#TODO: check for existence of option too
    if ($rows_ref->[$row]->{'part_of_a_larger_initiative'}
          && lc($rows_ref->[$row]->{'part_of_a_larger_initiative'}) =~ /^y[es]/) {
      $msg = "WARNING: $row: this BioProject may need to be linked to a master "
           . "project. If so, provide its name using the XXX option.\n"
           . "Continue with this load anyway? ";
      exit if (promptUser($msg) ne 'y');
    }
  }#BioProject worksheet
  
  
  ###### Check Project_extended worksheet #####
  elsif ($worksheet eq 'Project_extended') {
    if (!getProject($rows_ref->[$row]->{'project_title'}, $dbh)) {
      $msg = "The project '" . $rows_ref->[$row]->{'project_title'} 
           . " does not exist. Make sure the value in the 'project_title'"
           . " column matches the 'project_title' column in the BioProject"
           . " worksheet";
      print "ERROR: $row: $msg\n";
      $verified = 0;
    }#check project title
    
    if ($rows_ref->[$row]->{'MaizeGDB_reference_ID'}) {
      if (!getMGDBReference($rows_ref->[$row]->{'MaizeGDB_reference_ID'}, $dbh)) {
        print "ERROR: $row: The MaizeGDB reference " . $rows_ref->[$row]->{'MaizeGDB_reference_ID'} . " does not exist.\n";
        $verified = 0;
      }
    }#check MaizeGDB_reference_ID
  }#BioProject worksheet
  
  
  ###### Check BioSample worksheet #####
  elsif ($worksheet eq 'BioSample') {
    if (my $lat_lon = uc($rows_ref->[$row]->{'lat_lon'})) {
      if ($lat_lon ne '') {
        if ($lat_lon =~ /(\d+[\.\d+]*)\s*([NS])\D*(\d+[\.\d+]*)\s*([E|W])/) {
          print "okay\n";
          $rows_ref->[$row]->{'lat'} = ($2 eq 'N') ? $1 : -$1;
          $rows_ref->[$row]->{'lon'} = ($4 eq 'E') ? $3 : -$3;
        }
        else {
          print "ERROR: $row: Incorrect lat-lon format. [$lat_lon] should be <float>{N|S}, <float>[E|W]\n";
          $verified = 0;
        }
      }
    }#check lat_lon

    if ((!$rows_ref->[$row]->{'geo_location'} || $rows_ref->[$row]->{'geo_location'} eq '')
          && (!$rows_ref->[$row]->{'lat_lon'} || $rows_ref->[$row]->{'lat_lon'} eq '')) {
      print "ERROR: $row: a location where sample was grown is required. ";
      print "Please enter a value for 'geo_location' and/or 'lat_lon' on the ";
      print "BioSample worksheet.\n";
      $verified = 0;
    }
    
    if (my $pubstr = $rows_ref->[$row]->{'ref_biomaterial'}) {
      if (!($pubstr =~ /^\d+$/) && !($pubstr =~ /^doi:/) 
        && !($pubstr =~ /^http:\/\//)) {
        print "ERROR: $row: Incorrect format for ref_biomaterial [$pubstr]. Must be a PMID, DOI, or URL.\n";
        $verified = 0;
      }
    }#check ref_biomaterial
  }#Sample worksheet
  
  ###### Check Subject worksheet #####
  elsif ($worksheet eq 'Subject') {
    if (!getOrganism($rows_ref->[$row]->{'common_name'}, $dbh)) {
      print "ERROR: $row: No record for the organism, " . $rows_ref->[$row]->{'common_name'} . ".\n";
      $verified = 0;
    }
  }
  
  return $verified;
}#verifyRow



