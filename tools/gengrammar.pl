#!/usr/bin/perl -W
use strict;
use v5.10;

my @funbuiltins;
for my $pirfile (<src/builtins/*.pir>){
	open my $fh, "<", $pirfile
		or die "Could not open '$pirfile': $!";

	for my $line (<$fh>){
		push @funbuiltins, $1 if $line =~ /.sub ['"]([^\.\@\!\^'"][^'"]*)['"]/;
	}
}

@funbuiltins = sort {length $b <=> length $a} @funbuiltins;
chomp @funbuiltins;
my $gengrammar = join "\t| ", map {$_ . " {*}\n"} @funbuiltins;

for (<DATA>){
	s/===BUILTINS===/$gengrammar/ if $_ eq "\t|===BUILTINS===\n";
	print;
}


__DATA__
# $Id$

#=begin overview

#This is the grammar for fun written as a sequence of Perl 6 rules.

#=end overview

grammar fun::Grammar is PCT::Grammar;

rule TOP {
	[<func>|<expr>]*
	[ $ || <panic: 'Syntax error'> ]
	{*}
}

##  this <ws> rule treats # as "comment to eol"
##  you may want to replace it with something appropriate
token ws {
    <!ww>
    [ '#' \N* \n? | \s+ ]*
}

##'ident' sucks I want hyphens dammit.
token funcname { 
	[ \w | '-' | '?' | '=' <!before '='> ]+ {*}
}

token print {
	'.'	{*}
}

##These arent really expressions but whatever.
rule expr {
##Fundamental stuff
	| <list>	{*} #= list
	| <value>	{*} #= value
	| <print>	{*} #= print

##Built in functions
	| <builtins> {*} #= builtins
	
##Possibly a user function call (this is the 'last resort' match)
	|| <userfunccall>	{*} #= userfunccall
}

##The function is trechnically a list, but "<ident> == <list>" adds an extra (unnecessary) layer,
##because I have to dig <expr> out of the <list>
rule func {
	| '[' <expr>* ']' <funcname> '==' {*}
	| <funcname> '[' <expr>* ']' '==' {*}
}

rule list { 
	'[' <expr>* ']' {*} 
}

token value {
	| <float> 	{*} #= float
	| <integer>	{*} #= integer
	| <string> 	{*} #= string
	| <bool> 	{*} #= bool
}

token integer { '-'? \d+ {*} }
token float { '-'? \d* '.' \d+ {*} }
token bool { ['true' | 'false'] {*} }
token string {
    [ \' <string_literal: '\'' > \' | \" <string_literal: '"' > \" ]
    {*}
}

token builtins {
	[
	|===BUILTINS===
	] <?before [ \s | '[' | ']' | '.' ]>
}

token userfunccall {
	<funcname> {*}
}