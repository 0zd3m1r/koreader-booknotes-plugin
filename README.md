# BookNotes - A KOReader Plugin

A simple plugin for KOReader that lets you view book-specific notes from a `book_notes.txt` file, organized by sections.

I created this plugin because I wanted a simple way to keep text-based notes (like character lists, chapter summaries, or quotes) for my books without them becoming one long, unmanageable file.

## Features

* Adds a "Book Notes" item to the KOReader main menu.
* Automatically looks for a `book_notes.txt` file inside your book's `.sdr` directory.
* Parses the `.txt` file using simple `=== Header ===` syntax.
* Presents your notes in a clean menu, one item per section.
* Includes an "All Notes" option to view the raw file.
* Groups any text before the first header into a "General Notes" section.

## How to Use

1.  Make sure the plugin is installed (see **Installation** below).
2.  Open any book in KOReader.
3.  Using a file explorer, navigate to your book's `.sdr` folder (e.g., `/books/MyBook.epub.sdr/`).
4.  Create a file named exactly `book_notes.txt` inside this directory.
5.  Add your notes to this file, using the format described below.
6.  In KOReader, tap the top menu, find and tap "Book Notes".
7.  A menu will appear showing the sections you created.

## Note File Format

The plugin parses any line that starts and ends with `===` as a section header.

**Example `book_notes.txt`:**

```text
These are my general, un-sectioned notes.
They will appear under the "General Notes" menu item.

=== Characters ===
- Alice: The protagonist.
- Bob: The mysterious stranger.
- Carol: The ally.

=== Chapter 1 Summary ===
The story begins on a dark and stormy night.
A lot of important plot points are introduced.

=== Favorite Quotes ===
"It was the best of times, it was the worst of times..."
"To be, or not to be..."
```

When you open the plugin with this file, you will see a menu with these options:

  . Characters
  . Chapter 1 Summary
  . Favorite Quotes
  . General Notes (containing the text before the first header)
  . All Notes (shows the complete file content)

## Installation

1. [Download](https://github.com/0zd3m1r/koreader-booknotes-plugin/archive/refs/heads/main.zip) the latest booknotes.koplugin.zip file.
2. Extract the zip file. You should now have a booknotes.koplugin folder.
3. Copy this entire booknotes.koplugin folder to your KOReader's plugins directory. (This is usually at koreader/plugins/).
4. Restart KOReader.

## License

This project is licensed under the MIT License.
