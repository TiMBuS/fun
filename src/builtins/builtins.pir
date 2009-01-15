=head1 Builtins

General purpose functions

=head2 Functions

=over 4

=cut

.namespace[]

=item '.'

The dot. This is the only function that is not pushed into the stack. When a '.' is hit in your program, the stack will execute down and functions will be ran as they are hit. By default, the remaining value left on the stack once execution is halted will be popped off and printed to stdout, followed by a newline.
In the future, the result behaviour of the dot may be customizable, which is why it is not in the IO section.

=cut

.sub '.'
	.local pmc stack, isempty
	stack = get_global 'funstack'
	isempty = stack.'run'()
	if isempty goto finish
	
	##Make this a hook or something? Dunno. 
	#Consider: What would the hook be written in? C? pir? fun?
	'put'()
	
#	stack.'dump'()
	
finish:
.end

=item argc

  ->  I

Pushes the number of arguments passed to the program.

=cut

.sub 'argc'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = get_global 'args'
	$I0 = $P0
	stack.'push'($I0)
.end

=item argv

  ->  A

Creates an aggregate A containing the program's command line arguments.

=cut

.sub 'argv'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = get_global 'args'
	$P1 = new 'List'
	$P1.'append'($P0)
	stack.'push'($P1)
.end

=item getenv

 V  ->  S

Retrieves the string value S of the named environment variable V.

=cut

.sub 'getenv'
	.local pmc stack
	stack = get_global 'funstack'
	$S0 = stack.'pop'('String')
	$P0 = new 'Env'
	$S0 = $P0[$S0]

	.tailcall stack.'push'($S0)
.end

=item time

  ->  I

Pushes the integer value of time in seconds since the epoch.

=cut

.sub 'time'
	.local pmc stack
	stack = get_global 'funstack'
	$I0 = time
	stack.'push'($I0)
.end

=item localtime

 I  ->  T

Converts a time I into a list T representing local time:
[second minute hour day month year weekday yearday isdst].
Month is 1 = January ... 12 = December; isdst is a Boolean flagging daylight savings/summer time; weekday is 0..6, where 0 is Sunday.

=cut

.sub 'localtime'
	.local pmc stack
	stack = get_global 'funstack'
	$I0 = stack.'pop'('Integer')
	$P0 = decodelocaltime $I0
	#P0 is a Array, we need to turn it into a List
	$P1 = new 'List'
	$P1.'append'($P0)
	#The last part of the array needs to be a boolean, not an int.
	$I0 = $P1[8]
	$P0 = new 'Boolean'
	$P0 = $I0
	$P1[8] = $P0
	.tailcall stack.'push'($P1)
.end

=item gmtime

 I  ->  T

Converts a time I into a list T representing universal time:
[second minute hour day month year weekday yearday isdst].
Month is 1 = January ... 12 = December; isdst is false; weekday is 0..6, where 0 is Sunday.

=cut

.sub 'gmtime'
	.local pmc stack
	stack = get_global 'funstack'
	$I0 = stack.'pop'('Integer')
	$P0 = decodetime $I0
	#P0 is a Array, we need to turn it into a List
	$P1 = new 'List'
	$P1.'append'($P0)
	#The last part of the array needs to be a boolean, not an int.
	$I0 = $P1[8]
	$P0 = new 'Boolean'
	$P0 = $I0
	$P1[8] = $P0
	.tailcall stack.'push'($P1)
.end

=item mktime

 T  ->  I

Converts a list T representing local time into a time I. T is in the format generated by localtime.

=cut

.sub 'mktime'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'('List')
	$I0 = $P0
	if $I0 < 9 goto list_too_small
	$I0 = mktime $P0
	.tailcall stack.'push'($I0)
	
list_too_small:
	die "The given time list was invalid"
.end

=item strftime

 T S1  ->  S2

Formats a list T in the format of localtime or gmtime using string S1 and pushes the result S2.
This currently uses the C function strftime, so please make sure that the format string is safe, and the list T is correctly composed.

