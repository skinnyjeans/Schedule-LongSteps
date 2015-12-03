#! perl -wt

use Test::More;

use_ok('Schedule::LongSteps');
use_ok('Schedule::LongSteps::Storage');
use_ok('Schedule::LongSteps::Storage::DBI');

done_testing();
