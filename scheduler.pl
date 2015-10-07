#! /usr/bin/perl
use strict;
use warnings;
use diagnostics;
use feature ':5.14';
use Gtk3 '-init';
use Glib qw/TRUE FALSE/;
use utf8;
use autodie;

use constant {
    WEEKDAYS => [qw(P W S C P)],
    HOURS    => [ map { sprintf '%02d:00', $_ } 8, 10, 12, 14, 16, 18, 20 ],
    STATUSES => [qw(. v e x)],
    INDENT   => ' ' x 4,
};

# Gtk parameter constants for readability
use constant {
    COLUMN_FIXED       => 0,
    COLUMN_NUMBER      => 1,
    COLUMN_SEVERITY    => 2,
    COLUMN_DESCRIPTION => 3,
    PACK_DEFAULTS      => [ TRUE, TRUE, 0 ],
    LSTORE_TYPES => [qw(Glib::Boolean Glib::Uint Glib::String Glib::String)],
};

# Initialize the window
my $window = Gtk3::Window->new('toplevel');
$window->set_title("New plan");
$window->set_position("mouse");
$window->set_default_size(400, 50);
$window->set_border_width(20);
$window->signal_connect(delete_event => \&Gtk3::main_quit);

my $rows = Gtk3::Box->new('vertical', scalar @{ (HOURS) } + 2);
$rows->set_homogeneous(TRUE);
$window->add($rows);

my $title_entry = Gtk3::Entry->new();
$title_entry->set_text('Untitled plan');
$rows->add($title_entry);

# Create header with weekday labels
my $header = Gtk3::Box->new('horizontal', scalar @{ (WEEKDAYS) } + 1);
foreach my $text (' ', @{ (WEEKDAYS) }) {    # Dirty layout hack, I know
    $header->pack_start(Gtk3::Label->new($text), @{ (PACK_DEFAULTS) });
}
$rows->add($header);

# Generate buttons for status selection, keep them in a table for later access
my %table;
foreach my $hour (@{ (HOURS) }) {
    my $hbox = Gtk3::Box->new('horizontal', scalar @{ (WEEKDAYS) } + 1);
    $hbox->set_homogeneous(TRUE);
    $hbox->pack_start(Gtk3::Label->new($hour), @{ (PACK_DEFAULTS) });

    foreach my $day (@{ (WEEKDAYS) }) {
        my $day_entry = gen_combobox(@{ (STATUSES) });
        $day_entry->set_active(0);
        $hbox->pack_start($day_entry, @{ (PACK_DEFAULTS) });
        push @{ $table{$hour} }, $day_entry;
    }

    $rows->add($hbox);
}

# Box for main program control button
my $control_box = Gtk3::Box->new('horizontal', 3);
$rows->add($control_box);

# Button to exit the program
my $cancel_button = Gtk3::Button->new('Close');
$cancel_button->signal_connect(clicked => \&Gtk3::main_quit);
$control_box->pack_start($cancel_button, @{ (PACK_DEFAULTS) });

# Button to reset all status selectors
my $reset_button = Gtk3::Button->new('Reset');
$reset_button->signal_connect(clicked => \&reset_selection);
$control_box->pack_start($reset_button, @{ (PACK_DEFAULTS) });

# Button to save the plan
my $save_button = Gtk3::Button->new('Save');
$save_button->signal_connect(clicked => \&save);
$control_box->pack_start($save_button, @{ (PACK_DEFAULTS) });

$window->show_all;
Gtk3->main;

# Set all comboboxes in main data table to their default value
sub reset_selection {
    $title_entry->set_text('');
    foreach my $ra_hour (values %table) {
        foreach my $combobox (@$ra_hour) {
            $combobox->set_active(0);
        }
    }
    return;
}

# Display a file chooser dialog and save current state
sub save {
    my $dialog = Gtk3::FileChooserDialog->new(
        'Select a File',    # Title
        $window,            # Parent
        'save',             # Action
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok',
    );

    if ('ok' eq $dialog->run) {
        my $file = $dialog->get_filename;
        write_state($file);
        sleep 0.5;          # TODO: Better ending/shutdown UX
        Gtk3::main_quit;
    }
    $dialog->destroy;
    return;
}

# Write current data table state to a file
sub write_state {
    my $fname = shift;

    open my $FH, '>', $fname;

    # Write underlined title
    my $title = $title_entry->get_text();
    say $FH $title;
    say $FH '=' x length $title;
    print $FH "\n";

    # Write availability status
    say $FH INDENT, join ' ', 'GODZ.', @{ (WEEKDAYS) };
    foreach my $hour (@{ (HOURS) }) {
        say $FH INDENT, join ' ', $hour,
          map get_state_str($_), @{ $table{$hour} };
    }
    close $FH;

    return;
}

sub get_state_str {
    my $combobox   = shift;
    my $active_idx = $combobox->get_active();
    return ${ (STATUSES) }[$active_idx];
}

# Generate a simple combobox with the subs arguments as entries
sub gen_combobox {
    my $combobox = Gtk3::ComboBoxText->new;
    $combobox->append_text($_) foreach @_;
    return $combobox;
}
