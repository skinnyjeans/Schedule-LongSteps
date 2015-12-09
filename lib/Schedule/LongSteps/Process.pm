package Schedule::LongSteps::Process;

use Moose;
use Log::Any qw/$log/;

has 'longsteps' => ( is => 'ro', isa => 'Schedule::LongSteps' , required => 1);

has 'stored_process' => ( is => 'ro' );

=head1 NAME

Schedule::LongSteps::Process - A base class for all LongSteps processes.

=cut

=head2 state

Returns the current state (an arbitrary JSONable data structure, but usually a HashRef)
of this process.

=cut

sub state{
    my ($self) = @_;
    return $self->stored_process()->state();
}

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

=head2 wait_processes

Wait for the given process IDs and returns whatever the given
closure returns.

Usage:

   return $this->wait_process(
            [ $pid1 , $pid2 ],
            sub{
                ...
                return $this->new_step(...); # or whatever usual stuff
            }

If you skip the closure, this will just terminate $this process after the
given subprocesses have finished.

=cut

sub wait_processes{
    my ($self, $process_ids, $on_finish) = @_;
    $process_ids //= [];
    $on_finish //= sub{ $self->final_step(); };

    my @processes = map{ $self->longsteps()->find_process( $_ ) } @$process_ids;
    my @finished_processes = grep{ $_->status() eq 'terminated' } @processes;

    $log->debug(scalar(@finished_processes)." are finished");

    if( scalar( @processes ) == scalar( @finished_processes ) ){
        $log->debug("Calling on_finish");
        return $on_finish->( @finished_processes );
    }
    # Run at next tick
    $log->debug("Will wait a little bit more");
    return $self->new_step({ run_at => DateTime->now() });
}

__PACKAGE__->meta->make_immutable();

