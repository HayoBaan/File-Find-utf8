#!perl
use strict;
use warnings;
use Test::More 0.96;
use Test::Warn;
use Encode qw(decode FB_CROAK);

# Test files
my $test_root     = "test_files";
my $unicode_file  = "\x{30c6}\x{30b9}\x{30c8}\x{30d5}\x{30a1}\x{30a4}\x{30eb}";
my $unicode_dir   = "\x{30c6}\x{30b9}\x{30c8}\x{30c6}\x{3099}\x{30a3}\x{30ec}\x{30af}\x{30c8}\x{30ea}";

if ($^O eq 'dos' or $^O eq 'os2') {
    plan skip_all => "Skipped: $^O does not have proper utf-8 file system support";
} else {
    # Create test files
    mkdir $test_root
        or die "Unable to create directory $test_root: $!"
        unless -d $test_root;
    mkdir "$test_root/$unicode_dir"
        or die "Unable to create directory $test_root/$unicode_dir: $!"
        unless -d "$test_root/$unicode_dir";
    chmod 0755, "$test_root/$unicode_dir" or die "Failed to grant access to $test_root/$unicode_dir: $!";
    for ("$unicode_dir/bar", $unicode_file) {
        open my $touch, '>', "$test_root/$_" or die "Couldn't open $test_root/$_ for writing: $!";
        close   $touch                       or die "Couldn't close $test_root/$_: $!";
    }
}

# Expected output of find commands
my @expected = sort ($test_root, "$test_root/$unicode_file", "$test_root/$unicode_dir", "$test_root/$unicode_dir/bar");

plan tests => 3;

# Runs find tests

for my $test (0, 1) {
    subtest utf8find => sub {
        plan tests => 8;

        # To keep results in
        my @files;
        my @utf8_files;

        # Use normal find to gather list of files in the test_root directory
        {
            use File::Find;
            ($test ? \&finddepth : \&find)->({ no_chdir => 1, wanted => sub { push(@files, $_) if $_ !~ /\.{1,2}/ } }, $test_root);
        }

        # Use utf8 version of find to gather list of files in the test_root directory
        {
            use File::Find::utf8;
            ($test ? \&finddepth : \&find)->({ no_chdir => 1, wanted => sub { push(@utf8_files, $_) if $_ !~ /\.{1,2}/ } }, $test_root);
        }

        # Compare results
        @files      = sort @files;
        @utf8_files = sort @utf8_files;
        is_deeply \@utf8_files, \@expected; # utf8 version should match exactly with expected results
        is   $files[0] => $utf8_files[0]; # test_root
        isnt $files[1] => $utf8_files[1]; # test_root/unicode_file
        isnt $files[2] => $utf8_files[2]; # test_root/unicode_dir
        isnt $files[3] => $utf8_files[3]; # test_root/unicode_dir/bar
        is   decode('UTF-8', $files[1], FB_CROAK) => $utf8_files[1]; # But should match when UTF8-decoded
        is   decode('UTF-8', $files[2], FB_CROAK) => $utf8_files[2]; # But should match when UTF8-decoded
        is   decode('UTF-8', $files[3], FB_CROAK) => $utf8_files[3]; # But should match when UTF8-decoded
    };
}

# Check if warnings levels progate well
subtest warninglevels => sub {
    plan tests => 3;

    # Remove access to unicode_dir
    chmod 0000, "$test_root/$unicode_dir" or die "Failed to revoke access to $test_root/$unicode_dir: $!";

    use File::Find::utf8;
    my @utf8_files;

    # Test no warnings in File::Find
    warning_is
        {
            no warnings 'File::Find';
            find( { no_chdir => 1, wanted => sub { push(@utf8_files, $_) if $_ !~ /\.{1,2}/ } }, $test_root);
        }
        undef, 'No warning for unaccessible directory';

    # Test warnings in File::Find
    warning_like
        {
            #use warnings 'File::Find'; # This is actually the default
            find( { no_chdir => 1, wanted => sub { push(@utf8_files, $_) if $_ !~ /\.{1,2}/ } }, $test_root);
        }
        qr/Can't opendir/, 'Warning for unaccessible directory' or diag $@;

    # Test fatal warnings in File::Find
    warning_like
        {
            eval {
                use warnings FATAL => 'File::Find';
                find( { no_chdir => 1, wanted => sub { push(@utf8_files, $_) if $_ !~ /\.{1,2}/ } }, $test_root);
            };
            warn $@;
        }
        qr/Can't opendir/, 'Warning for unaccessible directory' or diag $@;

    # Reset directory permissions
    chmod 0755, "$test_root/$unicode_dir" or die "Failed to grant access to $test_root/$unicode_dir: $!";
}
