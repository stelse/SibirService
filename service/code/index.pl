#!/usr/local/bin/perl

use strict;
use warnings FATAL => 'all';;
use IO::Socket;
use DBI;
use Digest::MD5 qw(md5_hex);
use Algorithm::LCSS qw( LCSS CSS CSS_Sorted );
use threads;
use Try::Tiny;
use List::MoreUtils;


sub addtask {
	my ($task, $login, $phrase, $dbh) = @_;
	my $stmt = "SELECT id FROM persons WHERE login = '$login' LIMIT 1";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	my @author = $sth->fetchrow_array();
	$stmt = "INSERT INTO tasks (description, phrase, id_person) VALUES ('$task', '$phrase', $author[0]) RETURNING id";
	$sth = $dbh->prepare($stmt);
	$rv = $sth->execute() or die $DBI::errstr;	
	my @id_task = $sth->fetchrow_array();
	return $id_task[0];
}

sub addtest {
	my ($login, $ntask, $inp, $outp, $dbh) = @_;
	my $stmt = "SELECT id FROM tasks WHERE id = $ntask AND id_person = (SELECT id FROM persons WHERE login = '$login' LIMIT 1)";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 1){
		$stmt = "INSERT INTO tests (id_task, input, output) VALUES ($ntask, '$inp', '$outp')";
		$rv = $dbh->do($stmt) or die $DBI::errstr;
		return 1; 
	} else {
		return 0;
	}
}


sub fingerprint($)
{
	my @keywords = qw(
	auto 	 break 	    case 	    char 	const 	    continue 	default 	do
	double 	 else 	    enum 	    extern 	float 	    for 	    goto 	    if
	int 	 long 	    register 	return 	short 	    signed 	    sizeof 	    static
	struct 	 switch 	typedef 	union 	unsigned 	void 	    volatile 	while

	printf scanf include stdio math stdlib malloc calloc realloc free

	bool catch class const_cast delete dynamic_cast explicit false friend
	inline mutable namespace new operator private protected public
	reinterpret_cast static_cast template this throw true try typeid typename
	using virtual wchar_t 
	
	cons car cdr atom null list defun lambda setq eval funcall apply format princ 
	if cond unless eq eql equal equalp let loop nil
	
	as case of class data default deriving do forall foreign hiding if then else import infix infixl infixr 
        instance let in mdo module newtype qualified type where	
);
	
	my ($contents) = @_;
	my %keywords;
	map { $keywords{$_} = 1; } @keywords;
	my %result;

	$result{source} = md5_hex($contents);

	$contents =~ s/\/\*.*?\*\///gs;
	$contents =~ s/\/\/.*//g;
	$contents =~ s/\b/ /g;
	$contents =~ s/(\W)(?=\W)/$1 /g;
	$contents =~ s/[\s\n\r]+/ /g;
	$result{compressed} = md5_hex($contents);

	my %dictionary;
	my $counter = 0;

	while ($contents =~ /\b([a-z]\w*)\b/gi)
	{
		next if defined $keywords{$1};
		$dictionary{$1} = sprintf "ID%05d", ++$counter;
	}

	foreach my $word (keys %dictionary)
	{
		$contents =~ s/\b$word\b/$dictionary{$word}/g;
	}

	$result{encoded} = md5_hex($contents);

	my @contents = split /\s+/, $contents;
	my $fingerprints = '';
	my @fplist;
	foreach my $token (@contents)
	{
		my $value = (defined $keywords{$token} ? 'k' : ($token =~ /^ID/ ? 'i' : 
								($token =~ /^\d+$/ ? 'n' : $token)));
		$fingerprints .= $value;
		push @fplist, $value;
	}
	 
	$result{fingerprints} = $fingerprints;
	$result{fplist} = \@fplist;	

	return %result;
}


sub testlogin {  
	my ($login, $pass, $dbh) = @_;
	my $pass_hash = md5_hex($pass);
	my $stmt = "SELECT role FROM persons WHERE login = '$login' AND pass = '$pass_hash'";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 1) {
		my @role = $sth->fetchrow_array();
		if ($role[0] eq 'w') {
			return 1;
		} else {
			return 0;
		}
	} else {
		$stmt = "SELECT role FROM persons WHERE login = '$login'";
		$sth = $dbh->prepare($stmt);
		$rv = $sth->execute() or die $DBI::errstr;
		if ($rv == 1) {
			return -2
		} else {		
			return -1;
		}
	}
}

