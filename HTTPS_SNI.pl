#Monitor-Name:HTTPS_SNI

use strict;
use warnings;

########################################################################################################
# jetNEXUS custom health checking Copyright jetNEXUS 2016
########################################################################################################
#
#
# This is a Perl script for jetNEXUS customer health checking
# The monitor name as above is displayed in the dropdown of Available health checks
# There are 6 value passed to this script (see below)
#
# The script will return the following values
# 1 is the test is successful
# 2 if the test is un successful
#
# This monitor will send an SNI compatable HTTPS health check to each of your real servers. 
# Use the Library or Real Servers to customise you page location, required content and the 
# notes section to specify the domain name to be checked. 


sub monitor
{
    my $host       = $_[0];     ### Host IP or name
    my $port       = $_[1];     ### Host Port
    my $content    = $_[2];     ### Content to look for (in the web page and HTTP headers)
    my $notes      = $_[3];     ### Virtual host name
    my $page       = $_[4];     ### The part of the URL after the host address
    my $user       = $_[5];     ### domain/username (optional)
    my $password   = $_[6];     ### password (optional)
    my $resolve;
    my $auth       = '';

    if ($port) 
    {
        $resolve = "$notes:$port:$host";        
    }
    else {
        $resolve = "$notes:$host";
    }

    if ($user && $password) {
        $auth = "-u $user:$password";   
    }

    # Use fresh curl 7.50.3 with SNI support
    my @lines = `LD_LIBRARY_PATH=/usr/local/lib64 curl-jn -s -i --retry 1 --max-time 1 -k -H "Host:$notes" --resolve $resolve $auth https://${notes}${page} 2>&1`;
    if (join("",@lines) =~ /$content/)
    {   
        print "https://${notes}${page} looking for - $content - Healhcheck check successful\n";
        return(1);
    }
    else
    {
        print "https://${notes}${page} looking for - $content - Healhcheck check failed.\n";
        return(2)
    }

}

monitor(@ARGV);
