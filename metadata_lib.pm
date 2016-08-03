# file: metadata_lib.pm
#
# purpose: common functions used by multiple metadata scripts.
#
# history:
#  02/15/16  eksc  created

use strict;
use base 'Exporter';
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

package metadata_lib;

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = (
                    qw(attachAnalysisAnalysis),
                    qw(attachAnalysisDbXref),
                    qw(attachExperimentDbXref),
                    qw(attachExperimentProject),
                    qw(attachExperimentStock),
                    qw(attachProjectDbXref),
                    qw(createAnalysis),
                    qw(createAnalysisProp),
                    qw(createAnalysisPub),
                    qw(createDbXref),
                    qw(createExperiment),
                    qw(createExperimentDbxref),
                    qw(createExperimentProp),
                    qw(createGeoLocation),
                    qw(createProject),
                    qw(createProjectAnalysis),
                    qw(createProjectDbxref),
                    qw(createProjectProp),
                    qw(createProjectRelationship),
                    qw(createStock),
                    qw(createStockProp),
                    qw(dataVerified),
                    qw(doQuery),
                    qw(extractOBO),
                    qw(getAnalysis),
                    qw(getDbXref),
                    qw(getOrganism),
                    qw(getProject),
                    qw(getMGDBStock),
                    qw(getProject),
                    qw(getMGDBReference),
                    qw(openExcelFile),
                    qw(promptUser),
                    qw(readWorksheet),
                    qw(updateAnalysisMethod),
                   );


