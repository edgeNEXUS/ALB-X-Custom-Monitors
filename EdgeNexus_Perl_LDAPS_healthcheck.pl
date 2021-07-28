#Monitor-Name:LDAPS
use strict;
use warnings;
use Net::LDAP; 
use MIME::Base64;

#####################################################################
# EdgeNexus custom LDAPS Healthcheck - written by acra
#####################################################################
# This is a Perl script for use with Edgenexus load balancers to check LDAPS status
# When return = 1, healthcheck pass. When return = 2, healthcheck fail.
# See https://appstore.edgenexus.io/user-guides/user-guide-4-2-x/software-version-4-2-x-user-guide/real-server-monitoring/#Custom_Monitors for more details
sub monitor
{
	my $host = $_[0];   ### Host IP or name
	my $port = $_[1];   ### Host port
	my $notes = $_[3];  ### Taken from notes field on Real Server
	my $user = $_[5];   ### User field from GUI Library > Real Server Monitors
	my $password = $_[6];   ### Password field from GUI Library > Real Server Monitors

	if (!defined($port) || ($port eq '')) {
	    $port = 636;
	}

	# Password is Base64 encoded as such please passwordd
        my $passwordd = decode_base64($password);

 	# Connect to the server
	my $ldap = Net::LDAP->new("ldaps://$host", port => $port, version => 3)
	    or return(2);

	# Bind to the server
	my $result = $ldap->bind($user, password => $passwordd);
	return(3) if $result->code();
      
   	# Unbind and exit
	$ldap->unbind();
	print "LDAP bind Successful.\n";
	return(1);
}
monitor(@ARGV);
