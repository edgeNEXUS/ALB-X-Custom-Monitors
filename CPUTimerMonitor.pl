#Monitor-Name:CPUTimerMonitor

use strict;
use warnings;

########################################################################################################
# jetNEXUS custom health checking Copyright jetNEXUS 2016
########################################################################################################
#
#
# This is a Perl script for jetNEXUS customer health checking
# The monitor name as above is displayed in the dropdown of Available health checks
# There are 4 value passed to this script
#
# 1) IP address of the server to be health checked
# 2) Port of the server to be health checked
# 3) Required contact - additional data can be passed to health check from the GUI
# 4) Server Notes - from that content server, allowing server-unique values, like username and password
# 
# The script will return the following values
# 1 is the test is successful
# 2 if the test is un successful
#
# When a Windows Server reaches a CPU of 100% and maintains this for 10 minutes, 
# fail the health check and take the server offline. 


sub max {
    my ($x, $y) = @_;
    ($x + $y + abs($x - $y)) / 2;
}


# Remove from history all data that are preceding the latest high CPU load period.
sub trim_green_history_data {
        my @history = @{$_[0]};
        my $threshold = $_[1];
	my $now = $_[2];
	my $time_to_red = $_[3];
    	my $debug_fh = $_[4];
    	my $debug = $_[5];

        # Search through history backwards and find the first occurance of low CPU load,
        # which is preceeding the latest block of high CPU load
        my $found_high = 0;
        my $found_low = 0;
	for (my $i=$#history; $i>=0; $i--) {
            next if (!$history[$i] || ($history[$i] eq ''));
	    my ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	    if (($load > $threshold) && !$found_high) {
                $found_high = $i;
	    }
	    if (($load < $threshold) && $found_high) {
                $found_low = $i;
                last;
	    }
	}

        # Delete data, but leave at least $time_to_read of data
        my $del_num = 0;
        if ($found_low) {
            for (my $i=$found_low; $i>=0; $i--) {
                next if (!$history[$i] || ($history[$i] eq ''));
        	my ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	        if ($time < $now - $time_to_red - 5) {
		    delete $history[$i];
                    $del_num++;
	        }
	    }
        }

	if ($del_num > 0) {
	    printf($debug_fh "Deleted history data values preceding the latest high CPU load period: $del_num\n") unless (!$debug);
        }

        return(@history);
}


