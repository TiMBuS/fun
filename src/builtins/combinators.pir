=head1 Combinators

These functions are designed to manipulate the way functions are composed and executed.
They are similar to code flow functions, except they focus more on execution style, rather than choices.

=head2 Functions

=over 4

=cut


=item i

 [P]  ->  ...

Executes the list C<P>

=cut

.sub 'i'
	.local pmc list, stack
	
	stack = get_hll_global ['private'], 'funstack'
	list = stack.'pop'('List')
	stack.'push'(list :flat)

.end

=item x

 [P]  ->  [P] ...

Executes the list C<P> without removing it from the stack

=cut

.sub 'x'
	.local pmc list, listcpy, stack
	
	stack = get_hll_global ['private'], 'funstack'
	list = stack.'pop'('List')
	listcpy = '!@deepcopy'(list)
	stack.'push'(list, listcpy :flat)

.end

=item dip

 X [P] ->  ... X

Saves C<X>, executes C<P>, pushes C<X> back.

=cut

.sub 'dip'
	.local pmc stack
	stack = get_hll_global ['private'], 'funstack'
	$P0 = stack.'pop'('List')
	$P1 = stack.'pop'()
	
	stack.'push'($P0 :flat, $P1)

.end

=item stack

 .. X Y Z  ->  .. X Y Z [Z Y X ..]

Pushes the current continutations' stack as a list. The top of the stack will be at the head of the list.

=cut

.sub 'stack'
	.local pmc stack
	.local pmc stacklist
	stack = get_hll_global ['private'], 'funstack'
	#Getstack uses getat(), which makes a copy of each element, so no need to make any copies.
	stacklist = stack.'getstack'()
	stacklist = '!@deepcopy'(stacklist)
	stack.'push'(stacklist)
.end

=item unstack

 [X Y Z ..]  ->  .. Z Y X

The list C<[X Y Z ..]> becomes the new stack. Setting a new stack inside a continuation will only make the continuation stack change.
Be wary when using this. 

=cut

.sub 'unstack'
	.local pmc stack
	.local pmc newstack
	stack = get_hll_global ['private'], 'funstack'
	
	newstack = stack.'pop'('List')
	.tailcall stack.'setstack'(newstack)
.end

=item infra

 L1 [P]  ->  L2

Using list L1 as stack, executes P and returns a new list L2.
The first element of L1 is used as the top of stack, and after execution of P the top of stack becomes the first element of L2.

=cut

.sub 'infra'
	.local pmc stack
	.local pmc p, li
	stack = get_hll_global ['private'], 'funstack'
	p  = stack.'pop'('List')
	li = stack.'pop'('List')
	
	$P0 = new 'EOSMarker'
	li.'push'($P0)
	
	stack.'makecc'()
	stack.'setstack'(li)
	stack.'push'(p :flat)
	stack.'run'()
	li = stack.'getstack'()
	stack.'exitcc'()

	$P0 = li[-1]
	$S0 = typeof $P0
	if $S0 != "EOSMarker" goto just_push
	li.'pop'()
just_push:
	.tailcall stack.'push'(li)
.end

=item construct

 [P] [[P1] [P2] ..]  ->  R1 R2 ..

Makes a new contination and then executes [P] in it.
Each [Pi] will then be executed in its own continuation on top of the [P] continuation, giving the single value Ri, which will be saved and pushed onto the original stack.

=cut

.sub 'construct'
	.local pmc stack
	.local pmc p, plist, rlist
	stack = get_hll_global ['private'], 'funstack'
	plist = stack.'pop'('List')
	p = stack.'pop'('List')
	
	rlist = new 'List'
	
	stack.'makecc'()
	stack.'push'(p :flat)
	
ploop:
	unless plist goto finish
	$P0 = plist.'shift'()
	$S0 = typeof $P0
	unless $S0 == 'List' goto type_error
	
	stack.'makecc'()
	stack.'push'($P0 :flat)
	$P0 = stack.'pop'()
	rlist.'push'($P0)
	stack.'exitcc'()
	goto ploop

finish:
	stack.'exitcc'()
	.tailcall stack.'push'(rlist :flat)

type_error:
	$P0 = new 'Exception'
	.local string errmsg
	errmsg = "Bad type '"
	errmsg .= $S0
	errmsg .= "' popped from the stack.\nWas expecting type 'List'."
	$P0 = errmsg
	throw $P0
