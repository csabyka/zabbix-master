#!/usr/bin/perl

$bareosDbUser='bareos';
$bareosDbName='bareos';

@clients=`/usr/bin/psql -U$bareosDbUser -d$bareosDbName -t -A -c "select name from client;"`;

$first = 1;
print "{\n";
print "\t\"data\":[\n\n";
foreach $arg(@clients)
{
  $arg=~s/\n//; 
  print "\t,\n" if not $first;
	$first = 0;
	print "\t{\n";
  print "\t\t\"{#CLIENTNAME}\":\"$arg\"\n";
  print "\t}\n";
}
print "\n\t]\n";
print "}\n";
