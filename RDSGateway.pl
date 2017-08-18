#Monitor-Name:RDSGateway

use strict;
use warnings;

########################################################################################################
# jetNEXUS custom health checking Copyright jetNEXUS 2015
########################################################################################################
#
# Microsoft RDS Remote Desktop Gateway health-check
#
# _[0] IP address of the server to be health checked
# _[1] Port of the server to be health checked (ignored by this script)
# _[2] Required content: UserName%Password
# _[3] Notes value from the Real Server (ignored by this script)
# 
# The script will return the following values
# 1 is the test is successful
# 2 if the test is unsuccessful
#
#
# Goal: load balance multiple Microsoft RDS 2012 R2 RD Gateway and RDWEB Roles 
# configured on common servers. The default IIS health check is not sufficient.
# This comprehensive health check ensures traffic is only directed to a server 
# that is fully operational. 
#
# We need to check:
# 1) the port 3391 UDP is open for connection;
# 2) the IIS page /rpc is also responding;
# 3) the IIS page /RDWeb is responding on 443;
# 4) the gateway service is alive on target server and accepting logins.



sub monitor
{
    my $host    = $_[0];
    my $port    = $_[1];	# unused
    my $content = $_[2];
    my $notes   = $_[3];	# unused

    my ($user, $pass) = split(/\%/, $content);
    my $udp_port = 3391;

    if (!$host) {
      print "Microsoft RDS Gateway health-check failed (host address not specified)\n";
      return(2);
    }
    if (!$user) {
      print "Microsoft RDS Gateway health-check failed (domain user name not specified)\n";
      return(2);
    }
    if (!$pass) {
      print "Microsoft RDS Gateway health-check failed (domain user password not specified)\n";
      return(2);
    }

    # Check UDP port
    my $res = `nc -z -w1 -u $host $udp_port`;
    if ($? != 0) {
        print "Microsoft RDS Gateway health-check failed (UDP port check failed)\n";
	return(2);
    }

    # Check RPC page
    $res = `curl -k -s -o /dev/null -w %{http_code} -u '$user':'$pass' "https://$host/rpc/en-us/rpcproxy.dll"`;
    if ($res ne '503') {
        print "Microsoft RDS Gateway health-check failed (RPC page check failed)\n";
	return(2);
    }

    # Check RDWeb page
    $res = `curl -k -s -o /dev/null -w %{http_code} -X POST "https://$host/RDWeb/Pages/en-US/login.aspx?ReturnUrl=/RDWeb/Pages/en-US/Default.aspx" -d "DomainUserName=$user&UserPass=$pass"`;
    if ($res ne '302') {
        print "Microsoft RDS Gateway health-check failed (RDWeb page check failed)\n";
	return(2);
    }

    return(1);
}

exit(monitor(@ARGV));