.end

=item times

 N [P]  ->  ...

Executes C<P>, C<N> times

=cut

.sub 'times'
	.local pmc stack
	.local pmc p
	.local int n
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	n = stack.'pop'('Integer')
	
	$I0 = 0
times_loop:
	if $I0 == n goto loop_end
	$P0 = '!@deepcopy'(p)
	stack.'push'($P0 :flat)
	stack.'run'()
	inc $I0
	goto times_loop
loop_end:
.end

=item primrec

 X [I] [C]  ->  R

Executes I to obtain an initial value R0.
For integer X uses increasing positive integers to X, combines by C for new R.
For aggregate X uses successive members and combines by C for new R.

=cut

.sub 'primrec'
	.local pmc stack
	.local pmc i, c, x
	.local string type
	.local int count
	count = 0
	stack = get_hll_global ['private'], 'funstack'
	c = stack.'pop'('List')
	i = stack.'pop'('List')
	(x, type) = stack.'pop'('Integer', 'List', 'String')
	if type == 'List' goto list_loop
	if type == 'String' goto str_loop

int_loop:
	unless x > 0 goto combine
	inc count
	$I0 = x
	stack.'push'($I0)
	dec x
	goto int_loop

str_loop:
	x = '!@str2chars'(x)
list_loop:
	unless x goto combine
	inc count
	$P0 = shift x
	stack.'push'($P0)
	goto list_loop

combine:
	stack.'push'(i :flat)
combine_loop:
	unless count > 0 goto finish
	$P0 = '!@deepcopy'(c)
	stack.'push'($P0 :flat)
	stack.'run'()
	dec count
	goto combine_loop

finish:
.end

=item linrec

 [B] [T] [R1] [R2]  ->  ...

Executes C<B>. If that yields true, executes C<T>.
Else executes C<R1>, recurses, executes C<R2>.

NOTE: C<B> is executed within a new continuation, so that the test gobbles no value(s).

=cut

.sub 'linrec'
	.local pmc stack
	.local pmc reclist
	.local pmc p, t, r1, r2
	stack = get_hll_global ['private'], 'funstack'
	r2 = stack.'pop'('List')
	r1 = stack.'pop'('List')
	t = stack.'pop'('List')
	p = stack.'pop'('List')
	reclist = new 'List'
	
recurse:
	stack.'makecc'()
	$P0 = '!@deepcopy'(p)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	if $I0 goto do_true

	$P0 = '!@deepcopy'(r1)
	stack.'push'($P0 :flat)
	#This keeps the stack smaller.. makes functions run more 'in order' too for what that is worth..
	stack.'run'()
	
	$P0 = '!@deepcopy'(r2)
	reclist.'push'($P0)
	goto recurse
	
do_true:
	stack.'push'(t :flat)
	stack.'run'()

push_reclist:
	unless reclist goto finish
	$P0 = reclist.'shift'()
	stack.'push'($P0 :flat)
	stack.'run'()
	goto push_reclist

finish:
.end

=item condlinrec

 [ [C1] [C2] .. [D] ]  ->  ...

Each [Ci] is of the forms [[B] [T]] or [[B] [R1] [R2]].
Tries each B. If that yields true and there is just a [T], executes T and exit.
If there are [R1] and [R2], executes R1, recurses, executes R2.
Subsequent case are ignored. If no B yields true, then [D] is used.
It is then of the forms [[T]] or [[R1] [R2]]. For the former, executes T.
For the latter executes R1, recurses, executes R2.

=cut

.sub 'condlinrec'
	.local pmc stack
	.local pmc condlist, reclist
	.local pmc condit, testit
	stack = get_hll_global ['private'], 'funstack'
	condlist = stack.'pop'('List')
	unless condlist goto bad_list
	
	reclist = new 'List'
	
recurse:
	condit = iter condlist
	
iter_condlist:
	$P0 = shift condit
	$S0 = typeof $P0
	if $S0 != 'List' goto bad_list
	testit = iter $P0
	unless condit goto default
	
	$P0 = shift testit
	stack.'makecc'()
	$P0 = '!@deepcopy'($P0)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	if $I0 == 0 goto iter_condlist

