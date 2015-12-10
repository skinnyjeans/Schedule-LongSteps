#! perl -wt

use strict;
use Test::More;
use Test::MockDateTime;

use DateTime;

use Schedule::LongSteps;
use Schedule::LongSteps::Storage::DBIxClass;

eval "use Test::mysqld";
plan skip_all => "Test::mysqld is required for this test" if $@;

eval "use DBIx::Class";
plan skip_all => "DBIx::Class is required for this test" if $@;

eval "use SQL::Translator";
plan skip_all => "SQL::Translator is required for this test" if $@;

eval "use DBIx::Class::InflateColumn::Serializer";
plan skip_all => "DBIx::Class::InflateColumn::Serializer is required for this test" if $@;

eval "use Net::EmptyPort";
plan skip_all => "Net::EmptyPort is required for this test" if $@;

my $test_mysql = Test::mysqld->new(
    my_cnf => {
        port => Net::EmptyPort::empty_port()
    });

{
    package MyApp::Schema::Result::Process;
    use base qw/DBIx::Class::Core/;
    __PACKAGE__->table('longprocesse');
    __PACKAGE__->load_components(qw/InflateColumn::DateTime InflateColumn::Serializer/);
    __PACKAGE__->add_columns(
        id =>
            { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
        process_class =>
            { data_type => "varchar", is_nullable => 0, size => 255 },
        what =>
            { data_type => "varchar", is_nullable => 1, size => 255 },
        status =>
            { data_type => "varchar", is_nullable => 0, size => 50 , default_value => 'pending' },
        run_at =>
            { data_type => "datetime", datetime_undef_if_invalid => 1, is_nullable => 1 },
        run_id =>
            { data_type => "varchar", is_nullable => 1, size => 36 },
        state =>
            { data_type => "text",
              serializer_class => 'JSON',
              is_nullable => 0,
          },
        error =>
            { data_type => "text", is_nullable => 1 }
        );

    __PACKAGE__->set_primary_key("id");
    sub sqlt_deploy_hook {
        my ($self, $sqlt_table) = @_;
        $sqlt_table->add_index(name => 'idx_longprocess_run_id', fields => ['run_id']);
    }
    1;
}

{
    package MyApp::Schema;
    use base qw/DBIx::Class::Schema/;
    __PACKAGE__->load_classes({ 'MyApp::Schema::Result' => [ 'Process' ] });
    1;
}

{
    package MyMedicalProcess;
    # Inspired by https://en.wikipedia.org/wiki/XPDL Medical process example
    use Moose;
    extends qw/Schedule::LongSteps::Process/;

    use DateTime;

    has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1);

    sub build_first_step{
        my ($self) = @_;
        return $self->new_step({ what => 'do_first_look', run_at => DateTime->now() });
    }

    sub do_first_look{
        my ($self) = @_;
        my $state = $self->state();

        if( ! $state->{looks_cancerous} ){
            return $self->final_step({ state => { %$state , has_cancer => 0 } });
        }
        return $self->new_step({ what => 'do_analyze_more', run_at => DateTime->now() });
    }

    sub do_analyze_more{
        my ($self) = @_;
        my $state = $self->state();
        my $p1 = $self->longsteps->instantiate_process('AnalyzePatient', { schema =>  $self->schema()  }, { %$state });
        my $p2 = $self->longsteps->instantiate_process('AnalyzeFamily', { schema => $self->schema() } , { %$state });
        return $self->new_step({ what => 'do_synthetize_analyzes', run_at => DateTime->new()->add( days => 3 ),
                                 { %$state , processes => [ $p1->id(), $p2->id() ] } });
    }
    sub do_synthetize_analyzes{
        my ($self) = @_;
        return $self->wait_processes(
            $self->state()->{processes},
            sub{
                my ( @processes ) = @_;
                return $self->new_step({
                    what => 'do_prescribe',
                    state => {
                        %{$self->state()},
                        map{ %{$_->state()} } @processes
                    }});
            });

    }

    sub do_prescribe{
        my ($self) = @_;
        my $state = $self->state();
        if( $state->{looks_cancerous} &&
                $state->{has_cancer_cells} &&
                $state->{has_cancer_history}
            ){
            return $self->final_step({ state => { %$state , have_treatment => 1 } });
        }
        return $self->final_step({ state => { %$state , have_treatment => 0 } });
    }
    __PACKAGE__->meta->make_immutable();
}

{
    package AnalyzePatient;
    use Moose;
    extends qw/Schedule::LongSteps::Process/;
    sub build_first_step{
        my ($self) = @_;
        return $self->new_step({ what => 'do_analyze_patient', run_at => DateTime->now() });
    }
    sub do_analyze_patient{
        my ($self) = @_;
        return $self->final_step({ state => { has_cancer_cells => 0 } });
    }
    __PACKAGE__->meta->make_immutable();
}

{
    package AnalyzeFamily;
    use Moose;
    extends qw/Schedule::LongSteps::Process/;
    sub build_first_step{
        my ($self) = @_;
        return $self->new_step({ what => 'do_analyze_family', run_at => DateTime->now()->add(days => 2) });
    }
    sub do_analyze_family{
        my ($self) = @_;
        return $self->final_step({ state => { has_cancer_history => 0 } });
    }
    __PACKAGE__->meta->make_immutable();
}



my $schema = MyApp::Schema->connect( $test_mysql->dsn(), '', '' );
$schema->deploy();

# Time to build a storage

my $storage = Schedule::LongSteps::Storage::DBIxClass->new({ schema => $schema,
                                                             resultset_name => 'Process'
                                                         });
my $long_steps = Schedule::LongSteps->new({ storage => $storage });

ok( my $healthy_process = $long_steps->instantiate_process('MyMedicalProcess', { schema => $schema } , { looks_cancerous => 0  }) );

# This would run in a completely separate process
ok( $long_steps->run_due_processes({ schema => $schema }) );

$healthy_process->discard_changes();
is( $healthy_process->status(), 'terminated' );


# use Schedule::LongSteps;

# {
#     package MyProcess;
#     use Moose;
#     extends qw/Schedule::LongSteps::Process/;

#     use DateTime;
#     sub build_first_step{
#         my ($self) = @_;
#         return $self->new_step({ what => 'do_stuff1', run_at => DateTime->now() });
#     }

#     sub do_stuff1{
#         my ($self) = @_;
#         return $self->new_step({ what => 'do_end', run_at => DateTime->now()->add( days => 2 ) });
#     }

#     sub do_end{
#         my ($self) = @_;
#         return $self->final_step({ state => { final => 'state' }});
#     }
# }


# ok( my $long_steps = Schedule::LongSteps->new() );

# ok( my $process = $long_steps->instantiate_process('MyProcess', undef, { beef => 'saussage' }) );

# # Time to run!
# ok( $long_steps->run_due_processes() );

# is( $process->what() , 'do_end' );

# # Nothing to run right now
# ok( ! $long_steps->run_due_processes() );

# # Simulate 3 days after now.
# my $three_days = DateTime->now()->add( days => 3 );

# on $three_days.'' => sub{
#     ok( $long_steps->run_due_processes() , "Ok one step was run");
# };

# is_deeply( $process->state() , { final => 'state' });

ok(1);
done_testing();
