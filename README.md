# NAME

Schedule::LongSteps - Manage sets of steps accross days, months, years

# ABSTRACT

This attempts to solve the problem of defining and running a serie of steps, maybe conditional accross an arbitrary long timespan.

An example of such a process would be: "After an order has been started, if more than one hour, send an email reminder every 2 days until the order is finished. Give up after a month"". You get the idea.

A serie of steps like that is usually a pain to implement and this is an attempt to provide a framework so it would make writing and testing such a process as easy as writing and testing an good old Class.

# CONCEPTS

## Process

A process is an unordered collection of named steps, the name of an initial step

# SYNOPSIS

    package My::Application::LongProcess;

    # The first step should be executed after the process is installed on the target.
    sub build_first_step{
      my ($self) = @_;
      return Schedule::LongSteps::Step->new({ what => 'do_stuff1', when => DateTime->now(), args => [ .. ]});
    }

    sub build_steps{
        return {
           'do_stuff1' => sub{
              my ($step, $args) = @_;

              .. Do some stuff and return the next step to execute ..

               return $step->update({ what => 'do_stuff2', when => DateTime->... , args => [ 'some', 'args' ] });
           },
           'do_stuff2' => sub{
              my ($step, $args) = @_;

              .. Do some stuff and terminate the process for ever  ..
              return $step->delete();
           }
       };
    };