default:
	#Change this to >2 if parrot fixes get_integer on iterators.
	$I0 = testit
	if $I0 > 3 goto bad_list

	#So just see if you can shift twice to determine if its recursive or not.
	
	$P0 = shift testit
	$P0 = '!@deepcopy'($P0)
	stack.'push'($P0 :flat)
	stack.'run'()
	unless testit goto reclist_push
	
	$P0 = shift testit
	$P0 = '!@deepcopy'($P0)
	reclist.'push'($P0)
	stack.'run'()
	goto recurse

reclist_push:
	unless reclist goto finish
	$P0 = reclist.'shift'()
	stack.'push'($P0 :flat)
	stack.'run'()
	goto reclist_push
finish:
	.return()

bad_list:
	$P0 = new 'Exception'
	$P0 = "The given list is invalid."
	throw $P0
.end

=item binrec

 [B] [T] [R1] [R2]  ->  ...

Executes C<B>. If that yields true, executes C<T>.
Else uses C<R1> to produce two intermediates, recurses twice,
then executes C<R2> (usually to combine their results).

NOTE: C<B> is executed within a new continuation, so that the test gobbles no value(s).

=cut

.sub 'binrec'
	.local pmc stack
	.local pmc p, t, r1, r2
	.local pmc vallist, reclist
	stack = get_hll_global ['private'], 'funstack'
	r2 = stack.'pop'('List')
	r1 = stack.'pop'('List')
	t = stack.'pop'('List')
	p = stack.'pop'('List')
	
	reclist = new 'List'
	vallist = new 'List'

recurse_one:
	stack.'makecc'()
	$P0 = '!@deepcopy'(p)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	
	if $I0 goto do_true
	
	$P0 = '!@deepcopy'(r1)
	stack.'push'($P0 :flat)
	#Save the second of the values to use after the first recursion halts.
	$P0 = stack.'pop'()
	vallist.'push'($P0)
	
	goto recurse_one

do_true:
	$P0 = '!@deepcopy'(t)
	stack.'push'($P0 :flat)

	unless vallist goto reclist_push
	$P0 = vallist.'pop'()
	stack.'push'($P0)
	
	$P0 = '!@deepcopy'(r2)
	reclist.'push'($P0)
	goto recurse_one
	
reclist_push:
	unless reclist goto finish
	$P0 = reclist.'shift'()
	stack.'push'($P0 :flat)
	stack.'run'()
	goto reclist_push

finish:
.end

=item tailrec

 [B] [T] [R1]  ->  ...

Executes P. If that yields true, executes T.
Else executes R1, recurses.

=cut

.sub 'tailrec'
	.local pmc stack
	.local pmc p, t, r1
	stack = get_hll_global ['private'], 'funstack'
	r1 = stack.'pop'('List')
	t = stack.'pop'('List')
	p = stack.'pop'('List')

rec_loop:
	stack.'makecc'()
	$P0 = '!@deepcopy'(p)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	if $I0 goto do_true
	
	$P0 = '!@deepcopy'(r1)
	stack.'push'($P0 :flat)
	stack.'run'()
	goto rec_loop
	
do_true:
	stack.'push'(t :flat)
	.tailcall stack.'run'()
.end

=item genrec

 [B] [T] [R1] [R2]  ->  ...

Executes C<P>, if that yields true executes C<T>.
Else executes C<R1> and then C<[[P] [T] [R1] [R2] genrec] R2>.

=cut

.sub 'genrec'
	.local pmc stack
	.local pmc p, t, r1, r2
	stack = get_hll_global ['private'], 'funstack'
	
	r2 = stack.'pop'('List')
	r1 = stack.'pop'('List')
	t = stack.'pop'('List')
	p = stack.'pop'('List')
	
	stack.'makecc'()
	$P0 = '!@deepcopy'(p)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	if $I0 goto do_true
	
	$P0 = '!@deepcopy'(r1)
	stack.'push'($P0 :flat)
	stack.'run'()

	$P0 = get_global "genrec"
	$P1 = '!@mklist'(p, t, r1, r2, $P0)
	stack.'push'($P1)


	$P0 = '!@deepcopy'(r2)
	stack.'push'($P0 :flat)
	.tailcall stack.'run'()
	
