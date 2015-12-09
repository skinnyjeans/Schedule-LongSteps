# NAME

Schedule::LongSteps - Manage sets of steps accross days, months, years

# ABSTRACT

This attempts to solve the problem of defining and running a serie of steps, maybe conditional accross an arbitrary long timespan.

An example of such a process would be: "After an order has been started, if more than one hour, send an email reminder every 2 days until the order is finished. Give up after a month"". You get the idea.

A serie of steps like that is usually a pain to implement and this is an attempt to provide a framework so it would make writing and testing such a process as easy as writing and testing a good old Class.

# CONCEPTS

## Process

A Process represents a set of logically linked steps that need to run over a long span of times (hours, months, even years..). It persists in a Storage.

At the logical level, the persistant Process has the following attributes (See [Schedule::LongSteps::Storage::DBIxClass](https://metacpan.org/pod/Schedule::LongSteps::Storage::DBIxClass) for a comprehensive list):

\- what. Which step should it run next.

\- run\_at. A [DateTime](https://metacpan.org/pod/DateTime) at which this next step should be run. This allows running a step far in the future.

\- status. Is the step running, or paused or is the process terminated.

\- state. The persistant state of your application. This should be a pure Perl hash (JSONable).

Users (you) implement their business process as a subclass of [Schedule::LongSteps::Process](https://metacpan.org/pod/Schedule::LongSteps::Process). Such subclasses can have contextual properties
as Moose properties that will have to be supplied by the [Schedule::LongSteps](https://metacpan.org/pod/Schedule::LongSteps) management methods.

## Steps

A step is simply a subroutine in a process class that runs some business code. It always returns either a new step to be run
or a final step marker.

## Storage

A storage provides the backend to persist processes. Build a Schedule::LongSteps with a storage instance.

## Manager: Schedule::LongSteps

A [Schedule::LongSteps](https://metacpan.org/pod/Schedule::LongSteps) provides an entry point to all thing related to Schedule::LongSteps process management.
You should keep once instance of this in your application (well, one instance per process) as this is what you
are going to use to launch and manage processes.

# QUICK START AND SYNOPSIS

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

    my $dbic_storage = Schedule::LongSteps::Storage::DBIxClass->new(...);
    # Keep only ONE Instance of this in your application.
    my $longsteps = Schedule::LongSteps->new({ storage => $dbic_storage });
    ...

    $longsteps->instanciate_process('My::Application::MyProcess', { thing => 'whatever' }, [ the, init, state ]);

Then regularly (in a cron, or a recurring callback):

    my $dbic_storage = Schedule::LongSteps::Storage::DBIxClass->new(...);
    # Keep only ONE instance of this in your application.
    my $longsteps = Schedule::LongSteps->new({ storage => $dbic_storage });
    ...

    $long_steps->run_due_steps({ thing => 'whatever' });

# PERSISTANCE

The persistance of processes is managed by a subclass of [Schedule::LongSteps::Storage](https://metacpan.org/pod/Schedule::LongSteps::Storage) that you should instanciate
and given to the constructor of [Schedule::LongSteps](https://metacpan.org/pod/Schedule::LongSteps)

Example:

    my $dbic_storage = Schedule::LongSteps::Storage::DBIxClass->new(...);
    my $longsteps = Schedule::LongSteps->new({ storage => $dbic_storage });
    ...

# COOKBOOK

This package should  be expressive enough for you to implement business processes
as complex as those given as an example on this page: [https://en.wikipedia.org/wiki/XPDL](https://en.wikipedia.org/wiki/XPDL)

Proper support for XPDL is not implemented yet, but here is a list of recipes to implement
the most common process patterns:

## MOVING TO A FINAL STATE

Simply do in your step 'do\_last\_stuff' implementation:

    sub do_last_stuff{
       my ($self) = @_;
       # Return final_step with the final state.
       return $self->final_step({ state => { the => 'final' , state => 1 } });
    }

## DO SOMETHING ELSE IN X AMOUNT OF TIME

    sub do_stuff{
         ...
         # Do the things that have to be done NOW
         ...
         # And in two days, to this
         return $self->new_step({ what => 'do_stuff_later', run_at => DateTime->now()->add( days => 2 ) ,  state => { some => 'new one' }});
    }

## DO SOMETHING CONDITIONALLY

    sub do_choose{
       if( ... ){
          return $self->new_step({ what => 'do_choice1', run_at => DateTime->now() });
       }
       return $self->new_step({ what => 'do_choice2', run_at => DateTime->now() });
    }

    sub do_choice1{...}
    sub do_choice2{...}

## FORKING AND WAITING FOR PROCESSES

    sub do_fork{
       ...
       my $p1 = $self->longsteps->instanciate_process('AnotherProcessClass', \%build_args , \%initial_state );
       my $p2 = $self->longsteps->instanciate_process('YetAnotherProcessClass', \%build_args2 , \%initial_state2 );
       ...
       return $self->new_step({ what => 'do_join', run_at => DateTime->now() , { processes => [ $p1->id(), p2->id() ] } });
    }

    sub do_join{
       return $self->wait_processes( $self->state()->{processes}, sub{
            my ( @terminated_processes ) = @_;
            my $state1 = $terminated_processes[0]->state();
            my $state2 = $terminated_processes[1]->state();
            ...
            # And as usual:
            return $self->...
       });
    }

# SEE ALSO

[BPM::Engine](https://metacpan.org/pod/BPM::Engine) A business Process engine based on XPDL, in Alpha version since 2012 (at this time of writing)

# Copyright and Acknowledgement

This code is released under the Perl5 Terms by Jerome Eteve (JETEVE), with the support of Broadbean Technologies Ltd.

See [perlartistic](https://metacpan.org/pod/perlartistic)

## uuid

Returns a [Data::UUID](https://metacpan.org/pod/Data::UUID) from the storage.

## run\_due\_processes

Runs all the due processes steps according to now(). All processes
are given the context to be built.

Usage:

    # No context given:
    $this->run_due_processes();

    # With 'thing' as context:
    $this->run_due_processes({ thing => ... });

Returns the number of processes run

## instanciate\_process

Instanciate a stored process from the given process class returns a new process that will have an ID.

Usage:

    $this->instanciate_process( 'MyProcessClass', { process_attribute1 => .. } , { initial => 'state' });

## find\_process

Shortcut to $self->storage->find\_process( $pid );
