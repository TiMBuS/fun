=head1 Codeflow

Functions for controlling code flow

=head2 Functions

=over 4

=cut


=item choice

 B T F  ->  X

If B is true, then X = T else X = F.

=cut

.sub 'choice'
	.local pmc stack
	stack = get_global 'funstack'
	$P0 = stack.'pop'()
	$P1 = stack.'pop'()
	
	$P2 = stack.'pop'('Boolean')
	
	if $P2 == 0 goto false
	stack.'push'($P1)
	goto finish
false:
	stack.'push'($P0)
	
finish:
	.return()
.end

=item branch

 B [T] [F]  ->  ...

If B is true, then executes T else executes F.

=cut

.sub 'branch'
	.local pmc stack, ifcnd, then, else
	stack = get_global 'funstack'
	
	else = stack.'pop'('ResizablePMCArray')
	then = stack.'pop'('ResizablePMCArray')
	
	ifcnd = stack.'pop'('Boolean')
	
	if ifcnd == 0 goto run_else
	stack.'push'(then :flat)
	goto finish

run_else:
	stack.'push'(else :flat)
	
finish:
	stack.'run'()
.end


=item ifte

 [B] [T] [F]  ->  ...

Executes B. If that yields true, then executes T else executes F.

=cut

.sub 'ifte'
	.local pmc stack, ifcnd, then, else
	stack = get_global 'funstack'
	
	else = stack.'pop'('ResizablePMCArray')
	then = stack.'pop'('ResizablePMCArray')
	
	$P0 = stack.'pop'('ResizablePMCArray')
	stack.'push'($P0 :flat)
	stack.'run'()
	ifcnd = stack.'pop'('Boolean')
	
	if ifcnd == 0 goto run_else
	stack.'push'(then :flat)
	stack.'run'()
	.return()

run_else:
	stack.'push'(else :flat)
	stack.'run'()
	.return()
.end

=item cond

 [..[[Bi] Ti]..[D]]  ->  ...

Tries each C<Bi>. If that yields true, then executes C<Ti> and exits.
If no C<Bi> yields true, executes default C<D>.

=cut

.sub 'cond'
	.local pmc stack, condlist 
	.local pmc bi, ti, d
	
	stack = get_global 'funstack'
	condlist = stack.'pop'('ResizablePMCArray')
	d = condlist.'pop'()
	
find_true:
	unless condlist goto do_default
	ti = shift condlist
	bi = shift ti
	stack.'push'(bi :flat)
	$I0 = stack.'pop'('Boolean')
	unless $I0 goto find_true
	
	stack.'push'(ti :flat)
	stack.'run'()
	.return()

do_default:
	stack.'push'(d :flat)
	stack.'run'()
	.return()
.end

=item case

 X [..[X Xs]..]  ->  Xs

Indexing on the B<value> of X, execute the matching Xs. Defaults to the last case if no match found.
Note: Uses '=' not 'equals' to check for a matching index. I<Do not> use lists (or functions) to index.

=cut

.sub 'case'
	.local pmc stack
	.local pmc caselist, x, xs, d
	stack = get_global 'funstack'
	caselist = stack.'pop'('ResizablePMCArray')
	d = pop caselist
	x = stack.'pop'()
	
find_true:
	unless caselist goto do_default
	xs = shift caselist
	$P0 = shift xs
	if $P0 != x goto find_true
	stack.'push'(xs :flat)
	goto finish
	
do_default:
	stack.'push'(d :flat)
finish:
.end

=item opcase

 X [..[X Xs]..]  ->  [Xs]

Indexing on the B<type> of X, returns the list [Xs].
Defaults to the last case if no match found.

=cut

.sub 'opcase'
	.local pmc stack
	.local pmc caselist, x, xs, d
	stack = get_global 'funstack'
	caselist = stack.'pop'('ResizablePMCArray')
	d = pop caselist
	x = stack.'pop'()
	x = typeof x
	
find_true:
	unless caselist goto do_default
	xs = shift caselist
	$P0 = shift xs
	$P0 = typeof $P0
	if $P0 != x goto find_true
	stack.'push'(xs :flat)
	goto finish
	
do_default:
	stack.'push'(d :flat)
finish:
.end

=back
