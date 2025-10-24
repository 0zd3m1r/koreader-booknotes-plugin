-- koreader/plugins/booknotes.koplugin/main.lua
--
-- BookNotes Plugin
-- Allows users to view notes from a 'book_notes.txt' file located in the book's .sdr directory.
-- Supports section parsing using '=== Section Name ===' headers.

-- Import required KOReader modules
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local InputDialog = require("ui/widget/inputdialog")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local _ = require("gettext")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local Device = require("device")
local Screen = Device.screen
local ffiUtil = require("ffi/util")
local T = ffiUtil.template

-- Main plugin class definition
local BookNotes = WidgetContainer:extend{
    name = "booknotes",
    title = _("Book Notes"),
    NOTE_FILENAME = "book_notes.txt",
}

-- init: Plugin initialization
-- Registers the plugin to the main menu.
function BookNotes:init()
    self.ui.menu:registerToMainMenu(self)
    logger.info("BookNotes: Plugin initialized and registered to main menu.")
end

-- addToMainMenu: Adds the plugin entry to the main menu table.
function BookNotes:addToMainMenu(menu_items)
    menu_items.booknotes = {
        text = self.title,
        callback = function()
            self:showBookNotes()
        end,
    }
end

-- showBookNotes: The main entry point when the user clicks the menu item.
-- It finds the current book, locates its .sdr directory, and looks for the note file.
function BookNotes:showBookNotes()
    logger.info("BookNotes: Showing notes...")

    -- Check if a document is currently open
    if not self.ui or not self.ui.document or not self.ui.document.file then
        logger.warn("BookNotes: No book file found.")
        UIManager:show(InfoMessage:new{
            text = _("Please open a book first."),
            timeout = 3
        })
        return
    end

    local book_path = self.ui.document.file
    logger.info("BookNotes: Book path: " .. book_path)

    -- Find the associated .sdr directory for the book
    local sdr_path = self:findSDRPath(book_path)
    if not sdr_path then
        UIManager:show(InfoMessage:new{
            text = _("Could not find the notes directory for this book."),
            timeout = 3
        })
        return
    end

    -- Check if the specific note file exists
    local notes_file_path = ffiUtil.joinPath(sdr_path, self.NOTE_FILENAME)
    logger.info("BookNotes: Notes file path: " .. notes_file_path)

    local attr = lfs.attributes(notes_file_path)
    if attr and attr.mode == "file" then
        -- File exists, proceed to parse and show it
        self:parseAndShowSections(notes_file_path)
    else
        -- File does not exist
        UIManager:show(InfoMessage:new{
            text = T(_("%1 file not found."), self.NOTE_FILENAME),
            timeout = 3
        })
    end
end

-- findSDRPath: Locates the .sdr directory for a given book path.
-- KOReader might create 'book.epub.sdr' or just 'book.sdr'.
function BookNotes:findSDRPath(book_path)
    local book_dir = book_path:match("^(.*)/") or "."
    local book_filename_ext = book_path:match("/([^/]+)$") or book_path
    local book_base_name = book_filename_ext:gsub("%.[^.]+$", "")

    -- Try possible .sdr directory names
    local possible_sdr_names = {
        book_filename_ext .. ".sdr",
        book_base_name .. ".sdr"
    }

    for _, sdr_name in ipairs(possible_sdr_names) do
        local potential_path = ffiUtil.joinPath(book_dir, sdr_name)
        local attr = lfs.attributes(potential_path)
        if attr and attr.mode == "directory" then
            logger.info("BookNotes: .sdr directory found: " .. potential_path)
            return potential_path
        end
    end

    logger.warn("BookNotes: .sdr directory not found.")
    return nil
end

-- parseAndShowSections: Reads the notes file and decides whether to show
-- a section menu or the full content.
function BookNotes:parseAndShowSections(filepath)
    local sections, section_order = self:parseNotesFile(filepath)

    if not sections then
        UIManager:show(InfoMessage:new{
            text = _("Error reading notes file."),
            timeout = 3
        })
        return
    end

    if #section_order == 0 then
        -- No sections found (or file is empty), just show the full content
        logger.info("BookNotes: No sections found, showing full note content.")
        self:showFullNoteContent(filepath)
    else
        -- Sections were found, display the selection menu
        self:showSectionMenu(sections, section_order, filepath)
    end
end

