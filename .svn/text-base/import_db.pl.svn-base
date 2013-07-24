#! /usr/bin/env perl

use DBI;
use Data::Dumper;

our $database = "net-test";
our $hostname = "127.0.0.1";
our $username = 'root';
our $password = '';
our $dsn = "DBI:mysql:database=$database;host=$hostname";
our $dbh = DBI->connect($dsn, $username, $password);
our $log_file = $ARGV[0];

$dbh->do("SET NAMES 'utf8'");
$dbh->do("SET CHARACTER_SET_CLIENT=utf8");
$dbh->do("SET CHARACTER_SET_RESULTS=utf8");

my $sql="insert into tb_nettest(test_time,src_ip,dst_ip,lost_packet,min_connect,avg_connect,max_connect,province,network) value (?,?,?,?,?,?,?,?,?)";
my $sth = $dbh->prepare($sql);

sub create_table {
	my $create_table = "create table IF NOT EXISTS tb_nettest(
		id bigint not null primary key AUTO_INCREMENT,
		test_time DATETIME,
		src_ip char(15),
		dst_ip char(15),
		lost_packet int(3),
		min_connect float(10,3),
		avg_connect float(10,3),
		max_connect float(10,3),
		province varchar(100),
		network varchar(100))engine=myisam char set utf8";
	my $sth = $dbh->prepare($create_table);
	$sth->execute;
}

sub extractinfo {
	my @data = split(/[\t|,]/,$_);
	
	return(@data);
}
sub write_db {
	my ($sth,@data) = @_;
	for ($i = 0; $i<@data; $i++) {
		my $j = $i;
		$j++;
		$sth->bind_param($j, $data[$i]);
	}
	$sth->execute();
	$sth->finish;
}

# --main--

create_table();

open FH,"<$log_file";
while(<FH>) {
	chomp;
	my @data = extractinfo($_);
	write_db($sth,@data);
}