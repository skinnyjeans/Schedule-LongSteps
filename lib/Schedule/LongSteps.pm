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
      my $state = $self->step()->state();

      my $thing = $self->thing();

     .. Do some stuff and return the next step to execute ..

      return $self->new_step({ what => 'do_stuff2', run_at => DateTime->... , state => [ 'some', 'jsonable', 'structure' ]  });
  }

  sub do_stuff2{
      my ($self, $step) = @_;

      $self->wait_for_steps('do_stuff1', 'do_stuff2' );

      .. Do some stuff and terminate the process ..

       my $args = $step->args()
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

has 'storage' => ( is => 'ro', isa => 'Schedule::LongSteps::Storage', required => 1);

=head2 run_due_steps

Runs all the due steps according to now(). Steps being run will all be

=cut

sub run_due_steps{
    my ($self, $context) = @_;
    $context ||= {};

    my $steps = $self->storage->prepare_due_steps();

    while( my $step = $steps->next() ){
        my $process = $step->process_class()->new({ step => $step, %{$context} });

        my $new_step = eval{ $step->what(); };
        if( my $err = $@ ){
            $step->update({ error => $err,
                            run_at => undef
                        });
            next;
        }

        $step->update({
            status => 'paused',
            started_at => undef,
            run_at => undef,
            %{$new_step}
        });
    }
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

    my $step = $self->storage->create_step({
        state => $init_state,
        %{$step_props}
    });
    return;
}

__PACKAGE__->meta->make_immutable();
