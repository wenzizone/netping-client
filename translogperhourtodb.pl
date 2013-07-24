#! /bin/env perl -w

use Net::SFTP;
use Config::IniFiles;
use File::Basename;
use DBI;
use Data::Dumper;

# SFTP 从中心机房到各个测试IDC拿日志
sub sftp_get_log {
    my ($host,$remote_file,$local_file,%connect_args) = @_;
    my $rt = 1;
    my $try = 0;
    
    my $sftp = new Net::SFTP($host,%connect_args);
    while ($rt && $try <5) {
        $sftp->get($remote_file,$local_file);
        $rt = $sftp->status;
        $try++;
    }
    return($try);
}

# SFTP 推送日志到中心机房
sub sftp_put_log {
    my ($host,$local_file,$remote_file,%connect_args) = @_;
    my $rt = 1;
    my $try = 0;

    my $sftp = new Net::SFTP($host,%connect_args);

    while ($rt && $try < 5) {
        $sftp->put($local_file,$remote_file);

        $rt = $sftp->status;
        $try++;
    }
    return($try);
}

# 出错后发送邮件通知
sub send_mail{
    my $local_ip = shift;
    $cmd = "echo \"transfer log tried for 5 times but failed\nplease check it!!\nfrom $local_ip\"|mail -s 'transfer log tried for 5 times but failed' hanzhao.liu\@kunlun-inc.com";
    `$cmd`;
}

# 用于生成测试机文件名和中心文件名
sub create_file_name{
    
}

# 回收子进程资源
foreach(@childs) {
    waitpid($_,0)
}

sub help{
    print "please input one option: get or put.\n"
}

# ----- MAIN ------

if ($ARGV[0]) {
    our $option = $ARGV[0];
} else {
    help();
    exit(1);
}
our $base_dir = File::Basename::dirname($0);
my $src_ip_src = `/sbin/ifconfig eth0|grep "inet addr"`;
my ($local_ip) = $src_ip_src =~ '.*?:(\d+.\d+.\d+.\d+)';
my $file_name_suffix = "-intodb.log";


my $cfg = new Config::IniFiles(-file => $base_dir."/config.ini");

my $dest_dir = "/var/www/html/net-test/net-test-perl/perlhourlog";

if ($option eq 'put') {
    my $host = $cfg->val('center','host');
    my $user = $cfg->val('center','username');
    my $pass = $cfg->val('center','passwd');
    my $port = $cfg->val('center','port');
    my $log_dir = $cfg->val('file','log_dir');

    my %connect_args = (
        user => $user,
        password => $pass,
        ssh_args => [port => $port],
    ); 

    $remote_file = $dest_dir."/".$local_ip.$file_name_suffix;
    $local_file = $log_dir."/".$log_dir_mid.$local_ip.$file_name_suffix;

    my $res_try = sftp_put_log($host,$local_file,$remote_file,%connect_args);

    if ($res_try == 5) {
        send_mail($local_ip);
    }
} elsif ($option eq 'get') {
    my @idc_groups = $cfg->GroupMembers('Group');

    foreach (@idc_groups) {
        my $host = $cfg->val($_,'host');
        my $user = $cfg->val($_,'username');
        my $pass = $cfg->val($_,'passwd');
        my $port = $cfg->val($_,'port');
        my $log_dir = $cfg->val($_,'log_dir');

        my %connect_args = (
            user => $user,
            password => $pass,
            ssh_args => [port => $port],
        );

        $remote_file = $log_dir."/".$host.$file_name_suffix;
        $local_file = $dest_dir."/".$host.$file_name_suffix;

        my $pid = fork();
        if($pid) {
            push(@childs,$pid);
        } elsif($pid == 0) {
            my $res_try = sftp_get_log($host,$remote_file,$local_file,%connect_args); 
            if ($res_try == 5) {
                send_mail($host);
            }else{
                `perl $base_dir/import_db.pl $local_file`;
            }
            exit(0);
        }

    }
}
# ----END MAIN----------------


