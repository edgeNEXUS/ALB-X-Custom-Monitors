#Monitor-Name:LDAPS_Healthcheck
use strict;
use warnings;
use Net::LDAP; 
use MIME::Base64;

#####################################################################
# EdgeNexus custom LDAPS Healthcheck - written by acra
#####################################################################
# This is a Perl script for use with Edge Nexus load balancers to check LDAPS status
# When return = 1, healthcheck pass. When return = 2, healthcheck fail.
# See https://appstore.edgenexus.io/user-guides/user-guide-4-2-x/software-version-4-2-x-user-guide/real-server-monitoring/#Custom_Monitors for more details
sub monitor
{
	 my $host = $_[0];   ### Host IP or name
	 my $port = $_[1];   ### Host port
	 my $notes = $_[3];  ### Taken from notes field on Real Server
	 my $user = $_[5];   ### User field from GUI Library > Real Server Monitors
	 my $password = $_[6];   ### Password field from GUI Library > Real Server Monitors
	 my $resolve;
	 my $auth = '';
	 
	 #Password is Base64 encoded as such please passwordd
$passwordd =$decode_base64($password);
	 
	 if ($port)
	 {
		 $resolve = "$notes:$port:$host";
	 }
	 else {
		 $resolve = "$notes:$host";
	 }
	## Connect and bind to the server.
	 $ldap = Net::LDAP->new ($host, port =>$port,
							 version => 3 )
	 or return(2);
		 
	 $result = $ldap->start_tls(  );
	 return(2) if $result->code(  );
		 
	 $result = $ldap->bind(
			 "cn=aerohive_svc,ou=service accounts,dc=diti,dc=lr,dc=net",
			 password => $password);
	 return(2) if $result->code(  );
      
	## Unbind and exit.
	 $ldap->unbind(  );
	 print "Bind Successful. Quitting.";
	 return(1);
	 
}
monitor(@ARGV);
	 
