package Schedule::LongSteps::Storage;

use Moose;

=head1 NAME

Schedule::LongSteps::Storage - An abstract storage class for steps

=cut

=head2 prepare_due_steps

Mark the steps that are due to run as 'running' and
returns an iterable object listing them.

Users: Note that this is meant to be used by L<Schedule::LongSteps>, and not intended
to be called directly.

Implementors: You will have to implement this method should you wish to implement
a new steps storage backend.

=cut

sub prepare_due_steps{
    my ($self) = @_;
    ...
}


__PACKAGE__->meta()->make_immutable();