=cut

#TODO: Consider turning this into a pure pir function instead of using the C std.
.sub 'strftime'
	.local pmc stack
	stack = get_global 'funstack'
	$S0 = stack.'pop'('String')
	$P0 = stack.'pop'('List')
	$I0 = $P0
	if $I0 < 9 goto list_too_small
	$S0 = strftime $S0, $P0
	.tailcall stack.'push'($S0)
	
list_too_small:
	die "The given time list was invalid"
.end

=item format

 L F  ->  S

Will format either a single number or list of numbers L according to the format string F to produce string S.
The format string is the same as used by sprintf. Length specifiers are not required.

=cut

.sub 'format'
	.local pmc stack
	.local string formatstr
	stack = get_global 'funstack'
	formatstr = stack.'pop'('String')
	($P0, $S0) = stack.'pop'('List', 'Integer', 'Float')
	
	if $S0 == 'List' goto formatlist
	
	$P1 = new 'List'
	$P1[0] = $P0
	$P0 = $P1
	
formatlist:
	$S0 = sprintf formatstr, $P0
	.tailcall stack.'push'($S0)
.end

=item strtol

 S I  ->  J

String S is converted to the integer J using base I.
If I is 0, it is automatic. strtol will assume normally base 10, but a leading "0" will assume base 8 and leading "0x" will assume base 16.
If you don't need any kind of special base for conversion, consider using L<toint>

=cut

.sub 'strtol'
	.local pmc stack
	stack = get_global 'funstack'
	$I0 = stack.'pop'('Integer')
	$S0 = stack.'pop'('String')
	$I0 = strtol $S0, $I0
	.tailcall stack.'push'($I0)
.end

=item strtod

 S  ->  F

String S is converted to the float F

=cut

.sub 'strtod'
	.local pmc stack
	stack = get_global 'funstack'
	$S0 = stack.'pop'('String')
	$N0 = $S0
	.tailcall stack.'push'($N0)
.end

=item toint

 X  ->  I

X is converted to the integer I.

=cut

.sub 'toint'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'()
	$I0 = $P0
	.tailcall stack.'push'($I0)
.end

=item tonum

 X  ->  F

X is converted to the float F.

=cut

.sub 'tonum'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'()
	$N0 = $P0
	.tailcall stack.'push'($N0)
.end


=item tostr

 X  ->  S

X is converted to the string S.

=cut

.sub 'tostr'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'()
	$S0 = '!@mkstring'($P0)
	.tailcall stack.'push'($S0)
.end

=item tochar

 X  ->  C

X is converted to the char C. 
A list or string will be converted by getting the length, and converting it to an ascii char. This function does not act in the same way as C<chr>

=cut

.sub 'tochar'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'()
	$I0 = $P0
	$P0 = new 'Char'
	$P0 = $I0
	.tailcall stack.'push'($P0)
.end

=item maxint

 ->  maxint

Pushes largest integer possible.

=cut

.sub 'maxint'
	.local pmc stack
	stack = get_global 'funstack'
	$I0 = maxint
	.tailcall stack.'push'($I0)
.end


=item typeof

 X  ->  S

Value X is popped from the stack and the string representation of its type is pushed.

=cut

.sub 'typeof'
	.local pmc stack, symbol
	stack = get_global 'funstack'
	($P0, $S0) = stack.'pop'()
	stack.'push'($S0)
.end

=item name

 sym  ->  "sym"

For functions, the string "sym" is the name of item sym, for literals sym the result string is its type.
Because it has to directly pop a function without evaluating it, it currently does not work well with continuations. Do not try to use it in a continuation to pull an argument from a previous stack (ie C<symbol [name] nullary> will not work. C<[symbol name] nullary> is fine). This should be fixed in the future, but it's low priority.

=cut

