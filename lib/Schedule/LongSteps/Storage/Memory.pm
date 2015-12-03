package Schedule::LongSteps::Storage::Memory;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

use DateTime;

use MooseX::Iterator;

=head1 NAME

Schedule::LongSteps::Storage::DBIxClass - DBIx::Class based storage.

=head1 SYNOPSIS

  my $storage = Schedule::LongSteps::Storage::Memory->new();

Then build and use a L<Schedule::LongSteps> object:

  my $long_steps = Schedule::LongSteps->new({ storage => $storage });

  ...


=cut

has 'steps' => ( is => 'ro', isa => 'ArrayRef[Schedule::LongSteps::Storage::Memory::Step]', default => sub{ []; } );

=head2 prepare_due_steps

See L<Schedule::LongSteps::Storage::DBIxClass>

=cut

sub prepare_due_steps{
    my ($self) = @_;

    my $now = DateTime->now();
    my $uuid = $self->uuid()->create_str();

    my @to_run = ();
    foreach my $step ( @{ $self->steps() } ){
        if( $step->run_at()
                && !$step->run_id()
                && ( DateTime->compare( $step->run_at(),  $now ) <= 0 ) ){
            $step->update({
                run_id => $uuid,
                status => 'running'
            });
            push @to_run , $step;
        }
    }
    return  MooseX::Iterator::Array->new( collection => \@to_run );
}

=head2 create_step

See L<Schedule::LongSteps::Storage>

=cut

sub create_step{
    my ($self, $step_properties) = @_;
    my $step = Schedule::LongSteps::Storage::Memory::Step->new($step_properties);
    push @{$self->steps()} , $step;
    return $step;
}

__PACKAGE__->meta->make_immutable();

package Schedule::LongSteps::Storage::Memory::Step;

use Moose;

use DateTime;

has 'process_class' => ( is => 'ro', isa => 'Str', required => 1);
has 'process_id' => ( is => 'ro', isa => 'Str', required => 1 );
has 'status' => ( is => 'rw', isa => 'Str', default => 'pending' );
has 'what' => ( is => 'rw' ,  isa => 'Str', required => 1);
has 'run_at' => ( is => 'rw', isa => 'Maybe[DateTime]', default => sub{ undef; } );
has 'run_id' => ( is => 'rw', isa => 'Maybe[Str]', default => sub{ undef; } );
has 'state' => ( is => 'rw', default => sub{ {}; });
has 'error' => ( is => 'rw', isa => 'Maybe[Str]', default => sub{ undef; } );

sub update{
    my ($self, $update_properties) = @_;
    $update_properties //= {};

    # use Data::Dumper;
    # warn "Updating with ".Dumper($update_properties);

    while( my ( $key, $value ) = each %{$update_properties} ){
        $self->$key( $value );
    }
}

__PACKAGE__->meta->make_immutable();