-- parseNotesFile: Reads the note file line-by-line and parses it into sections.
-- Sections are delimited by '=== Header Name ==='.
function BookNotes:parseNotesFile(filepath)
    logger.info("BookNotes: Parsing file: " .. filepath)

    local file = io.open(filepath, "r")
    if not file then
        logger.error("BookNotes: Could not open file: " .. filepath)
        return nil
    end

    local sections = {}
    local section_order = {}
    local current_section_name = nil
    local current_section_lines = {}
    -- Regex for the header, e.g., "=== My Section ==="
    local header_pattern = "^%s*===%s*([^=]+)%s*===%s*$"

    -- Helper function to save the accumulated lines for the previous section
    local function save_previous_section()
        if current_section_name then
            local section_text = table.concat(current_section_lines, "\n")
            -- Trim leading/trailing whitespace
            section_text = section_text:match("^%s*(.-)%s*$") or ""

            if section_text ~= "" then
                sections[current_section_name] = section_text
                logger.dbg("BookNotes: Saved section: " .. current_section_name ..
                               " (" .. string.len(section_text) .. " chars)")
            end

            current_section_lines = {}
        end
    end

    -- Read the file line by line
    for line in file:lines() do
        local header_match = line:match(header_pattern)

        if header_match then
            -- New header found: save the previous section and start a new one
            save_previous_section()
            current_section_name = header_match:match("^%s*(.-)%s*$")
            table.insert(section_order, current_section_name)
            logger.dbg("BookNotes: New header found: " .. current_section_name)
        else
            -- This is a normal content line
            if not current_section_name then
                -- This is text before any header, assign to a default section
                current_section_name = "__GENEL__" -- Internal name for "General"
                table.insert(section_order, current_section_name)
            end
            table.insert(current_section_lines, line)
        end
    end

    -- Save the last section after the loop finishes
    save_previous_section()
    file:close()

    logger.info("BookNotes: Found " .. #section_order .. " sections.")
    return sections, section_order
end

-- showSectionMenu: Displays a menu with all found sections.
function BookNotes:showSectionMenu(sections, section_order, original_filepath)
    local item_table = {}

    -- Add an "All Notes" option at the top
    table.insert(item_table, {
        text = _("📄 All Notes"),
        callback = function()
            self:showFullNoteContent(original_filepath)
        end,
        separator = true,
    })

    -- Add all named sections
    for _, section_name in ipairs(section_order) do
        if section_name ~= "__GENEL__" then
            local section_text = sections[section_name]
            table.insert(item_table, {
                text = "📑 " .. section_name,
                callback = function()
                    self:showSectionText(section_name, section_text or "")
                end,
            })
        end
    end

    -- If a general (no-header) section exists, add it to the end
    if sections["__GENEL__"] then
        table.insert(item_table, {
            text = _("📝 General Notes"),
            callback = function()
                self:showSectionText(_("General Notes"), sections["__GENEL__"])
            end,
            separator = true,
        })
    end

    local menu = Menu:new{
        title = _("Note Sections"),
        item_table = item_table,
        width = Screen:getWidth() * 0.9,
        height = Screen:getHeight() * 0.9,
    }

    UIManager:show(menu)
end

-- showSectionText: Displays the text content in a simple, read-only window.
-- Using InputDialog in read-only mode is a simple way to show scrollable text.
function BookNotes:showSectionText(title, text)
    logger.info("BookNotes: Showing text for: " .. title)

    if not text or text == "" then
        UIManager:show(InfoMessage:new{
            text = _("This section is empty."),
            timeout = 2
        })
        return
    end

    local input_dialog
    input_dialog = InputDialog:new{
        title = title,
        input = text,
        input_type = "text",
        text_height = Screen:getHeight() * 0.7,
        fullscreen = true,
        readonly = true, -- Read-only mode
        buttons = {
            {
                {
                    text = _("Close"),
                    is_enter_default = true,
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }

    UIManager:show(input_dialog)
end

-- showFullNoteContent: Reads and displays the entire content of the notes file.
function BookNotes:showFullNoteContent(filepath)
    logger.info("BookNotes: Showing full note content: " .. filepath)

    local file = io.open(filepath, "r")
    if not file then
        logger.error("BookNotes: Could not open file: " .. filepath)
        UIManager:show(InfoMessage:new{
            text = _("Could not read notes file."),
            timeout = 3
        })
        return
    end

    local content = file:read("*a")
    file:close()

    if content and content ~= "" then
        self:showSectionText(_("All Notes"), content)
    else
        UIManager:show(InfoMessage:new{
            text = _("Notes file is empty."),
            timeout = 3
        })
    end
end

-- Return the plugin class
return BookNotes