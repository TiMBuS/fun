=head1 TITLE

Stack.pir

=head1 DESCRIPTION

Stack class for the 'fun' language.
Handles pop/push, and continuations(stack copies).

=cut

.namespace ['Stack']

.sub onload :anon :init :load
	.local pmc class
	class = newclass 'Stack'
	addattribute class, 'topcc'
	addattribute class, 'rootcc'
.end

.sub init :vtable :method
	$P0 = new 'Stack::Continuation'
	
	setattribute self, 'topcc', $P0
	setattribute self, 'rootcc', $P0
.end

.sub get_integer :vtable :method
	$P0 = getattribute self, 'rootcc'
	$I0 = $P0
	.return($I0)
.end

##Stack manipulation:
.sub 'pop' :method
	.param pmc args :slurpy
	.local pmc currentc, value
	.local int argc
	.local string type
	
	currentc = getattribute self, 'topcc'
	value = currentc.'pop'()
	type = typeof value
	
	#No args means no typechecking.
	argc = args
	unless argc goto finish
	
	.local pmc it
	it = iter args
iter_loop:
	unless it goto typefail
	$S0 = shift it
	if $S0 == type goto finish
	goto iter_loop
	
finish:
	.return(value, type)

typefail:
	#May as well salvage what we can. ##Or maybe not.
	#self.'push'(value)
	#Die out.
	$S0 = "Bad type '"
	$S0 .= type
	$S0 .= "' popped from the stack.\nWas expecting type '"
	
	$S2 = args.'pop'()
	unless args goto just_one
	$S1 = join "', '", args
	$S0 .= $S1
	$S0 .= "' or '"
just_one:
	$S0 .= $S2

	$S0 .= "'."
	$P0 = new 'Exception'
	$P0 = $S0	
	throw $P0
	#die $S0
	.return()

.end

#Used to grab a value without running it.
.sub 'pop_raw' :method
	.local pmc currentc
	currentc = getattribute self, 'topcc'	
	.tailcall currentc.'pop_raw'()
.end

.sub 'run' :method
	#For now, no params.
	.local pmc currentc
	currentc = getattribute self, 'topcc'
	.tailcall currentc.'run'()
.end

.sub 'push' :method
	.param pmc args :slurpy
	.local pmc currentc
	
	currentc = getattribute self, 'topcc'
	
	##Not needed for now (Hopefully not needed ever).
	#currentc.'push'(args)
	
	$P0 = currentc.'getstack'()
	$P0.'append'(args)
.end

.sub 'getstack' :method
	.local pmc retstack
	retstack = new 'List'

	$P0 = getattribute self, 'topcc'
	$P0 = $P0.'getstack'()

	.local pmc it
	it = iter $P0
	it = 4 ##runtime/parrot/include/iterator.pasm:.macro_const ITERATE_FROM_END	4
iter_loop:
	unless it goto done
	$P0 = pop it
	retstack.'push'($P0)
	goto iter_loop
done:
	.return(retstack)
.end

.sub 'setstack' :method
	.param pmc newstack
	.local pmc revlist
	revlist = new 'List'
	
iter:
	unless newstack goto assign_stack
	$P0 = newstack.'pop'()
	revlist.'push'($P0)
	goto iter

assign_stack:
	$P0 = getattribute self, 'topcc'
	$P0 = $P0.'getstack'()
	assign $P0, revlist
.end

## Continuation-related stuff: ##
.sub 'makecc' :method
	.local pmc oldcc, newcc
	newcc = new 'Stack::Continuation'
	oldcc = getattribute self, 'topcc'
	
	newcc.'setparent'(oldcc)
	
	$I0 = oldcc
	newcc.'setposition'($I0)
	
	setattribute self, 'topcc', newcc
.end

.sub 'exitcc' :method
	#Basically: topcc = topcc->parent
	
	$P0 = getattribute self, 'topcc'
	$P0 = $P0.'getparent'()
	if null $P0 goto no_stack
	setattribute self, 'topcc', $P0
	.return()

no_stack:
	die "Fatal Error: No prior continuation found!"
.end

.sub 'dump' :method
	.local pmc currentc
	currentc = getattribute self, 'topcc'
	
	print "stackdump:\n"
loop:
	$P0 = currentc.'getstack'()
	$S0 = '!@mkstring'($P0)
	print $S0
	print "\n"
	currentc = currentc.'getparent'()
	if null currentc goto finish
	goto loop
finish:
.end

