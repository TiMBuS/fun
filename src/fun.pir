
=head1 TITLE

xyz.pir - A fun compiler.

=head2 Description

This is the base file for the fun compiler.

This file includes the parsing and grammar rules from
the src/ directory, loads the relevant PGE libraries,
and registers the compiler under the name 'fun'.

=head2 Functions

=over 4

=item onload()

Creates the fun compiler using a C<PCT::HLLCompiler>
object.

=cut

.namespace [ 'fun::Compiler' ]

.loadlib 'fun_group'
.loadlib 'fun_ops'
.loadlib 'sys_ops'
.loadlib 'io_ops'
.loadlib 'math_ops'
.loadlib 'trans_ops'
 
.sub 'onload' :anon :load
    load_bytecode 'PCT.pbc'

    $P0 = get_hll_global ['PCT'], 'HLLCompiler'
    $P1 = $P0.'new'()
    $P1.'language'('fun')
    $P1.'parsegrammar'('fun::Grammar')
    $P1.'parseactions'('fun::Grammar::Actions')
.end

.include 'src/gen_objects.pir'
.include 'src/gen_builtins.pir'
.include 'src/gen_grammar.pir'
.include 'src/gen_actions.pir'

.namespace []

.sub 'initfun' :anon :load
    $P0 = getinterp
    $P0.'recursion_limit'(100000)

    $P0 = new 'Stack'
    set_hll_global ['private'], 'funstack', $P0

    $P0 = get_hll_global "put"
    $P1 = new 'List'
    $P1.'push'($P0)
    set_hll_global ['private'], 'dothook', $P1

    $P0 = new 'Boolean'
    $P0 = 1
    set_hll_global ['private'], 'undeferror', $P0

    #I dont really see any case where the following code would be needed.
    #It's here in case I add a function that needs to get the userfuncs namespace but no user functions exist.
    #$P0 = get_hll_namespace
    #$P0.'add_namespace'('userfuncs')
.end

=back

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:

