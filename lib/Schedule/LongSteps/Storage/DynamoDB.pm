package Schedule::LongSteps::Storage::DynamoDB;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

use Log::Any qw/$log/;
use Scalar::Util;

=head1 NAME

Schedule::LongSteps::Storage::DynamoDB - A DynamoDB backed longstep storage.

=cut

=head1 SYNOPSIS


  my $dynamo_db = Paws->service('DynamoDB', ...); # see Paws
  # You can also look in t/storage-dynamodb.t for a working example.

  my $storage = Schedule::LongSteps::Storage::DynamoDB->new({ dynamo_db => $dynamo_db, table_prefix => 'my_app_longsteps' });

  # Call that only once as part of your persistent data management:
  $storage->vivify_table();

  my $sl = Schedule::LongSteps->new({ storage => $storage, ... }, ... );

=cut

has 'dynamo_db' => (is => 'ro', isa => 'Paws::DynamoDB' , required => 1 );
has 'table_prefix' => ( is => 'ro', isa => 'Str', required => 1);

has 'table_name' => ( is => 'ro', isa => 'Str', lazy_build => 1);

has 'creation_wait_time' => ( is => 'ro', isa => 'Int', default => 2 );

sub _build_table_name{
    my ($self) = @_;
    my $package = __PACKAGE__;
    $package =~ s/::/_/g;
    return $self->table_prefix().'_'.$package;
}

=head2 table_active

The remote DynamoDB table exists and is active.

=cut

sub table_active{
    my ($self) = @_;
    my $status = $self->table_status();
    unless( defined( $status ) ){ $status = 'NOMATCH'; }
    return $status eq 'ACTIVE';
}

=head2 table_exists

The remote DynamoDB table exists.

=cut

sub table_exists{
    return defined( shift->table_status() );
}

=head2 table_status

Returns the table status (or undef if the table doens't exists at all)

Usage:

  if( my $status = $self->table_status() ){ .. }

Returned status can be one of those described here: L<https://metacpan.org/pod/Paws::DynamoDB::TableDescription>

=cut

sub table_status{
    my ($self) = @_;
    my $desc_table = eval{ $self->dynamo_db()->DescribeTable( TableName => $self->table_name() ) };
    if( my $err = $@ ){
        if( Scalar::Util::blessed($err) &&
            $err->isa('Paws::Exception') &&
            $err->code() eq 'ResourceNotFoundException'
        ){
            $log->debug("No table ".$self->table_name());
            return undef;
        }
        # Rethrow any other error.
        confess( $err );
    }
    return $desc_table->Table()->TableStatus();
}

=head2 vivify_table

Vivifies the remote DynamoDB table to support this storage.

You need to call that at least once as part of your persistent data
management process, or at the beginning of your application.

=cut

sub vivify_table{
    my ($self) = @_;

    my $table_name = $self->table_name();
    if( $self->table_exists() ){
        $log->warn("Table $table_name already exists in remote DynamoDB. Not creating it");
        return;
    }
    # Get all tables and check this one is not there already.
    $log->info("Creating Table ".$table_name." in dynamoDB");

    my $creation = $self->dynamo_db()->CreateTable(
        TableName => $table_name,
        AttributeDefinitions => [
            { AttributeName => 'id', AttributeType => 'S' },
            ## Note those are only there for reference.
            ## as AttributeDefinition must only defined attributes
            ## used in the KeySchema
            # { AttributeName => 'process_class', AttributeType => 'S' },
            # { AttributeName => 'status', AttributeType => 'S' },
            # { AttributeName => 'what', AttributeType => 'S' },
            # { AttributeName => 'run_at_day' , AttributeType => 'N' }, # Time in epoch / 86400 = epoch day
            # { AttributeName => 'run_at', AttributeType => 'N' }, # Time in epoch of run_at
            # { AttributeName => 'state', AttributeType => 'B' },
            # { AttributeName => 'error', AttributeType => 'S' },
        ],
        KeySchema => [
            { AttributeName => 'id', KeyType => 'HASH' },
        ],
        ProvisionedThroughput => {
            ReadCapacityUnits => 2,
            WriteCapacityUnits => 2,
            # This is low to avoid having a large bill in case
            # of tests failure.
            # Note that we can change that AFTER the fact
        },
    );

    while(! $self->table_active() ){
        $log->info("Table $table_name not active yet. Waiting ".$self->creation_wait_time()." second");
        if( $self->creation_wait_time() ){
            sleep($self->creation_wait_time());
        }
    }
    $log->info("Table $table_name ACTIVE. All is fine");
    return $creation;
}


=head2 destroy_table

Destroys this table. Mainly so tests don't leave some crap behind.

Use that responsibly. Which is never except in tests.

Note that this blocks until the table has effectively been deleted remotely.

=cut

sub destroy_table{
    my ($self, $am_i_sure) = @_;
    unless( $am_i_sure eq 'I am very sure and I am not insane' ){
        confess("Sorry we cannot let you do that");
    }
    unless( $self->table_active() ){
        confess("Sorry this table is not ACTIVE. Too early to destroy");
    }
    my $table_name = $self->table_name();
    unless( $table_name =~ /^testdelete/ ){
        confess("Sorry this is not a test table (from the test suite. Destroy manually if you are sure");
    }
    $log->warn("Will destroy $table_name from dynamoDB");
    my $deletion = $self->dynamo_db()->DeleteTable(TableName => $table_name);
    # Wait until the table is effectively destroyed.
    while( $self->table_exists() ){
        $log->warn("Table $table_name not destroyed yet. Waiting ".$self->creation_wait_time()." second");
        if( $self->creation_wait_time() ){
            sleep( $self->creation_wait_time() );
        }
    }
    $log->warn("Table $table_name DESTROYED");
    return $deletion;
}


__PACKAGE__->meta()->make_immutable();

