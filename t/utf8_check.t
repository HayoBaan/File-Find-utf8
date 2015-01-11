#!perl
use strict;
use warnings;
use Test::Warn;
use Test::Exception tests => 3;

# Tests whether setting $File::Find::utf8::UTF8_CHECK has the required result

use Encode ();
use File::Find::utf8;
no warnings 'File::Find'; # Turn off File::Find warnings

# Arguments to find, with an illegal Unicode character
my @find_args = ( sub { }, "Illegal \x{d800} character" );

# Croak on faulty utf-8
{
    Test::Exception::throws_ok
          {
              find(@find_args);
          }
          qr/"\\x\{d800\}" does not map to utf8/,
          'croak on encoding error (default)';
}

# Warn on faulty utf-8
{
    local $File::Find::utf8::UTF8_CHECK = Encode::FB_WARN;
    Test::Warn::warning_is
          {
              find(@find_args);
          }
          qq("\\x\{d800\}" does not map to utf8),
          'warn on encoding error';
}

# Nothing on faulty utf-8
{
    local $File::Find::utf8::UTF8_CHECK = Encode::FB_DEFAULT;
    Test::Warn::warning_is
          {
              find(@find_args);
          }
          [],
          'no warn on encoding error';
}
