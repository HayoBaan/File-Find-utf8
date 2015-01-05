#!perl
use strict;
use warnings;
use Test::More 0.96;
use Test::Warn;
use Encode qw(encode decode FB_CROAK);

# Enable utf-8 encoding so we do not get Wide character in print
# warnings when reporting test failures
use open qw{:encoding(UTF-8) :std};

plan skip_all => "Skipped: $^O does not have proper utf-8 file system support"
    if ($^O =~ /MSWin32|cygwin|dos|os2/);

# Create test files
my $test_root     = "corpus.tmp";
my $unicode_file  = "\x{30c6}\x{30b9}\x{30c8}\x{30d5}\x{30a1}\x{30a4}\x{30eb}";
my $unicode_dir   = "\x{30c6}\x{30b9}\x{30c8}\x{30c6}\x{3099}\x{30a3}\x{30ec}\x{30af}\x{30c8}\x{30ea}";
mkdir $test_root
    or die "Unable to create directory $test_root: $!"
    unless -d $test_root;
mkdir "$test_root/$unicode_dir"
    or die "Unable to create directory $test_root/$unicode_dir: $!"
    unless -d "$test_root/$unicode_dir";
for ("$unicode_dir/bar", $unicode_file) {
    open my $touch, '>', "$test_root/$_" or die "Couldn't open $test_root/$_ for writing: $!";
    close   $touch                       or die "Couldn't close $test_root/$_: $!";
}

# Expected output of find commands
my @expected = sort ($test_root, "$test_root/$unicode_dir", "$test_root/$unicode_dir/bar", "$test_root/$unicode_file");

# Check utf8 and non-utf8 results
sub check_results {
    my ($test, $utf8, $non_utf8) = @_;
    my @utf8     = sort @{$utf8};     # Sort to overcome difference in find and finddepth
    my @non_utf8 = sort @{$non_utf8}; # Sort to overcome difference in find and finddepth
    my @utf8_encoded     = map { encode('UTF-8', "$_", FB_CROAK); } @utf8;     # Quotes to prevent tampering by encode/decode!
    my @non_utf8_decoded = map { decode('UTF-8', "$_", FB_CROAK); } @non_utf8; # Quotes to prevent tampering by encode/decode!

    plan tests => 3;

    is_deeply \@utf8, \@expected,         "$test all utf8 files are present";
    is_deeply \@utf8, \@non_utf8_decoded, "$test utf8 files match decoded non-utf8";
    is_deeply \@utf8_encoded, \@non_utf8, "$test encoded utf8 files match non-utf8";
}

plan tests => 4;

# Check find and finddepth
for my $test (qw(find finddepth)) {
    subtest "utf8$test" => sub {
        # To keep results in
        my @utf8;
        my @non_utf8;

        # Use normal find to gather list of files in the test_root directory
        {
            use File::Find;
            (\&{$test})->({ no_chdir => 1, wanted => sub { push(@non_utf8, $_) if $_ !~ /^\.{1,2}$/ } }, $test_root);
        }

        # Use utf8 version of find to gather list of files in the test_root directory
        {
            use File::Find::utf8;
            (\&{$test})->({ no_chdir => 1, wanted => sub { push(@utf8, $_) if $_ !~ /^\.{1,2}$/ } }, $test_root);
        }

        # Compare results
        check_results($test, \@utf8, \@non_utf8);
    };
}

# Check no File::Find::utf8;
subtest no_file_find_utf8 => sub {
    my $test = "no File::Find::utf8";

    # To keep results in
    my @utf8;
    my @non_utf8;

    # Use utf8 version of find to gather list of files in the test_root directory
    use File::Find::utf8;
    find({ no_chdir => 1, wanted => sub { push(@utf8, $_) if $_ !~ /^\.{1,2}$/ } }, $test_root);

    # Turn of utf8 extensions;
    no File::Find::utf8;
    find({ no_chdir => 1, wanted => sub { push(@non_utf8, $_) if $_ !~ /^\.{1,2}$/ } }, $test_root);

    # Compare results
    check_results($test, \@utf8, \@non_utf8);
};

# Check if warnings levels progate well
subtest warninglevels => sub {
    plan tests => 3;

    use File::Find::utf8;

    # Test no warnings in File::Find
    warning_is
        {
            no warnings 'File::Find';
            find( { no_chdir => 1, wanted => sub { } }, "$test_root/does_not_exist");
        }
        undef, 'No warning for non-existing directory';

    # Test warnings in File::Find
    warning_like
        {
            #use warnings 'File::Find'; # This is actually the default
            find( { no_chdir => 1, wanted => sub { } }, "$test_root/does_not_exist");
        }
        qr/Can't stat $test_root\/does_not_exist/, 'Warning for non-existing directory' or diag $@;

    # Test fatal warnings in File::Find
    warning_like
        {
            eval {
                use warnings FATAL => 'File::Find';
                find( { no_chdir => 1, wanted => sub { } }, "$test_root/does_not_exist");
            };
            warn $@ if $@;
        }
        qr/Can't stat $test_root\/does_not_exist/, 'Fatal warning for non-existing directory' or diag $@;
};

# Cleanup temporarily created files and directories
use File::Path qw(remove_tree);
remove_tree($test_root) or die "Unable to remove $test_root";
