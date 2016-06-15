# file: dbconnect.pl

sub getConnectString {
  my $connect_str = 'dbi:Pg:host=peanutbase-dev.agron.iastate.edu;dbname="drupal"';

  return $connect_str;
}

sub connectToDB {
  my $user        = 'ecannon';
  my $pass        = 'soy4eksc!';

  my $connect_str = getConnectString;
  my $dbh = DBI->connect($connect_str, $user, $pass);

  $dbh->{AutoCommit} = 0;  # enable transactions, if possible
  $dbh->{RaiseError} = 1;

  return $dbh;
}#connectToDB

1;
