#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::AutoDBIx;
use DateTime;

eval "use DBD::SQLite";
plan skip_all => "DBD::SQLite is required for this test."
    if $@;

eval "use DBIx::Class";
plan skip_all => "DBIx::Class is required for this test" if $@;

eval "use SQL::Translator";
plan skip_all => "SQL::Translator is required for this test" if $@;

eval "use DBIx::Class::InflateColumn::Serializer";
plan skip_all => "DBIx::Class::InflateColumn::Serializer is required for this test" if $@;

eval "use DateTime::Format::SQLite";
plan skip_all => "DateTime::Format::SQLite is required for this test" if $@;


my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', undef, undef, {
    AutoCommit => 1,
    RaiseError => 1
});

ok( my $storage = Schedule::LongSteps::Storage::AutoDBIx->new({ get_dbh => sub{ $dbh; } }) );
# $storage->deploy();
is( $storage->prepare_due_processes()->count() , 0 , "Ok zero due steps");

# Note that we need that for SQLite, cause it hasnt got
# a datetime type. Therefore, we need to make sure the format is consistent with what is done
# inside the LongSteps::Storage::DBIxClass code.
my $dtf = $storage->schema->storage()->datetime_parser();

ok( my $process_id = $storage->create_process({ process_class => 'Blabla',
                                                state => {},
                                                what => 'whatever',
                                                run_at => $dtf->format_datetime( DateTime->now() )
                                            })->id(), "Ok got ID");
ok( $storage->find_process($process_id) );

is( $storage->prepare_due_processes()->count() , 1 , "Ok one due step");
is( $storage->prepare_due_processes()->count() , 0 , "Doing it again gives zero steps");

my $process = $storage->create_process({ process_class => 'Blabla',
                                         what => 'whatever',
                                         state => {},
                                         run_at => $dtf->format_datetime( DateTime->now() )
                                     });
ok( $storage->find_process($process->id()));
$storage->create_process({ process_class => 'Blabla',
                           what => 'whatever',
                           state => {},
                           run_at => $dtf->format_datetime( DateTime->now() )
                       });

my $steps = $storage->prepare_due_processes();
is( $steps->count() , 2 , "Ok two steps to do");
while( my $step = $steps->next() ){
    # While we are doing things, any other process would see zero things to do
    is( $storage->prepare_due_processes()->count() , 0 , "Preparing steps again whilst they are running give zero steps");
}


done_testing();