sub new_person {  
	my ($login, $pass, $role, $dbh) = @_;
	my $pass_hash = md5_hex($pass);
	my $stmt = "INSERT INTO persons (login, pass, role) VALUES ('$login', '$pass_hash', '$role')";
	my $rv = $dbh->do($stmt) or die $DBI::errstr;
	if ($rv == 1) {
		return 1;
	} else {
		return 0;
	}
}

sub youtask {  
	my ($ntask, $dbh) = @_;
	my $stmt = "SELECT description FROM tasks WHERE id = $ntask";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	my @task = $sth->fetchrow_array();
	return $task[0];
}

sub assignedtask {
	my ($login, $idtask, $dbh) = @_;
	my $stmt = "SELECT id FROM persons WHERE login = '$login'";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	my @idperson = $sth->fetchrow_array();
	$stmt = "INSERT INTO assigned_tasks (id_person, id_task) VALUES ('$idperson[0]', '$idtask')";
	$rv = $dbh->do($stmt) or die $DBI::errstr;
	return 1;
}


sub testntask {
	my ($login, $ntask, $dbh) = @_;
	my $stmt = "SELECT id FROM assigned_tasks WHERE id NOT IN (SELECT id_assigned_task FROM fingerprints) AND (id_task = $ntask) AND id_person = (SELECT id FROM persons WHERE login = '$login')";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 0) {
		return (-1);	
	} else {
		my @res = $sth->fetchrow_array();
		return @res;
	}
}

sub testtests {
	my ($ntask, $dbh) = @_;
	my $stmt = "SELECT id FROM tests WHERE id_task = $ntask";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 0) {
		return 0;
	} else {
		return 1;
	}
}


sub filecompil {
	my ($login, $ntask) = @_;
	my $res = `gcc -c /home/app/files/$login-$ntask.c 2>&1`;
	return $res;
}


sub testfile {
	my ($login, $ntask, $dbh, $client) = @_;
	my $res = `gcc /home/app/files/$login-$ntask.c -o /home/app/files/$login-$ntask 2>&1`;
	if ($res eq "") {
		my $stmt = "SELECT input, output FROM tests WHERE id_task = $ntask";
		my $sth = $dbh->prepare($stmt);
		my $rv = $sth->execute() or die $DBI::errstr;
		while (my @tests = $sth->fetchrow_array()) {
			my $res_test = `echo $tests[0] | /home/app/files/$login-$ntask`; 
			if ($res_test eq $tests[1]) {
				$res = `rm /home/app/files/$login-$ntask`;
				$res = `rm /home/app/files/$login-$ntask.c`;
				print $client "Test faild. Input data: $tests[0]\n";
				return 0;
			}
		}
		$res = `rm /home/app/files/$login-$ntask`;
		print $client "Tests passed\n";
		return 1;
	} else {
		return 0;
	}
}

sub substringmax {
	my ($myfingerprint, @fingerprint) = @_;
	my @substringmax = @fingerprint;
	splice(@fingerprint, 3, 3);
	splice(@substringmax, 0, 3);	
	my @substring = CSS_Sorted($myfingerprint, $fingerprint[0]);
	if (length $substring[0][0] > length $substringmax[0]) {
		@substringmax = ($substring[0][0], $fingerprint[1], $fingerprint[2]);
	} elsif ((length $substring[0][0]) == (length $substringmax[0]) and $fingerprint[2] > $substringmax[1]) {
		@substringmax = ($substring[0][0], $fingerprint[1], $fingerprint[2]);
	}
	return @substringmax;
}


sub proc {
	my ($myfingerprint, @substringamax) = @_;
	my $proc = 100 * (1 - (length $substringamax[0])/(length $myfingerprint));
	return $proc;
}


sub wbdfin{
	my ($idastask, $uniq, $fingerprint, $idfingerprint, $dbh) = @_;
	my $time = localtime;
        my $stmt = "INSERT INTO fingerprints (id_assigned_task, date, uniqueness, fingerprint) VALUES ($idastask, '$time', $uniq, '''$fingerprint''') RETURNING id";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;	
	my @id_fingerprint = $sth->fetchrow_array();
	if ($idfingerprint == -1) {
		$stmt = "INSERT INTO fingerprint_fingerprint (id_fingerprint, id_fingerprint_for_comparison) VALUES ($id_fingerprint[0], $id_fingerprint[0])";
		$rv = $dbh->do($stmt) or die $DBI::errstr;
	} else {
		$stmt = "INSERT INTO fingerprint_fingerprint (id_fingerprint, id_fingerprint_for_comparison) VALUES ($id_fingerprint[0], $idfingerprint)";
		$rv = $dbh->do($stmt) or die $DBI::errstr;
	}
}

