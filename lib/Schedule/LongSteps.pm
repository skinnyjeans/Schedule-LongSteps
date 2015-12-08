package Schedule::LongSteps;

# ABSTRACT: Manage sets of steps accross days, months, years.

use Moose;

=head1 NAME

Schedule::LongSteps - Manage sets of steps accross days, months, years

=head1 ABSTRACT

This attempts to solve the problem of defining and running a serie of steps, maybe conditional accross an arbitrary long timespan.

An example of such a process would be: "After an order has been started, if more than one hour, send an email reminder every 2 days until the order is finished. Give up after a month"". You get the idea.

A serie of steps like that is usually a pain to implement and this is an attempt to provide a framework so it would make writing and testing such a process as easy as writing and testing an good old Class.

=head1 QUICK START AND SYNPSIS

First write a class to represent your long running set of steps

  package My::Application::MyLongProcess;

  use Moose;
  extends qw/Schedule::LongSteps::Process/;

  # Some contextual things.
  has 'thing' => ( is => 'ro', required => 1); # Some mandatory context provided by your application at each regular run.

  # The first step should be executed after the process is installed on the target.
  sub build_first_step{
    my ($self) = @_;
    return $self->new_step({ what => 'do_stuff1', run_at => DateTime->now() });
  }

  sub do_stuff1{
     my ($self) = @_;

      # The starting state
      my $state = $self->state();

      my $thing = $self->thing();

     .. Do some stuff and return the next step to execute ..

      return $self->new_step({ what => 'do_stuff2', run_at => DateTime->... , state => [ 'some', 'jsonable', 'structure' ]  });
  }

  sub do_stuff2{
      my ($self, $step) = @_;

      $self->wait_for_steps('do_stuff1', 'do_stuff2' );

      .. Do some stuff and terminate the process ..

       if( ... ){
           return Schedule::LongSteps::Step->new({ what => 'do_stuff1', run_at => DateTime->... , state => { some jsonable structure } });
       }
       return $self->final_step({ state => { the => final, state => 1 }  }) ;
  }

  __PACKAGE__->meta->make_immutable();

Then in you main application do this once per 'target':

   my $longsteps = Schedule::LongSteps->new(...);
   ...

   $longsteps->instanciate_process('My::Application::MyProcess', { thing => 'whatever' }, [ the, init, state ]);

Then regularly (in a cron, or a recurring callback):

  my $long_steps = Schedule::LongSteps->new(...); # Keep only one instance per process.
  ...

  $long_steps->run_due_steps({ thing => 'whatever' });

=cut

use Class::Load;
use Log::Any qw/$log/;

use Schedule::LongSteps::Storage::Memory;

has 'storage' => ( is => 'ro', isa => 'Schedule::LongSteps::Storage', lazy_build => 1);

sub _build_storage{
    my ($self) = @_;
    $log->warn("No storage specified. Will use Memory storage");
    return Schedule::LongSteps::Storage::Memory->new();
}

=head2 uuid

Returns a L<Data::UUID> from the storage.

=cut

sub uuid{
    my ($self) = @_;
    return $self->storage()->uuid();
}

=head2 run_due_processes

Runs all the due processes steps according to now(). All processes
are given the context to be built.

Usage:

 # No context given:
 $this->run_due_processes();

 # With 'thing' as context:
 $this->run_due_processes({ thing => ... });

Returns the number of processes run

=cut

sub run_due_processes{
    my ($self, $context) = @_;
    $context ||= {};

    my $stored_processes = $self->storage->prepare_due_processes();
    my $process_count = 0;
    while( my $stored_process = $stored_processes->next() ){
        Class::Load::load_class($stored_process->process_class());
        my $process = $stored_process->process_class()->new({ stored_process => $stored_process, %{$context} });
        my $process_method = $stored_process->what();

        $process_count++;

        my $new_step_properties = eval{ $process->$process_method(); };
        if( my $err = $@ ){
            $log->error("Error running process ".$stored_process->process_class().':'.$stored_process->id().' :'.$err);
            $stored_process->update({
                status => 'error',
                error => $err,
                run_at => undef,
                run_id => undef,
            });
            next;
        }

        $stored_process->update({
            status => 'paused',
            run_at => undef,
            run_id => undef,
            %{$new_step_properties}
        });
    }
    return $process_count;
}

=head2 instanciate_process

Instanciate a process from the given process class

=cut

sub instanciate_process{
    my ($self, $process_class, $build_args, $init_state ) = @_;

    $build_args //= {};
    $init_state //= {};

    Class::Load::load_class($process_class);
    unless( $process_class->isa('Schedule::LongSteps::Process') ){
        confess("Class '$process_class' is not an instance of 'Schedule::LongSteps::Process'");
    }
    my $process = $process_class->new( $build_args );
    my $step_props = $process->build_first_step();

    my $stored_process = $self->storage->create_process({
        process_class => $process_class,
        state => $init_state,
        %{$step_props}
    });
    return $stored_process;
}

__PACKAGE__->meta->make_immutable();
