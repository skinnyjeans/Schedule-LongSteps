package Schedule::LongSteps::Storage::DBIxClass;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

use Data::UUID;
use DateTime;

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1);
has 'resultset_name' => ( is => 'ro', isa => 'Str', required => 1);

has 'uuid' => ( is => 'ro', isa => 'Data::UUID', lazy_build => 1);

sub _get_resultset{
    my ($self) = @_;
    return $self->schema()->resultset($self->resultset_name());
}

sub _build_uuid{
    my ($self) = @_;
    return Data::UUID->new();
}

=head1 NAME

Schedule::LongSteps::Storage::DBIxClass - DBIx::Class based storage.

=head1 SYNOPSIS

First instanciate a storage with your L<DBIx::Class::Schema> and the name
of the resultset that represent the set of steps:

  my $storage = Schedule::LongSteps::Storage::DBIxClass->new({
                   schema => $dbic_schema,
                   resultset_name => 'LongstepsStep'
                });

Then build and use a L<Schedule::LongSteps> object:

  my $long_steps = Schedule::LongSteps->new({ storage => $storage });

  ...

=head1 RESULTSET REQUIREMENTS

The resultset to use with this storage MUST contain the following columns, constraints and indices:

=over

=item a primary key of your choice

But the old 'id PRIMARY KEY AUTO_INCREMENT' (or any equivalent) will do.

=item process_class

A VARCHAR long enough to hold  your L<Schedule::LongSteps::Process> class names. NOT NULL.

=item status

A VARCHAR(50) NOT NULL, defaults to 'pending'

=item run_at

A Datetime (or timestamp with timezone in PgSQL). Will hold a UTC Timezoned date of the next run. Default to NULL.

Please index this so it is fast to select a range.

=item run_id

A CHAR or VARCHAR (at least 36). Default to NULL.

Please index this so it is fast to select rows with a matching run_id

=item state

A Reasonably long TEXT field (or JSON field in supporting databases) capable of holding
a JSON dump of pure Perl data. NOT NULL and defaults to  '{}';

=item error

A reasonably long TEXT field capable of holding a full stack trace in case something goes wrong. Defaults to NULL.

=back

=cut

=head2 prepare_due_steps

See L<Schedule::LongSteps::Storage::DBIxClass>

=cut

sub prepare_due_steps{
    my ($self) = @_;

    my $now = DateTime->now();
    my $rs = $self->_get_resultset();
    my $dtf = $self->schema()->storage()->datetime_parser();

    my $uuid = $self->uuid()->create_str();

    # Move the due ones to a specific 'transient' running status
    $rs->search({
       run_at => { '<=' => $dtf->format_datetime( $now ) },
       run_id => undef,
    })->update({
        run_id => $uuid,
        status => 'running'
    });

    # And return them as a resultset
    return $rs->search({
        run_id => $uuid,
    });
}

__PACKAGE__->meta->make_immutable();