sub wfingerprint {
	my ($login, $ntask, $idastask, $dbh) = @_;
	my $code = `cat /home/app/files/$login-$ntask.c`;
	my $res = `rm /home/app/files/$login-$ntask.c`;
	my %mfingerprint = fingerprint($code);
	my $mfingerprint = $mfingerprint{fingerprints};
	my $stmt = "SELECT fingerprint, uniqueness, id FROM fingerprints WHERE id_assigned_task IN (SELECT id FROM assigned_tasks WHERE id_task = $ntask)";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	my @substringamax = ('', 0, -1); 
	if ($rv == 0) {
		wbdfin($idastask, 100, $mfingerprint, -1, $dbh);
		return 100;
	} else {
		while (my @fingerprint = $sth->fetchrow_array()) {
			@substringamax = substringmax($mfingerprint, @fingerprint, @substringamax);
		}
	}
	my $proc = proc($mfingerprint, @substringamax);
	if ($proc < 80) {
		return $proc;
	} else {
		wbdfin($idastask, $proc, $mfingerprint, $substringamax[2], $dbh);
		return $proc;
	}
}


sub passfile {
	my ($login, $ntask, $client) = @_;
	open FILE, ">> /home/app/files/$login-$ntask.c";
	LOOP: while (<$client>) {
		last LOOP if $_ eq "\n";
		print FILE $_;
	}
	close FILE;
}

sub if_succes {
	my ($ntask, $dbh) = @_;
	my $stmt = "SELECT phrase FROM tasks WHERE id = $ntask";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	my @phrase = $sth->fetchrow_array();
	return $phrase[0];
}

sub about_task {
	my ($ntask, $login, $dbh) = @_;
	my $stmt = "SELECT id, description, phrase FROM tasks WHERE id = $ntask AND id_person = (SELECT id FROM persons WHERE login = '$login')";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 0) {
		return (-1);
	} else {
		my @task = $sth->fetchrow_array();
		return @task;
	}
}

sub isadmin {
	my ($login, $client, $dbh) = @_;
	print $client "Hello, $login. What do you do?\n1)Put task.\n2)Put test.\n3)Viwe your task\n";
	my $answer = <$client>;
	if ($answer =~ /^1$/) {
		print $client "Enter task text:\n";
		my $task = '';
		LOOP: while (<$client>) {
			last LOOP if $_ eq "\n";
			$task = $task . $_;
		}
		chomp($task);
		print $client "What do you want to say to the person who decides this task?\n";
		my $phrase = <$client>;
		chomp($phrase);
		my $res = addtask($task, $login, $phrase, $dbh); 
		print $client "Task added. Number: $res.\n";
	} elsif ($answer =~ /^2$/) {
		print $client "Enter task number:\n";
		my $ntask = <$client>;
		chomp($ntask);
		if ($ntask =~ /^\d+$/) {
			print $client "Input data:\n";
			my $input = <$client>;
			chomp($input);
			print $client "Output data:\n";
			my $output = <$client>;
			chomp($output);
			my $res = addtest($login, $ntask, $input, $output, $dbh); 
			if ($res == 0) {
				print $client "This is not your task\n";
			} else {
				print $client "Test successfully added\n"
			}
		} else {
			print $client "Incorrect data\n";
		}
	} elsif ($answer =~ /^3$/) {
		print $client "Enter task number:\n";
		my $ntask = <$client>;
		chomp($ntask);
		if ($ntask =~ /^\d+$/) {
			my @task = about_task($ntask, $login, $dbh);
			if ($task[0] == -1) {
				print $client "This is not your task\n";
			} else {
				print $client "Text task: $task[1], phrase: $task[2]\n";
			}
		} else {
			print $client "Incorrect data\n";
		}
	} else {
		print $client "Incorrect data\n";
	}
}

sub list_tasks {
	my ($login, $dbh) = @_;
	my $stmt = "SELECT id FROM tasks WHERE id NOT IN (SELECT id_task FROM assigned_tasks WHERE id_person = (SELECT id FROM persons WHERE login = '$login'))";
	my $sth = $dbh->prepare($stmt);
	my $rv = $sth->execute() or die $DBI::errstr;
	if ($rv == 0) {
		return (-1);
	} else {
		my @task_list;
		while (my @id_tasks = $sth->fetchrow_array()) {
			push @task_list, $id_tasks[0];
		}
		return @task_list;
	}
}

