#! /usr/bin/env perl -w

use File::Basename;
use Data::Dumper;

# 负责ping测试的子函数
sub ping {
    my ($local,$ip,$src_ip,$time,$net) = @_;
    my $dest_file = $dest_dir . '/' . $tmp_dir . '/tmp_' . $local . '.log';
    my $cmd = "ping $ip -c100 -W10";
    my $a = `$cmd`;
    my ($lost_data) = $a =~ '.*?,.*?, (\d+%)';
    my ($min,$avg,$max) = $a =~ '.*? = (\d+.\d+)/(\d+.\d+)/(\d+.\d+)';
    open FH,">>$dest_file";
    print FH "$time\t$src_ip\t$ip\t$lost_data\t$min\t$avg\t$max\t$local\t$net\n";
    close(FH);
    `curl -X POST -d "test_time=$time&src_ip=$src_ip&dst_ip=$ip&lost_packet=$lost_data&min_connect=$min&avg_connect=$avg&max_connect=$max&province=$local&network=$net" http://netping/index.php/admin/api/import_to_db`
}

# 将日志汇聚到一个文件中
sub gather_log {
	my $localip = shift;
    opendir DH,"$dest_dir/$tmp_dir";
    foreach (readdir DH) {
        next if /^\./;
        `cat "$dest_dir/$tmp_dir/$_" >> "$dest_dir/net-test.log"`;
		`cat "$dest_dir/$tmp_dir/$_" >> "$dest_dir/$localip-intodb.log"`;
    }
    closedir DH;
    #`rm -rf "$dest_dir/$tmp_dir"`;
}

#清空导入日志
sub clear_log {
    my ($times,$localip) = @_;
    my @time = split(/ /,$times);
    if ($time[1] =~ "[0-2][0-9]:00" ) {
		my $cmd = "echo > $dest_dir/$localip-intodb.log";
		`$cmd`;
		print $cmd;
    }
}

# ------- MAIN ---------
our $dest_dir = File::Basename::dirname($0);
our $tmp_dir = 'tmp';
#my $time_str = 'date +%Y-%m-%d\ %H:%M';
my $time_str = 'date +%s';
my $time = `$time_str`;
chomp($time);
if (! -e "$dest_dir/$tmp_dir") {
    `mkdir $dest_dir/$tmp_dir`;
}

my $src_ip_src = `/sbin/ifconfig eth0|grep "inet addr"`;
my ($src_ip) = $src_ip_src =~ '.*?:(\d+.\d+.\d+.\d+)';

clear_log($time,$src_ip);

our $line = 0;
our $province = 0;

open FH,"<$dest_dir/ip.txt";
while (<FH>) {
    $line++;
    chomp;
    @list = split;
    if($line == 1){
        for(my $i = 1; $i < @list; $i++) {
            push @province,$list[$i]; 
        }
    }else{
        for(my $i = 1; $i < @list; $i++) {
           $net_hash{$province[$i - 1]}{$list[$province]} = $list[$i];
        }
    }
}
close(FH);

# 处理各节点数据
while (($k,$v) = each %net_hash) {
    while (($k1,$v1) = each %{$v}) {
        my $pid = fork();
        if($pid) {
            push(@childs,$pid);
        } elsif($pid == 0) {
            ping("$k1",$v1,$src_ip,$time,$k);
            exit(0);
        }
    }
}

# 回收子进程资源
foreach(@childs) {
    waitpid($_,0)
}

gather_log($src_ip);
