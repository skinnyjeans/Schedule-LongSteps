package Schedule::LongSteps::Process;

use Moose;

=head1 NAME

Schedule::LongSteps::Process - A base class for all LongSteps processes.

=cut

has 'process_id' => ( is => 'ro', isa => 'Str' , required => 1 );

=head2 new_step

Returns a new step from the given properties.

Usage examples:

=cut

sub new_step{
    my ($self, $step_properties) = @_;
    return $step_properties;
}

=head2 final_step

Returns a final step that will never run
from the given properies.

=cut

sub final_step{
    my ($self, $step_properties) = @_;
    $step_properties //= {};

    return {
        %$step_properties,
        run_at => undef,
        status => 'terminated'
    };
}

__PACKAGE__->meta->make_immutable();

