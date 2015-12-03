#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::DBIxClass;
use DateTime;

eval "use DBD::SQLite";
plan skip_all => "DBD::SQLite is required for this test."
    if $@;

eval "use DBIx::Class::Schema::Loader";
plan skip_all => "DBIx::Class::Schema::Loader is required for this test."
    if $@;

my $create_table = q|
CREATE TABLE longsteps_step( id INTEGER PRIMARY KEY AUTOINCREMENT,
                             status TEXT NOT NULL DEFAULT 'pending',
                             what TEXT NOT NULL,
                             run_at TEXT DEFAULT NULL,
                             run_id TEXT DEFAULT NULL,
                             state TEXT NOT NULL DEFAULT '{}',
                             error TEXT DEFAULT NULL
)
|;

my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', undef, undef, {
    AutoCommit => 1,
    RaiseError => 1
});

$dbh->do( $create_table );

DBIx::Class::Schema::Loader::make_schema_at(
    'My::Schema',
    {
        # debug => 1,
        naming => 'v5',
        components => ["InflateColumn::DateTime"],
    },
    [ sub{ return $dbh; } ]
);

my $schema = My::Schema->connect(sub{ $dbh; });

ok( my $storage = Schedule::LongSteps::Storage::DBIxClass->new({ schema => $schema, resultset_name => 'LongstepsStep' }) );
is( $storage->prepare_due_steps()->count() , 0 , "Ok zero due steps");

# Note that we need that for SQLite, cause it hasnt got
# a datetime type. Therefore, we need to make sure the format is consistent with what is done
# inside the LongSteps::Storage::DBIxClass code.
my $dtf = $schema->storage()->datetime_parser();

$storage->create_step({ what => 'whatever', run_at => $dtf->format_datetime( DateTime->now() ) });

is( $storage->prepare_due_steps()->count() , 1 , "Ok one due step");
is( $storage->prepare_due_steps()->count() , 0 , "Doing it again gives zero steps");

$storage->create_step({ what => 'whatever', run_at => $dtf->format_datetime( DateTime->now() ) });
$storage->create_step({ what => 'whatever', run_at => $dtf->format_datetime( DateTime->now() ) });

my $steps = $storage->prepare_due_steps();
is( $steps->count() , 2 , "Ok two steps to do");
while( my $step = $steps->next() ){
    # While we are doing things, any other process would see zero things to do
    is( $storage->prepare_due_steps()->count() , 0 , "Preparing steps again whilst they are running give zero steps");
}


done_testing();
