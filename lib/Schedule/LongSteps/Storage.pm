package Schedule::LongSteps::Storage;

use Moose::Role;

=head1 NAME

Schedule::LongSteps::Storage - An abstract storage class for steps

=cut

use Data::UUID;

has 'uuid' => ( is => 'ro', isa => 'Data::UUID', lazy_build => 1);

sub _build_uuid{
    my ($self) = @_;
    return Data::UUID->new();
}



=head2 prepare_due_steps

Mark the steps that are due to run as 'running' and
returns an iterable object listing them.

Users: Note that this is meant to be used by L<Schedule::LongSteps>, and not intended
to be called directly.

Implementors: You will have to implement this method should you wish to implement
a new steps storage backend.

=cut

requires 'prepare_due_steps';

=head2 create_step

Creates and return a new stored step.

=cut

requires 'create_step';

1;