.sub 'name'
	.local pmc stack, symbol
	stack = get_global 'funstack'
	#We need to grab the symbol -without- evaluating it.
	symbol = stack.'pop_raw'()
	
	$S0 = typeof symbol
	
	if $S0 == "Sub" goto push_symbol
	if $S0 == "Closure" goto push_symbol
	if $S0 == 'DelayedSub' goto push_symbol
	.tailcall stack.'push'($S0)

push_symbol:
	$S0 = symbol
	.tailcall stack.'push'($S0)
.end

=item intern

 "sym"  -> sym

Pushes the item whose name is "sym". Will only work for individual symbols, not code. Use eval to parse code strings. This function mainly has the advantage of not needing the parser & compiler, making it very fast compared to eval.

=cut

.sub 'intern'
	.local pmc stack
	stack = get_global 'funstack'
	$S0 = stack.'pop'('String')
	$P0 = get_global $S0
	if null $P0 goto not_found
	.tailcall stack.'push'($P0)
	
not_found:
	$S1 = "Symbol '"
	$S1 .= $S0
	$S1 .= "' is undefined."
	die $S1
.end

=item body

 U  ->  [P]

Quotation [P] is the body of user-defined symbol U.

=cut

.sub 'body'
	.local pmc stack, symbol
	stack = get_global 'funstack'
	
	#We need to grab the symbol -without- evaluating it.
	symbol = stack.'pop_raw'()
	symbol('build' => 1)
	$S0 = symbol
	$S0 = concat '!usrfnlist', $S0
	$P0 = get_global $S0
	stack.'push'($P0)
.end

=item gc

  ->

Initiates garbage collection.

=cut

.sub 'gc'
	collect
.end

=item include

 "filename"  ->

Loads and runs a joy source file with the name "filename". You do not need to specify the filename extension if it is of the type .fun, .pir, or .pbc
This is done to allow for precompiled modules.

=cut

.sub 'include'
	.local pmc stack
	stack = get_global 'funstack'

	.local int iscompiled, noext
	iscompiled = 1
	noext = 0
	
	.local string name
	name = stack.'pop'('String')
	$I0 = length name
	if $I0 <= 5 goto no_ext
	
	substr $S0, name, -4
	if $S0 == '.pbc' goto already_compiled
	if $S0 == '.pir' goto already_compiled
	if $S0 == '.fun' goto has_ext

  no_ext:
	noext = 1
  has_ext:
	iscompiled = 0
  already_compiled:
 	##  loop through inc
#	.local pmc inc_it
#	$P0 = get_hll_global '@INC'
#	inc_it = iter $P0
#  inc_loop:
#	unless inc_it goto inc_end
	.local string basename, realfilename
#	$S0 = shift inc_it
#	basename = concat $S0, '/'
#	basename .= name
	basename = name

	if noext goto check_noext

  check_withext:
	realfilename = basename
	$I0 = stat realfilename, 0
#	unless $I0 goto inc_loop
	unless $I0 goto inc_end
	if iscompiled goto eval_parrot
	goto eval_fun

  check_noext:
	realfilename = concat basename, '.pbc'
	$I0 = stat realfilename, 0
	if $I0 goto eval_parrot
	realfilename = concat basename, '.pir'
	$I0 = stat realfilename, 0
	if $I0 goto eval_parrot
	realfilename = concat basename, '.fun'
	$I0 = stat realfilename, 0
	if $I0 goto eval_fun
#	goto inc_loop
  inc_end:
	$S0 = concat "Can't find module or file '", basename
	$S0 .= "'"
	$P0 = new 'Exception'
	$P0 = $S0
	throw $P0
	.return ()

  eval_parrot:
	load_bytecode realfilename
	.return (1)
  eval_fun:
	.local pmc compiler
	compiler = compreg 'fun'
	.tailcall compiler.'evalfiles'(realfilename)
.end

=item ban-space-kimchi

 ->  S

The function everyone wants implemented.

=cut

.sub 'ban-space-kimchi'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = new 'String'
	$P0 = "He sucks."
	stack.'push'($P0)
.end

=back

