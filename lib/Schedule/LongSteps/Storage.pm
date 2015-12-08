package Schedule::LongSteps::Storage;

use Moose;

=head1 NAME

Schedule::LongSteps::Storage - An abstract storage class for steps

=cut

use Data::UUID;

has 'uuid' => ( is => 'ro', isa => 'Data::UUID', lazy_build => 1);

sub _build_uuid{
    my ($self) = @_;
    return Data::UUID->new();
}



=head2 prepare_due_processes

Mark the processes that are due to run as 'running' and
returns an iterable object listing them.

Users: Note that this is meant to be used by L<Schedule::LongSteps>, and not intended
to be called directly.

Implementors: You will have to implement this method should you wish to implement
a new process storage backend.

=cut

sub prepare_due_processes{
    my ($self) = @_;
    die "Please implement this in $self";
}

=head2 create_process

Creates and return a new stored process.

=cut

sub create_process{
    my ($self, $properties) = @_;
    die "Please implement this in $self";
}


__PACKAGE__->meta()->make_immutable();