sub ifperson {
	my ($login, $client, $dbh) = @_;
	print $client "Hello, $login. What do you do?\n1)Get task.\n2)Pass task.\n";
	my $answer = <$client>;

	if ($answer =~ /^1$/) {
		my @task = list_tasks($login, $dbh);
		if ($task[0] == -1) {
			print $client "There are no tasks for you\n";
			return 0;
		} else {
			print $client "Available tasks for you:\n";
			foreach my $i (@task) {
				print $client "$i "; 
			}
		}
		print $client "\nEnter task number\n";
		my $ntask = <$client>;
		chomp $ntask;
		if ($ntask =~ /^\d+$/) {
			my $index = List::MoreUtils::first_index {$_ eq $ntask} @task;
			if ($index != -1) {
				my $description_task = youtask($ntask, $dbh);
				assignedtask($login, $ntask, $dbh);
				print $client "Number task: $ntask, text:\n$description_task\n";
			} else {
				print $client "There is no such task\n";
			}	
		} else {
			print $client "Incorrect data\n";
		}
	} elsif ($answer =~ /^2$/) {
		print $client "Enter task number\n";
		my $ntask = <$client>;
		chomp $ntask;
		if ($ntask =~ /^\d+$/) {		
			my @res = testntask($login, $ntask, $dbh); 
			if ($res[0] == -1) {	
				print $client "This is not your task\n";
				return 0;
			}
			my $res2 = testtests($ntask, $dbh);
			if ($res2 == 0) {
				print $client "Check impossible - no tests for this task. Try later\n";
				return 0;
			} 
			print $client "Paste your code:\n";
			passfile($login, $ntask, $client);
			my $res = filecompil($login, $ntask);
			if ($res eq '') {
				my $res2 = `rm /home/app/$login-$ntask.o`;
				$res = testfile($login, $ntask, $dbh, $client); # person.pl
				if ($res == 1) {
					$res = wfingerprint($login, $ntask, $res[0], $dbh); # person.pl
					if ($res < 80) {
						print $client "Not unique enough. Percent: $res\n";
						return 0;
					}
					print $client "Task is accepted. Percent: $res\n";
					$res = if_succes($ntask, $dbh);
					print $client "$res\n";
				} else {
					print $client "Error when building a binary file\n";
				}
			} else {
				print $client "Your compile error:\n $res\n";
				$res = `rm /home/app/files/$login-$ntask.c`;
			}
		} else {
			print $client "Incorrect data\n";
		}
	} else {
		print $client "Incorrect data\n";
	}
}

sub new_role {
	my ($count, $login, $pass, $client, $dbh) = @_;
	if ($count != 3) { 
		print $client "What is your role? Writer (w), reader (r):\n";
		my $role = <$client>;
		chomp($role);
		$count += 1;
		if (($role eq "w") or ($role eq "r")) {
			my $res = new_person($login, $pass, $role, $dbh);
			if ($role eq 'w') {
				isadmin($login, $client, $dbh); 
			} else {
				ifperson($login, $client, $dbh);
			}
		} else {
			print $client "\nIncorrect data. Repeat entry:\n";
			new_role($count, $login, $pass, $client, $dbh);
		}
	} else { 
		return 0;
	}
}

sub server {
	my $client = shift;
	my $driver   = "Pg"; 
	my $database = "my_service";
	my $userid = "postgres"; 
	my $password = "sibirwtf2018"; 
	my $dbport = '5432';
	my $dsn = "DBI:$driver:database=$database;host=perl_db";
	my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;
	try {
		print $client "You login:\n";
		my $login = <$client>;
		chomp($login);
		print $client "You pass:\n";
		my $pass = <$client>;
		chomp($pass);
		my $res = testlogin($login, $pass, $dbh);
		if ($res == 1) {
			isadmin($login, $client, $dbh); 
		} elsif ($res == 0) {
			ifperson($login, $client, $dbh);
		} elsif ($res == -1) {
			new_role(0, $login, $pass, $client, $dbh);
		} else {
			print $client "Incorrect password\n";
		}
		print $client "Press ctrl+c for exit\n";
		return 0;
	}
	catch {
		print $@;		
		return 0;
	}
	
}

sub handle_connection {
	my $socket = IO::Socket::INET->new(
	        LocalPort => 8080,
		Proto     => "tcp",
        	Type      => SOCK_STREAM,
	        Reuse     => 1,
	        Listen    => 100,
	) or die "error $!\n";

	while (my $client = $socket->accept()) {
		async(\&server, $client)->detach;
	}
	close($socket);
	return 0;
}

sub main {
	handle_connection();
}

&main() unless caller;
