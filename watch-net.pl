#! /usr/bin/env perl -w

use File::Basename;
use Data::Dumper;
use Mail::Sender;
use MIME::Base64;

# 负责ping测试的子函数
sub ping {
    my ($local,$ip,$src_ip,$time,$net) = @_;
    my $dest_file = $dest_dir . '/' . $tmp_dir . '/tmp_' . $local . '.log';
    my $cmd = "ping $ip -c20 -W10";
    my $a = `$cmd`;
    my ($lost_data) = $a =~ '.*?,.*?, (\d+%)';
    my ($min,$avg,$max) = $a =~ '.*? = (\d+.\d+)/(\d+.\d+)/(\d+.\d+)';
    open fh,">>$dest_file";
    print fh "$time\t$src_ip\t$ip\t$lost_data\t$min\t$avg\t$max\t$local\t$net\n";
    close(fh);
}

# 将日志汇聚到一个文件中
sub gather_log {
    opendir DH,"$dest_dir/$tmp_dir";
    foreach (readdir DH) {
        next if /^\./;
        `cat "$dest_dir/$tmp_dir/$_" >> "$dest_dir/watch-net-test.log"`;
    }
    closedir DH;
    `rm -rf "$dest_dir/$tmp_dir"`;
}

sub net_alert {
    my ($time,$server_ip) = @_;
    my $cmd = "awk '{print \$10}' $dest_dir/watch-net-test.log|sed '/^\$/d'|sort|uniq";
    my $network_tmp = `$cmd`;
    chomp($network_tmp);
    my @network = split(/\n/,$network_tmp);
    foreach(@network) {
	next if /cernet/;
	next if /cmnet/;
	my $cmd = "grep \"$time\" $dest_dir/watch-net-test.log |grep \"$_\"";
	my $res_tmp = `$cmd`;
	my @res = split(/\n/,$res_tmp);
	my $mesg = "";
	my $count = 0;
 	foreach $line(@res) {
	    my($date,$time,$lost,$city,$network) = $line =~ /(\S+) (\S+)\t\S+\t\S+\t(\d+)%\t\S+\t\S+\t\S+\t(\S+)\t(\S+)/;
	    if($lost > 10) {
	        $mesg .= "$date-->$time-->$city-$network-->$lost\%\n";
	        $count++;
	    }
	}
	if($count >= 3 and $count < 9) {
        @rcpt_to = ('hanzhao.liu@kunlun-inc.com');
        send_mail($server_ip,$count,$mesg,$network,@rcpt_to);
    }elsif($count >= 9 ) {
        @rcpt_to = ('hanzhao.liu@kunlun-inc.com');
        send_mail($server_ip,$count,$mesg,$network,@rcpt_to);
	}
    #print "$date,$time,$lost,$city,$network\n";
	
    }
}

sub send_mail {
    my($server_ip,$count,$mesg,$network,@rcpt_to) = @_;
    my $subject = "服务器：$server_ip 在 $count 个省的 $network 均有丢包的情况出现 !!!";
    $subject = encode_base64($subject,"");
    chomp($subject);
    $mail = new Mail::Sender{smtp => "127.0.0.1", port => 25} or die"$Mail::Sender::Error\n";
    $mail->Body({encoding => 'Base64',
        charset => 'utf8',});
    $mail->MailMsg({from => 'hanzhao.liu@localhost',
        to => $rcpt_to[0],
        cc => @rcpt_to > 1 ? $rcpt_to[1] : "",
        subject => "=?utf-8?B?$subject?=\n\n",
        msg => $mesg,});
    $mail->Close();
    print $Mail::Sender::Error eq "" ? "send ok!\n" : $Mail::Sender::Error;
}

sub clear_log {
    my $times = shift;
    my @time = split(/ /,$times);
    if ($time[1] eq '00:00' or $time[1] eq '12:00') {
	my $cmd = "echo \"\" > $dest_dir/watch-net-test.log";
	`$cmd`;
    }
}


# ---- MAIN ------

our $dest_dir = File::Basename::dirname($0);
our $tmp_dir = 'tmp';
my $time_str = 'date +%Y-%m-%d\ %H:%M';
my $time = `$time_str`;
chomp($time);

clear_log($time);

`mkdir $dest_dir/$tmp_dir`;
my $src_ip_src = `/sbin/ifconfig eth0|grep "inet addr"`;
my ($src_ip) = $src_ip_src =~ '.*?:(\d+.\d+.\d+.\d+)';

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

gather_log();

net_alert($time,$src_ip);