do_true:
	stack.'push'(t :flat)
	.tailcall stack.'run'()
.end

=item nullary

 [P]  ->  R

Begins a new continuation, then executes the list C<P>. The result of C<P> is copied back to the prior continuation.
The end result is that nothing is removed from the stack.

=cut

.sub 'nullary'
	.local pmc stack
	.local pmc p
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	stack.'makecc'()
	stack.'push'(p :flat)
	$P0 = stack.'pop'()
	stack.'exitcc'()
	stack.'push'($P0)
.end

=item unary

 X [P]  ->  R

Begins a new continuation, copies C<X> over to it, then executes the list C<P>. The result of C<P> is copied back to the prior continuation.
C<X> will always be removed.

=cut

.sub 'unary'
	.local pmc stack
	.local pmc p, x
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	x = stack.'pop'()
	stack.'makecc'()
	stack.'push'(x, p :flat)
	stack.'run'()
	$P0 = stack.'pop'()
	stack.'exitcc'()
	stack.'push'($P0)
.end

=item binary

 X Y [P]  ->  R

Begins a new continuation, copies C<X Y> over to it, then executes the list C<P>. The result of C<P> is copied back to the prior continuation.
C<X> and C<Y> will always be removed.

=cut

.sub 'binary'
	.local pmc stack
	.local pmc p, x, y
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	y = stack.'pop'()
	x = stack.'pop'()
	stack.'makecc'()
	stack.'push'(x, y, p :flat)
	$P0 = stack.'pop'()
	stack.'exitcc'()
	stack.'push'($P0)
.end

=item ternary

 X Y Z [P]  ->  R

Begins a new continuation, copies C<X Y Z> over to it, then executes the list C<P>. The result of C<P> is copied back to the prior continuation.
C<X>, C<Y> and C<Z> will always be removed.

=cut

.sub 'ternary'
	.local pmc stack
	.local pmc p, x, y, z
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	z = stack.'pop'()
	y = stack.'pop'()
	x = stack.'pop'()
	stack.'makecc'()
	stack.'push'(x, y, z, p :flat)
	$P0 = stack.'pop'()
	stack.'exitcc'()
	stack.'push'($P0)
.end

=item unary2

 X1 X2 [P]  ->  R1 R2

Executes P twice, with X1 and X2 on top of the stack. Returns the two values R1 and R2.

=cut

.sub 'unary2'
	.local pmc stack
	.local pmc p, pc, x1, x2
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	x2 = stack.'pop'()
	x1 = stack.'pop'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x1, pc :flat)
	stack.'run'()
	$P0 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	stack.'push'(x2, p :flat)
	stack.'run'()
	$P1 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'push'($P0, $P1)
.end

=item unary3

 X1 X2 X3 [P]  ->  R1 R2 R3

Executes P three times, with Xi, returns Ri (i = 1..3).

=cut

.sub 'unary3'
	.local pmc stack
	.local pmc p, pc, x1, x2, x3
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	x3 = stack.'pop'()
	x2 = stack.'pop'()
	x1 = stack.'pop'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x1, pc :flat)
	stack.'run'()
	$P0 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x2, pc :flat)
	stack.'run'()
	$P1 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	stack.'push'(x3, p :flat)
	stack.'run'()
	$P2 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'push'($P0, $P1, $P2)
.end

=item unary4

 X1 X2 X3 X4 [P]  ->  R1 R2 R3 R4

Executes P four times, with Xi, returns Ri (i = 1..4).

=cut

.sub 'unary4'
	.local pmc stack
	.local pmc p, pc, x1, x2, x3, x4
	stack = get_hll_global ['private'], 'funstack'
	p = stack.'pop'('List')
	x4 = stack.'pop'()
	x3 = stack.'pop'()
	x2 = stack.'pop'()
	x1 = stack.'pop'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x1, pc :flat)
	stack.'run'()
	$P0 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x2, pc :flat)
	stack.'run'()
	$P1 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	pc = '!@deepcopy'(p)
	stack.'push'(x3, pc :flat)
	stack.'run'()
	$P2 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'makecc'()
	stack.'push'(x4, p :flat)
	stack.'run'()
	$P3 = stack.'pop'()
	stack.'exitcc'()
	
	stack.'push'($P0, $P1, $P2, $P3)
.end

