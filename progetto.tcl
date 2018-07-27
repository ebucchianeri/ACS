
if {$argc == 1} { 
    set sim          [lindex $argv 0] 
} else {
    puts ""
    puts "      5Mb, 10ms"
    puts "  S1 -----------------" 
    puts "                     |"
    puts "       10Mb,10ms        25Mb,100ms  "
    puts "  S2 -------------- R1 ---------------R2"
    puts "                     |"
    puts "                     |"
    puts "  S3 -----------------"
    puts "       10Mb, 10ms"
    puts ""
    puts ""
    puts "  Usage:  $argv0 Queue_type (DropTail | RED)"
    puts ""
    exit 1
}

set ns [new Simulator]

#tracing 
set trace_nam  [open $sim.nam w]
set trace_all  [open $sim.tr w]
set trace_swnd [open swnd.$sim w]
set numseq [open sn.$sim w]


$ns namtrace-all $trace_nam
$ns trace-all $trace_all

# print cwnd
proc sampleswnd { interval } {
    global ns trace_swnd tcp1 
    set now [$ns now]
    set curr_cwnd [$tcp1 set cwnd_]
    set curr_wnd  [$tcp1 set window_]
    if { $curr_wnd < $curr_cwnd  } {
	set swnd $curr_wnd
    } else { 
	set swnd $curr_cwnd 
    }
    puts $trace_swnd     "$now $swnd"
    $ns at [expr $now + $interval] "sampleswnd $interval"
} 


# print sequence number
proc altri_tcp_var { step } {
	global ns tcp1 numseq
	set now [$ns now]
	set seqno [$tcp1 set t_seqno_ ]
	set sst [$tcp1 set ssthresh_ ]
	puts $numseq "$now $seqno $sst"
	$ns at [expr $now+$step] "altri_tcp_var $step"
}



#define a 'finish' procedure
proc finish {} {
  global ns sim trace_nam trace_all trace_swnd numseq  
  $ns flush-trace
  #close the trace file
  close $trace_nam
  close $trace_all
  close $trace_swnd
  close $numseq
  #execute nam on the trace file
  #exec nam $sim.nam &
  exit 0
}



# Define the topology
set s1 [$ns node]
set s2 [$ns node]
set s3 [$ns node]
set r1 [$ns node]
set r2 [$ns node]

#color
$s1 color "Blue"
$s1 add-mark color "Blue"
$s2 color "Green"
$s2 add-mark color "Green"
$s3 color "Red"
$s3 add-mark color "Red"

#   object      from  to    bandwith   delay    queue
$ns duplex-link $s1   $r1   5Mb        10ms    DropTail 
$ns duplex-link $s2   $r1   5Mb        10ms    DropTail  
$ns duplex-link $s3   $r1   10Mb       10ms    DropTail  
$ns duplex-link $r1   $r2   25Mb       100ms   $sim  


$ns duplex-link-op $s1 $r1 orient right-down
$ns duplex-link-op $s2 $r1 orient right
$ns duplex-link-op $s3 $r1 orient right-up
$ns duplex-link-op $r1 $r2 orient right

#$ns queue-limit $r1 $r2 50
$ns duplex-link-op $r1 $r2 queuePos 0.5


if {$sim == "RED"} { 
  set redq [[$ns link $r1 $r2] queue]
  set tchan_ [open info_RED.tr w]
  $redq trace curq_
  $redq trace ave_
  $redq attach $tchan_
  
  #$redq set thresh_ 1
  #$redq set maxthresh_ 6
  $redq set bytes_ false
  $redq set queue_in_bytes_ false
}

#nodo S1
set tcp1 [new Agent/TCP/RFC793edu] 
$ns attach-agent $s1 $tcp1
set sink1 [new Agent/TCPSink] 
$ns attach-agent $r2 $sink1
$ns connect $tcp1 $sink1

$ns color 1 blue
$tcp1 set fid_ 1

$tcp1 set window_ 1000
$tcp1 set jacobsonrtt_ true
$tcp1 set add793fastrtx_ false
$tcp1 set add793slowstart_ false
$tcp1 set add793exponinc_ true
$tcp1 set add793additiveinc_ false
$ns at 0.01 "$tcp1 set ssthresh_ 1"

set ftp1 [new Application/FTP] 
$ftp1 attach-agent $tcp1

# nodo S2
set udp2 [new Agent/UDP]
$ns attach-agent $s2 $udp2
set null2 [new Agent/Null]
$ns attach-agent $r2 $null2
$ns connect $udp2 $null2
$ns color 2 green
$udp2 set fid_ 2

set cbr2 [new Application/Traffic/CBR]
$cbr2 set packetSize_ 125
$cbr2 set rate_ 3mb
$cbr2 attach-agent $udp2

# nodo S3
set udp3 [new Agent/UDP]
$ns attach-agent $s3 $udp3
set null3 [new Agent/Null]
$ns attach-agent $r2 $null3
$ns connect $udp3 $null3
$ns color 3 red
$udp3 set fid_ 3

set cbr3 [new Application/Traffic/CBR]
$cbr3 set packetSize_ 500
$cbr3 set rate_ 5mb
$cbr3 attach-agent $udp3




$ns at 0.0 "sampleswnd 0.01"
$ns at 0.0 "altri_tcp_var 0.01"
$ns at 0.0 "$cbr3 start"
$ns at 0.5 "$cbr2 start"
$ns at 0.5 "$ftp1 start"
$ns at 10.0 "$ftp1 stop"
$ns at 10.0 "$cbr2 stop"
$ns at 10.0 "$cbr3 stop"
$ns at 12.0 "finish"

$ns run