sub monitor
{

	############
	# VARIABLES
	############
	my $ipaddr  = shift; 	### REMOTE HOST'S IP ADDRESS
	my $port    = shift;	### NOT APPLICABLE. JUST PROVIDE ANY DUMMY VALUE.	
	my $content = shift;	### <TIME TO SWITCH TO GREEN>,<TIME TO SWITCH TO RED>,<CPU LOAD % THRESHOLD>
	my $notes   = shift;	### CAPTURES IN FORMAT "<Domain>/<Username>%<Password>". <Domain> is optional. 
	my $cmd     = "/usr/bin/wmic -U $notes //${ipaddr} \"select LoadPercentage from Win32_Processor\"";
	my $log_file = "/tmp/CPUTimerMonitor-$ipaddr.tmp";
	my ($time_to_green, $time_to_red, $threshold) = split(/,/, $content);
	my $cpuload;
	my $status;
	my @results = ();
	my $debug = 0;
	my $debug_fh;

	my $now = time();
	chomp($now);

	if ($debug) {
	    open($debug_fh, ">>", "/tmp/CPUTimerMonitor.log");
    	    my $time = `LC_ALL=C date -d \@$now`;
	    printf($debug_fh "Time: $time");
	}

        #################
        # LOG PARAMETERS
        #################
	if ($debug)  {
    	    printf($debug_fh "PARAMETERS: IP_Address=%s Port=%s Content=%s Notes=%s\n", $ipaddr, $port, $content, $notes);
	}

        ##################
	# VERIFY CONTENT #
        ##################
	if (!defined($threshold) || ($threshold < 1) || ($threshold > 100) ||
	    !defined($time_to_red) || ($time_to_red < 1) ||
 	    !defined($time_to_green) || ($time_to_green < 1)) 
	{
	    printf(STDERR "PARAMETERS: IP_Address=%s Port=%s Content=%s Notes=%s\n", $ipaddr, $port, $content, $notes);
	    print(STDERR "Content format: <TIME TO SWITCH TO GREEN>,<TIME TO SWITCH TO RED>,<CPU LOAD % THRESHOLD>\n");
	    close($debug_fh) unless (!$debug);
	    exit();
	}
	
	##################################
	# RUN WMI TO GET CPU INFORMATION #
	##################################
	@results = split /\n/, `$cmd`;

	#####################
	# DISPLAY ERROR MSG #
	#####################
	if ($results[0] !~ /Win32_Processor/i)
	{
	    my $err_msg = join "\n", @results;
	    printf($debug_fh "ERROR MSG: $err_msg\n") unless (!$debug);
	    printf(STDERR "ERROR MSG: $err_msg\n");
	    close($debug_fh) unless (!$debug);
	    return 2;		
	}

	### JUNK FIRST 2 LINES: CLASS NAME AND PROPERTY NAMES ###	
	shift(@results);
	shift(@results);

	### GET CURRENT CPU LOAD ###
	foreach my $result(@results)
	{
	    my ($jnk, $val) = split /\|/, $result;
	    $cpuload += $val;
	    printf($debug_fh "CPU_LOAD_VALUE: $val\n") unless (!$debug);
	}

	### DETERMINE CURRENT CPU LOAD PERCENTAGE ###
	$cpuload = $cpuload / ($#results + 1);
#        $cpuload = `cat /tmp/cpu`; chomp($cpuload);
	print($debug_fh "CPU_LOAD_%: $cpuload\n") unless (!$debug);
	
	### LOAD HISTORY ###
	my @history;
	if (-f $log_file) {
	    open(LOG, $log_file);
	    @history = <LOG>;
	    close(LOG);
	}

	### REMOVE HISTORY DATA OLDER THAN max($time_to_green, $time_to_red) AND WITH TIME IN FUTURE ###
	my $del_num = 0;
	my $last_removed;
	my ($time, $load, $oldstatus);
	foreach my $i (0 .. $#history) {
	    $history[$i] =~ s/\n$//;
            next if (!$history[$i] || ($history[$i] eq ''));
	    ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	    if ($time > $now) {
		delete $history[$i];
		$del_num++;
	    }
	    if ($time < $now - max($time_to_green, $time_to_red) - 5) {
		$last_removed = $history[$i];
		delete $history[$i];
		$del_num++;
	    }
	}
	# Return last removed value back to history array, as we need
	# to keep a bit more than $time_to_green seconds of history
	if ($last_removed && ($last_removed ne '')) {
	    unshift(@history, $last_removed);
	    $del_num--;
	}
	if ($del_num > 0) {
	    printf($debug_fh "Deleted old history data values: $del_num\n") unless (!$debug);
	}

	### Assign previous status value to current status at first ###
	$status = $oldstatus;

	### APPEND CURRENT CPU LOAD PERCENTAGE TO HISTORY ###
	push(@history, "$now $cpuload 0");

	### 1. If there is not enough history data, i.e history size < $time_to_red, ###
	### assume status GREEN	and return the result.				     ###
	# Find first non-empty item in history array
	my $time_first;
	foreach my $l (@history) {
	    next if ($l eq '');
	    my ($time, $load, $oldstatus) = split(/ /, $l);
	    if ($time > 0) {
		$time_first = $time;
		last;
	    }
	}	
	if ($time_first > $now - $time_to_red) {
	    printf($debug_fh "History size < ${time_to_red}, assuming status GREEN\n") unless (!$debug);
	    $status = 1;
	    goto end;
	}

	### 2. CHECK IF AVERAGE CPU LOAD > $threshold FOR $time_to_red SECONDS => status = RED ###
	my $average_load_red;
	my $num_red = 0;
	foreach my $i (0 .. $#history) {
	    next if (!$history[$i] || ($history[$i] eq ''));
	    my ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	    next if ($time < $now - $time_to_red);
	    $average_load_red += $load;
	    $num_red++;
	}
	$average_load_red = $average_load_red / $num_red;
	printf($debug_fh "AVERAGE_CPU_LOAD_RED: $average_load_red\n") unless (!$debug);
	if ($average_load_red > $threshold) {
	    $status = 2;
    	    printf($debug_fh "status=$status\n") unless (!$debug);
            goto end;
	}

	### 3. CHECK IF AVERAGE CPU LOAD < $threshold FOR $time_to_green SECONDS => status = GREEN ###
	### Do this only if there are at least TIME_TO_GREEN seconds of data since the last        ###
	### transition from green to red.							   ###
	# Find the time of the last transition from green to red
	my ($transition_time, $time_green, $time_red);
	for (my $i=$#history; $i>=0; $i--) {
            next if (!$history[$i] || ($history[$i] eq ''));
	    my ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	    if ($oldstatus == 2) {
		$time_red = $time;
	    }
	    if ($time_red && ($oldstatus == 1)) {
		$transition_time = $time_red;
		last;
	    }
	}

	# If there was a transition from green to red, check if there are at least TIME_TO_GREEN seconds 
	# of data since the last transition from green to red, otherwise do not do the check over the 
	# TIME_TO_GREEN period
	if ($transition_time) {
	    printf($debug_fh "transition_time=%d, now-transition_time=%d, time_to_green=%d\n", $transition_time, $now - $transition_time, $time_to_green) unless (!$debug);
	    if ($now - $transition_time < $time_to_green) {
		printf($debug_fh "Transition from GREEN to RED was %ds ago < %ds, not checking over the TIME_TO_GREEN period\n", $now - $transition_time, $time_to_green) unless (!$debug);
		goto end;
	    }
	}

	my $average_load_green;
	my $num_green = 0;
	foreach my $i (0 .. $#history) {
	    next if (!$history[$i] || ($history[$i] eq ''));
	    my ($time, $load, $oldstatus) = split(/ /, $history[$i]);
	    next if ($time < $now - $time_to_green);
	    $average_load_green += $load;
	    $num_green++;
	}
	$average_load_green = $average_load_green / $num_green;
	printf($debug_fh "AVERAGE_CPU_LOAD_GREEN: $average_load_green\n") unless (!$debug);
	if ($average_load_green < $threshold) {
	    $status = 1;
	} else {
	    $status = 2;
	}
        printf($debug_fh "status=$status\n") unless (!$debug);

end:
	# Put current status value to the last item of the @history array
	$history[$#history] = "$now $cpuload $status";

        if ($status == 2) {
            @history = trim_green_history_data(\@history, $threshold, $now, $time_to_red, $debug_fh, $debug);
        }

	# Debug print history array
        print($debug_fh "History:\n") unless (!$debug);
        foreach my $i (0 .. $#history) {
	    next if (!$history[$i] || ($history[$i] eq ''));
            print($debug_fh "history[$i] = $history[$i]\n") unless (!$debug);
        }

	### SAVE HISTORY TO FILE ###
	open(LOG, ">$log_file");
	foreach my $l (@history) {
	    next if (!$l || ($l eq ''));
	    print(LOG "$l\n");
	}
        close(LOG);

	### RETURN STATUS ###
	printf($debug_fh "RET_VAL: $status\n") unless (!$debug);
	close($debug_fh) unless (!$debug);
	return($status);
}



exit(monitor(@ARGV));