=item while

 [B] [D]  ->  ...

While executing C<B> yields true executes C<D>.

=cut

.sub 'while'
	.local pmc stack
	.local pmc b, d
	stack = get_hll_global ['private'], 'funstack'
	d = stack.'pop'('List')
	b = stack.'pop'('List')

loop:
	stack.'makecc'()
	$P0 = '!@deepcopy'(b)
	stack.'push'($P0 :flat)
	$I0 = stack.'pop'('Boolean')
	stack.'exitcc'()
	if $I0 == 0 goto finish
	
	$P0 = '!@deepcopy'(d)
	stack.'push'($P0 :flat)
	stack.'run'()
	goto loop
	
finish:
.end

=item cleave

 X [P1] [P2]  ->  R1 R2

Executes C<P1> and C<P2>, each with C<X> on top, producing two results.

=cut

.sub 'cleave'
	.local pmc stack
	.local pmc x, p1, p2, r1, r2
	stack = get_hll_global ['private'], 'funstack'
	p2 = stack.'pop'('List')
	p1 = stack.'pop'('List')
	x = stack.'pop'()
	#Make a copy of 'x' since it will be ran twice
	$P0 = '!@deepcopy'(x)
	
	#Make a cc to contain any possible overflow, then run p1
	stack.'makecc'()
	stack.'push'($P0, p1 :flat)
	r1 = stack.'pop'()
	stack.'endcc'()
	
	#Now run p2
	stack.'makecc'()
	stack.'push'(x, p2 :flat)
	r2 = stack.'pop'()
	stack.'endcc'()
	
	stack.'push'(r1, r2)
.end

=item treestep

 T [P]  ->  ...

Recursively traverses leaves of tree T, executes P for each leaf.

=cut

.sub 'treestep'
	.local pmc stack
	.local pmc p, t, tlist
	stack = get_hll_global ['private'], 'funstack'
	
	p = stack.'pop'('List')
	t = stack.'pop'('List')
	tlist = new "List"
	
loop:
	unless t goto travel_up
	$P0 = t.'shift'()
	
	$S0 = typeof $P0
	if $S0 == 'List' goto travel_down

	$P1 = '!@deepcopy'(p)
	stack.'push'($P0, $P1 :flat)
	goto loop

travel_down:
	tlist.'push'(t)
	t = $P0
	goto loop

travel_up:
	unless tlist goto end_loop
	t = tlist.'pop'()
	goto loop
	
end_loop:
.end

=item treerec

 T [O] [C]  ->  ...

T is a tree. If T is a leaf, executes O. Else executes [[O] [C] treerec] C.

=cut

.sub 'treerec'
	.local pmc stack
	.local pmc t, o, c
	stack = get_hll_global ['private'], 'funstack'
	c = stack.'pop'('List')
	o = stack.'pop'('List')
	(t, $S0) = stack.'pop'()
	
	if $S0 == 'List' goto recurse
	$P0 = '!@deepcopy'(o)
	.tailcall stack.'push'(t, $P0 :flat)
	
recurse:
	$P0 = get_global "treerec"
	$P0 = '!@mklist'(o, c, $P0)
	$P1 = '!@deepcopy'(c)
	.tailcall stack.'push'(t, $P0, $P1 :flat)
.end

=item treegenrec

 T [O1] [O2] [C]  ->  ...

T is a tree. If T is a leaf, executes O1.
Else executes O2 and then [[O1] [O2] [C] treegenrec] C.

=cut

.sub 'treegenrec'
	.local pmc stack
	.local pmc t, o1, o2, c
	stack = get_hll_global ['private'], 'funstack'
	c = stack.'pop'('List')
	o2 = stack.'pop'('List')
	o1 = stack.'pop'('List')
	(t, $S0) = stack.'pop'()
	
	if $S0 == 'List' goto recurse
	$P0 = '!@deepcopy'(o1)
	.tailcall stack.'push'(t, $P0 :flat)
	
recurse:
	$P0 = get_global "treegenrec"
	$P0 = '!@mklist'(o1, o2, c, $P0)
	$P1 = '!@deepcopy'(c)
	$P2 = '!@deepcopy'(o2)
	.tailcall stack.'push'(t, o2 :flat, $P0, $P1 :flat)
.end

=back
=cut