sub attachAnalysisAnalysis {
  my ($subject_id, $object_id, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "
    SELECT * FROM analysis_relationship
    WHERE subject_id=$subject_id AND object_id=$object_id";
  if (!(my $row = doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO analysis_relationship
        (subject_id, object_id, type_id)
      VALUES
        ($subject_id, $object_id, 
         (SELECT cvterm_id FROM cvterm 
          WHERE name='derives_from'
                AND cv_id=(SELECT cv_id FROM cv
                           WHERE name= 'relationship'))
        )";
    doQuery($sql, 0, $dbh);
  }
}#attachAnalysisAnalysis



sub attachAnalysisDbXref {
  my ($analysis_id, $dbxref_id, $dbh) = @_;
  my ($sql, $row);

  $sql = "
    SELECT * FROM analysis_dbxref 
    WHERE analysis_id=$analysis_id AND dbxref_id=$dbxref_id";
  if (!($row = doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO analysis_dbxref
        (analysis_id, dbxref_id)
      VALUES
        ($analysis_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#attachAnalysisDbXref


sub attachExperimentDbXref {
  my ($nd_experiment_id, $dbxref_id, $dbh) = @_;
  my ($sql, $row);

  $sql = "
    SELECT * FROM nd_experiment_dbxref 
    WHERE nd_experiment_id=$nd_experiment_id AND dbxref_id=$dbxref_id";
  if (!($row = doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO nd_experiment_dbxref
        (nd_experiment_id, dbxref_id)
      VALUES
        ($nd_experiment_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#attachExperimentDbXref


sub attachExperimentProject {
  my ($nd_experiment_id, $project_id, $dbh) = @_;
  my ($sql, $row);
  
  # Attach to the project
  $sql = "
    SELECT * FROM nd_experiment_project 
    WHERE nd_experiment_id=$nd_experiment_id AND project_id=$project_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO nd_experiment_project
        (nd_experiment_id, project_id)
      VALUES
        ($nd_experiment_id, $project_id)";
    doQuery($sql, 0, $dbh);
  }
}#attachExperimentProject


sub attachExperimentStock {
  my ($nd_experiment_id, $stock_id, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "
    SELECT * FROM nd_experiment_stock
    WHERE nd_experiment_id=$nd_experiment_id AND stock_id=$stock_id
          AND type_id=(SELECT cvterm_id FROM cvterm
                       WHERE name='sampled_stock'
                             AND cv_id=(SELECT cv_id FROM cv 
                                        WHERE name='genome_metadata_structure'))";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO nd_experiment_stock
        (nd_experiment_id, stock_id, type_id)
      VALUES
        ($nd_experiment_id, $stock_id,
         (SELECT cvterm_id FROM cvterm
          WHERE name='sampled_stock'
                AND cv_id=(SELECT cv_id FROM cv WHERE name='genome_metadata_structure'))
        )";
    doQuery($sql, 0, $dbh);
  }
}#attachExperimentStock


sub attachProjectDbXref {
  my ($project_id, $dbxref_id, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "
    SELECT project_dbxref_id FROM project_dbxref
    WHERE project_id=$project_id AND dbxref_id=$dbxref_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO project_dbxref
        (project_id, dbxref_id)
      VALUES
        ($project_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#attachProjectDbXref


sub createAnalysis {
  my ($analysis_name, $description, $method, $version, $dbh) = @_;
  my ($sql, $row);
print "create analysis record with $dbh\n";
  
  my $analysis_id;
  
  $sql = "
    SELECT analysis_id FROM analysis
    WHERE name='$analysis_name'";
  if ($row=doQuery($sql, 1, $dbh)) {
    $analysis_id = $row->{'analysis_id'};
    $sql = "
      UPDATE analysis
        SET description='$description'
      WHERE analysis_id=$analysis_id";
    doQuery($sql, 0, $dbh);
  }
  else {
    $sql = "
      INSERT INTO analysis
        (name, description, program, programversion)
      VALUES
        ('$analysis_name', '$description', '$method', '$version')
      RETURNING analysis_id";
    $row = doQuery($sql, 1, $dbh);
    $analysis_id = $row->{'analysis_id'};
  }
  
  return $analysis_id;
}#createAnalysis


sub createAnalysisProp {
  my ($analysis_id, $value, $type, $dbh, $cv) = @_;
  my ($sql, $row);
  
  return if (!$value || $value eq '');
  
  if (!$cv) { $cv = 'SEQmeta'; }

  my $analysisprop_id;
  $sql = "
    SELECT analysisprop_id FROM analysisprop
    WHERE analysis_id=$analysis_id
          AND type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='$type'
                             AND cv_id=(SELECT cv_id FROM cv
                                        WHERE name='$cv'))";
  if ($row=doQuery($sql, 1, $dbh)) {
    $sql = "
      UPDATE analysisprop
        SET value='$value'
      WHERE analysisprop_id=" . $row->{'analysisprop_id'};
  } 
  else {
    $sql = "
      INSERT INTO analysisprop
        (analysis_id, value, type_id)
      VALUES
        ($analysis_id, '$value', 
         (SELECT cvterm_id FROM cvterm 
                         WHERE name='$type'
                               AND cv_id=(SELECT cv_id FROM cv
                                          WHERE name='$cv'))
        )";
  }
  
  doQuery($sql, 0, $dbh);
}#createAnalysisProp


sub createAnalysisPub {
  my ($analysis_id, $pubstr, $db, $dbh) = @_;
  my ($sql, $row);
  
  return if (!$pubstr || $pubstr eq '');
  
  my $dbxref_id;
  $sql = "
    SELECT dbxref_id FROM dbxref
    WHERE accession = '$pubstr'
          AND db_id=(SELECT db_id FROM db WHERE name='$db')";
  if ($row=doQuery($sql, 1, $dbh)) {
    $dbxref_id = $row->{'dbxref_id'};
  }
  else {
    $sql = "
      INSERT INTO dbxref
        (accession, db_id)
      VALUES
        ('$pubstr',
         (SELECT db_id FROM db WHERE name='$db')
        )
      RETURNING dbxref_id";  
    $row = doQuery($sql, 1, $dbh);
    $dbxref_id = $row->{'dbxref_id'};
  }
  
  $sql = "
    SELECT analysis_dbxref_id FROM analysis_dbxref
    WHERE analysis_id=$analysis_id AND dbxref_id=$dbxref_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO analysis_dbxref
        (analysis_id, dbxref_id)
      VALUES
        ($analysis_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#createAnalysisPub

sub createDbXref {
  my ($accession, $dbname, $dbh) = @_;
  my ($sql, $row);
  
  my $dbxref_id;
  
  $sql = "
      SELECT dbxref_id FROM dbxref
      WHERE accession='$accession' 
            AND db_id=(SELECT db_id FROM db WHERE name='$dbname')";
  if ($row=doQuery($sql, 1, $dbh)) {
    $dbxref_id = $row->{'dbxref_id'};
  }
  else {
    $sql = "
      INSERT INTO dbxref
        (accession, db_id)
      VALUES
        ('$accession',
         (SELECT db_id FROM db WHERE name='$dbname'))
      RETURNING dbxref_id";
    $row = doQuery($sql, 1, $dbh);
    $dbxref_id = $row->{'dbxref_id'};
  }
  
  return $dbxref_id;
}#createDbXref


sub createExperiment {
  my ($project_id, $geolocation_id, $type, $dbh) = @_;
  my ($sql, $row);

  my $nd_experiment_id;
  
  # create experiment record
  $sql = "
    SELECT e.nd_experiment_id FROM nd_experiment e
      INNER JOIN nd_experiment_project ep ON ep.nd_experiment_id=e.nd_experiment_id
    WHERE nd_geolocation_id = $geolocation_id
          AND ep.project_id=$project_id
          AND type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='$type'
                             AND cv_id=(SELECT cv_id FROM cv 
                                        WHERE name='genome_metadata_structure'))";
  if ($row=doQuery($sql, 1, $dbh)) {
    $nd_experiment_id = $row->{'nd_experiment_id'};
  }
  else {
    $sql = "
      INSERT INTO nd_experiment
        (nd_geolocation_id, type_id)
      VALUES
        ($geolocation_id, 
         (SELECT cvterm_id FROM cvterm 
          WHERE name='$type'
                AND cv_id=(SELECT cv_id FROM cv WHERE name='genome_metadata_structure'))
        )
      RETURNING nd_experiment_id";
    $row = doQuery($sql, 1, $dbh);
    $nd_experiment_id = $row->{'nd_experiment_id'};
  }
  
  return $nd_experiment_id;
}#createExperiment


sub createExperimentDbxref {
  my ($nd_experiment_id, $accession, $db, $dbh) = @_;
  my ($sql, $row);
  
  # create dbxref record
  my $dbxref_id;
  $sql = "
    SELECT dbxref_id FROM dbxref
    WHERE accession='$accession'
          AND db_id=(SELECT db_id FROM db
                     WHERE name='$db')";
  if ($row=doQuery($sql, 1, $dbh)) {
    $dbxref_id = $row->{'dbxref_id'};
  }
  else {
    $sql = "
      INSERT INTO dbxref
        (accession, db_id)
      VALUES
        ('$accession',
         (SELECT db_id FROM db WHERE name='$db')
        )
      RETURNING dbxref_id";
    $row = doQuery($sql, 1, $dbh);
    $dbxref_id = $row->{'dbxref_id'};
  }
  
  $sql = "
    SELECT * FROM nd_experiment_dbxref
    WHERE nd_experiment_id=$nd_experiment_id AND dbxref_id=$dbxref_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO nd_experiment_dbxref
        (nd_experiment_id, dbxref_id)
      VALUES
        ($nd_experiment_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#createExperimentDbxref


sub createExperimentProp {
  my ($nd_experiment_id, $value, $type, $dbh, $cv) = @_;
  my ($sql, $row);
  
  return if (!$value || $value eq '');
  
  if (!$cv) { $cv = 'SEQmeta'; }

  $sql = "
    SELECT nd_experimentprop_id FROM nd_experimentprop
    WHERE nd_experiment_id=$nd_experiment_id
          AND type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='$type'
                             AND cv_id=(SELECT cv_id FROM cv
                                        WHERE name='$cv'))";
  if ($row=doQuery($sql, 1, $dbh)) {
    my $nd_experimentprop_id = $row->{'nd_experimentprop_id'};
  
    $sql = "
      UPDATE nd_experimentprop
        SET value='$value'
      WHERE nd_experimentprop_id=$nd_experimentprop_id";
  }
  else {
    $sql = "
      INSERT INTO nd_experimentprop
        (nd_experiment_id, value, type_id)
      VALUES
        ($nd_experiment_id, '$value', 
         (SELECT cvterm_id FROM cvterm 
                         WHERE name='$type'
                               AND cv_id=(SELECT cv_id FROM cv
                                          WHERE name='$cv'))
        )";
  }

  doQuery($sql, 0, $dbh);
}#createExperimentProp


sub createGeoLocation  {
  my ($geo_locationstr, $geo_lat, $geo_lon, $geo_alt, $dbh) = @_;
  my ($sql, $row);
  
  my $nd_geolocation_id;
  
  my $geo_lat_clause = (!$geo_lat || $geo_lat eq '') ? 'IS NULL' : "='$geo_lat'";
  my $geo_lon_clause = (!$geo_lon || $geo_lon eq '') ? 'IS NULL' : "='$geo_lon'";
  my $geo_alt_clause = (!$geo_alt || $geo_alt eq '') ? 'IS NULL' : "='$geo_alt'";
  
  $sql = "
    SELECT nd_geolocation_id FROM nd_geolocation 
    WHERE description='$geo_locationstr' 
          AND latitude $geo_lat_clause AND longitude $geo_lon_clause 
          AND altitude $geo_alt_clause";
  if ($row=doQuery($sql, 1, $dbh)) {
    $nd_geolocation_id = $row->{'nd_geolocation_id'};
  }
  else {
    my $geo_lat = (!$geo_lat || $geo_lat eq '') ? 'NULL' : $geo_lat;
    my $geo_lon = (!$geo_lon || $geo_lon eq '') ? 'NULL' : $geo_lon;
    my $geo_alt = (!$geo_alt || $geo_alt eq '') ? 'NULL' : $geo_alt;
    $sql = "
      INSERT INTO nd_geolocation
        (description, latitude, longitude, altitude)
      VALUES
        ('$geo_locationstr', $geo_lat, $geo_lon, $geo_alt)
      RETURNING nd_geolocation_id";
    $row = doQuery($sql, 1, $dbh);
    $nd_geolocation_id = $row->{'nd_geolocation_id'};
  }
  
  return $nd_geolocation_id;
}#createGeoLocation


sub createProject {
  my ($name, $desc, $dbh) = @_;
  my ($sql, $row);
  
  my $project_id;
  $sql = "
    SELECT project_id FROM project
    WHERE name='$name'";
  $row = doQuery($sql, 1, $dbh);
  if ($row) {
    $project_id = $row->{'project_id'};
    $sql = "
      UPDATE project
        SET description='$desc'
      WHERE project_id=$project_id";
    doQuery($sql, 0, $dbh);
  }
  else {
    $sql = "
      INSERT INTO project
        (name, description)
      VALUES
        ('$name', '$desc')
      RETURNING project_id";
    $row = doQuery($sql, 1, $dbh);
    $project_id = $row->{'project_id'};
  }
  
  return $project_id;
}#createProject


sub createProjectAnalysis {
  my ($project_id, $analysis_id, $dbh) = @_;
  my ($sql, $row);

  $sql = "
    SELECT * FROM project_analysis
    WHERE analysis_id = $analysis_id AND project_id = $project_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO project_analysis
        (analysis_id, project_id)
      VALUES
        ($analysis_id, $project_id)";
    doQuery($sql, 0, $dbh);
  }
}#createProjectAnalysis


sub createProjectDbxref {
  my ($project_id, $accession, $db, $dbh) = @_;
  my ($sql, $row);
  
  return if (!$accession || $accession eq '' || !$db || $db eq '');

  # create dbxref record
  my $dbxref_id;
  $sql = "
    SELECT dbxref_id FROM dbxref
    WHERE accession='$accession'
          AND db_id=(SELECT db_id FROM db
                     WHERE name='$db')";
  if ($row=doQuery($sql, 1, $dbh)) {
    $dbxref_id = $row->{'dbxref_id'};
  }
  else {
  $sql = "
      INSERT INTO dbxref
        (accession, db_id)
      VALUES
        ('$accession',
         (SELECT db_id FROM db WHERE name='$db')
        )
      RETURNING dbxref_id";
    $row = doQuery($sql, 1, $dbh);
    $dbxref_id = $row->{'dbxref_id'};
  }
  
  $sql = "
    SELECT * FROM project_dbxref
    WHERE project_id=$project_id AND dbxref_id=$dbxref_id";
  if (!($row=doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO project_dbxref
        (project_id, dbxref_id)
      VALUES
        ($project_id, $dbxref_id)";
    doQuery($sql, 0, $dbh);
  }
}#createProjectDbxref


sub createProjectProp {
  my ($project_id, $value, $type, $dbh, $cv) = @_;
  my ($sql, $row);
  
  if (!$cv) { $cv = 'SEQmeta'; }
  
  return if (!$value || $value eq '');

  $sql = "
    SELECT projectprop_id FROM projectprop
    WHERE project_id=$project_id
          AND type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='$type'
                             AND cv_id=(SELECT cv_id FROM cv
                                        WHERE name='$cv'))";
  if ($row = doQuery($sql, 1, $dbh)) {
    my $projectprop_id = $row->{'projectprop_id'};
  
    $sql = "
      UPDATE projectprop
        SET value='$value'
      WHERE projectprop_id=$projectprop_id";
  }
  else {
    $sql = "
      INSERT INTO projectprop
        (project_id, value, type_id)
      VALUES
        ($project_id, '$value', 
         (SELECT cvterm_id FROM cvterm 
                         WHERE name='$type'
                               AND cv_id=(SELECT cv_id FROM cv
                                          WHERE name='$cv'))
        )";
  }
  
  doQuery($sql, 0, $dbh);
}#createProjectProp


sub createProjectRelationship {
  my ($subject_id, $object_id, $type, $dbh) = @_;
  
  my $sql = "
    SELECT * FROM project_relationship
    WHERE subject_project_id=$subject_id AND object_project_id=$object_id";
  if (!(my $row = doQuery($sql, 1, $dbh))) {
    $sql = "
      INSERT INTO project_relationship
        (subject_project_id, object_project_id, type_id)
      VALUES
        ($subject_id, $object_id, 
         (SELECT cvterm_id FROM cvterm 
          WHERE name='is_a'
                AND cv_id=(SELECT cv_id FROM cv
                           WHERE name= 'relationship'))
        )";
    doQuery($sql, 0, $dbh);
  }
}#createProjectRelationship


sub createStock {
  my ($name, $uniquename, $stock_type, $organism_id, $dbxref_id, $dbh) = @_;
  my ($sql, $row);

  my $stock_id;
  
  # get/create stock record
  $sql = "
    SELECT stock_id FROM stock 
    WHERE organism_id=$organism_id
          AND type_id=(SELECT cvterm_id FROM cvterm
                       WHERE name='$stock_type'
                             AND cv_id=(SELECT cv_id FROM cv WHERE name='stock_type'))
          AND uniquename='$uniquename'";
  if ($row=doQuery($sql, 1, $dbh)) {
    $stock_id = $row->{'stock_id'};
    $sql = "
      UPDATE stock
        SET dbxref_id=$dbxref_id, organism_id=$organism_id, name='$name'
      WHERE stock_id=$stock_id";
    doQuery($sql, 0, $dbh);
  }
  else {
    $sql = "
      INSERT INTO stock
        (dbxref_id, organism_id, name, uniquename, description, type_id) 
      VALUES
        ($dbxref_id, 
         $organism_id, 
         '$name',
         '$uniquename',
         '',
         (SELECT cvterm_id FROM cvterm
          WHERE name='Accession'
                AND cv_id=(SELECT cv_id FROM cv WHERE name='stock_type'))
        )
      RETURNING stock_id";
    $row = doQuery($sql, 1, $dbh);
    $stock_id = $row->{'stock_id'};
  }
  
  return $stock_id;
}#createStock


sub createStockProp {
  my ($stock_id, $value, $type, $dbh, $cv) = @_;
  my ($sql, $row);
  
  return if (!$value || $value eq '');

  if (!$cv) { $cv = 'SEQmeta'; }

  $sql = "
    SELECT stockprop_id FROM stockprop
    WHERE stock_id=$stock_id
          AND type_id=(SELECT cvterm_id FROM cvterm 
                       WHERE name='$type'
                             AND cv_id=(SELECT cv_id FROM cv
                                        WHERE name='$cv'))";
  if ($row=doQuery($sql, 1, $dbh)) {
    my $stockprop_id = $row->{'stockprop_id'};
    $sql = "
      UPDATE stockprop
        SET value='$value'
      WHERE stockprop_id=$stockprop_id";
  }
  else {
    $sql = "
      INSERT INTO stockprop
        (stock_id, value, type_id)
      VALUES
        ($stock_id, '$value', 
         (SELECT cvterm_id FROM cvterm 
                         WHERE name='$type'
                               AND cv_id=(SELECT cv_id FROM cv
                                          WHERE name='$cv'))
        )";
  }
  
  doQuery($sql, 0, $dbh);
}#createStockProp


sub dataVerified {
  my ($worksheet, $header_ref, $rows_ref, $dbh) = @_;
  my @headers = @$header_ref;
  my @rows = @$rows_ref;

  print "\n  Verifying data for $worksheet...\n";
  my $verified = 1;
  
  for (my $row=0; $row<=$#rows; $row++) {
    for (my $col=0; $col<=$#headers; $col++) {
      my $header = @headers[$col];
      $header =~ s/\*//;
      my $value = $rows[$row]->{$header};
      if ($header =~ /^\*/ && (!$value || $value eq '')) {
        print "    ERROR: $row: value missing for required field $header\n";
        $verified = 0;
      }
    }#each header
    
    # Do worksheet-specific verification.
    if (exists &verifyRow) {
      if (!verifyRow($worksheet, $row, $rows_ref, $dbh)) {
        $verified = 0;
      }
    }
  }#each row;
  
  if ($verified) {
    print "    ...success\n";
  }
  
  return $verified;
}#dataVerified


sub doQuery {
  my ($sql, $return_row, $dbh) = @_;
  print "$sql\n";
  my $sth = $dbh->prepare($sql);
  $sth->execute();
  if ($return_row) {
    return $sth->fetchrow_hashref;
  }
  else {
    return $sth;
  }
}#doQuery


sub extractOBO {
  my $str = $_[0];
  
  my @OBO_terms;
  
  # Expect to see terms with the form: <namespace>:<digits>
  while ($str =~ /(\w+:\d+)/g) {
    push @OBO_terms, $1;
  }
  
  return @OBO_terms;
}#extractOBO


sub getAnalysis {
  my ($name, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "SELECT analysis_id FROM analysis WHERE name='$name'";
  if ($row = doQuery($sql, 1, $dbh)) {
    return $row->{'analysis_id'};
  }
  else {
    return undef;
  }
}#getAnalysis


sub getDbXref {
  my ($accession, $db, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "
    SELECT dbxref_id_id FROM dbxref 
    WHERE accession='$accession'
          AND db_id=(SELECT db_id FROM db WHERE name='$db')";
  if ($row = doQuery($sql, 1, $dbh)) {
    return $row->{'dbxref_id_id'};
  }
  else {
    return undef;
  }
}#getDbXref


sub getProject {
  my ($name, $dbh) = @_;
  my ($sql, $row);
  
  $sql = "SELECT project_id FROM project WHERE name='$name'";
  if ($row=doQuery($sql, 1, $dbh)) {
    return $row->{'project_id'};
  }
  else {
    return undef;
  }
}#getProject


sub getMGDBStock {
  return undef;
}#getMGDBStock


sub getOrganism {
  my ($name, $dbh) = @_;
  my ($sql, $row);
  
  # $name might be common name, genus/species, NCBI taxonomy ID
  if ($name =~ /^[taxid]*(\d+)$/) {
    $sql = "
      SELECT o.organism_id FROM organism o
        INNER JOIN organism_dbxref od ON od.organism_id=o.organism_id
        INNER JOIN dbxref d ON d.dbxref_id=od.dbxref_id
      WHERE d.accession='$name'";
  }
  elsif ($name =~ /(\w+)\s+(\w+)\s*(spp\.\s+\w+)*/) {
    $sql = "
      SELECT organism_id FROM organism
      WHERE genus='$1' AND species='$2'";
  }
  else {
    $sql = "SELECT organism_id FROM organism WHERE common_name='$name'";
  }
  
  if (my $row=doQuery($sql, 1, $dbh)) {
    return $row->{'organism_id'}
  }
  else {
    return undef;
  }
}#getOrganism


sub getProject {
  my ($name, $dbh) = @_;
  
  my $sql = "SELECT project_id FROM project WHERE name='$name'";
  if (my $row=doQuery($sql, 1, $dbh)) {
    return $row->{'project_id'};
  }
  else {
    return undef;
  }
}#getProject


sub getMGDBReference { 
  my ($reference, $dbh) = @_;
  
  my $sql = "
    SELECT id FROM mgdb.reference WHERE id=$reference";
  if (my $row=doQuery($sql, 1, $dbh)) {
    return $row->{'id'};
  }
  else {
    return undef;
  }
}#getMGDBReference


sub openExcelFile {
  my ($excelfile)= @_;

  # open file for reading excel file
  (-e $excelfile) or die "\n\tERROR: cannot open Excel file $excelfile for reading\n\n";
  my $parser = new Spreadsheet::ParseExcel;
  my $oBook = $parser->Parse($excelfile);
  if (!defined $oBook) {
    die $parser->error() . "\n";
  }

  return $oBook;
}#openExcelFile


sub promptUser {
  my $prompt = $_[0];
  
  print $prompt;
  my $userinput =  <STDIN>;
  return chomp ($userinput);
}#promptUser


sub readHeaders {
  my ($sheet, $row) = @_;
  my @headers;
  
  if (!$sheet->{Cells}[$row][0] || $sheet->{Cells}[$row][0]->Value() =~ /^#/) {
    # Skip this row
    return 0;
  }

  if (lc($sheet->{Cells}[$row][0]->Value()) ne 'genome') {
    # Not the header row
    return 0;
  }
  
  for (my $col = $sheet->{MinCol}; 
       defined $sheet->{MaxCol} && $col <= $sheet->{MaxCol}; 
       $col++) {
    my $cell = $sheet->{Cells}[$row][$col];
    if ($cell && $cell->Value() ne '') {
      my $header = $cell->Value();
      $header =~ s/^\*//;
      push @headers, $header;
    }
    else {
      last;
    }
  }#each column

  return @headers;
}#readHeaders


sub readRow {
  my ($sheet, $row, @headers, $dbh) = @_;
  my %data_row;
  my $nonblank;

  if (!$sheet->{Cells}[$row][0] || $sheet->{Cells}[$row][0]->Value() =~ /^#/) {
    # Skip this row
    return undef;
  }

  for (my $col = $sheet->{MinCol}; 
       defined $sheet->{MaxCol} && $col <= $sheet->{MaxCol}; 
       $col++) {
    if (my $cell = $sheet->{Cells}[$row][$col]) {
      my $value = $cell->Value();
      $value =~ s/'/''/g;
      if ($value && $value ne '' && lc($value) ne 'null') {
        my $header = $headers[$col];
        $data_row{$header} = $value;
      }
    }
  }#each column

  return \%data_row;
}#readRow


sub readWorksheet {
  my ($oBook, $worksheetname, $dbh) = @_;

  print "\n\nReading $worksheetname worksheet...\n";
  my $sheet = $oBook->worksheet($worksheetname);
  my @headers; # will include '*' on required fields
  my @rows;    # array of hashes with no special characters on header keys
  my $row_num = 0;
  for ($row_num=$sheet->{MinRow}; 
       defined $sheet->{MaxRow} && $row_num <= $sheet->{MaxRow}; 
       $row_num++) {
    if (!@headers || $#headers == 0) {
      @headers = readHeaders($sheet, $row_num);
    }
    else {
      my $data_row = readRow($sheet, $row_num, @headers, $dbh);
      if ($data_row && (scalar keys %$data_row) > 1) {
        push @rows, $data_row;
      }
    }
  }#each row

  print "  read $row_num rows from worksheet '$worksheetname'.\n";
  
  return (\@headers, \@rows);
}#readWorksheet


sub updateAnalysisMethod {
  my ($analysis_id, $seq_meth, $version, $dbh) = @_;
  
  if (!$analysis_id || $analysis_id == 0) {
    print "ERROR: analysis_id is 0 in updateAnalysisMethod()\n";
    exit;
  }
  
  my $sql = "
    UPDATE analysis
      SET program = '$seq_meth', programversion='$version'
    WHERE analysis_id=$analysis_id";
  doQuery($sql, 0, $dbh);
}#updateAnalysisMethod

1;
