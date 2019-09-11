return {
identifiers = {
	-- ID, C++Name,      (Real Name)
	{   0, "none",       nil    },
	{   1, "left",       nil    },
	{   2, "center",     nil    },
	{   3, "right",      nil    },
	{   4, "top",        nil    },
	{   5, "middle",     nil    },
	{   6, "bottom",     nil    },
	{   7, "stretch",    nil    },
	{   8, "expand",     nil    },
	{   9, "_auto",      "auto" },
	{  10, "yesno",      nil    },
	{  11, "truefalse",  nil    },
	{  12, "onoff",      nil    },
	{  13, "visible",    nil    },
	{  14, "hidden",     nil    },
	{  15, "collapsed",  nil    },
	{  16, "vertical",   nil    },
	{  17, "horizontal", nil    },
	{  18, "sans",       nil    },
	{  19, "serif",      nil    },
	{  20, "monospace",  nil    },
	{  21, "percent",    nil    },
	{  22, "absolute",   nil    },
},

widgets = {
--    ID,  Enumeration,     ClassName       
    {   1, "button",        "Button"       },
    {   2, "label",         "Label"        },
    {   3, "combobox",      "ComboBox"     },
    {   4, "treeviewitem",  "TreeViewItem" },
    {   5, "treeview",      "TreeView"     },
    {   6, "listboxitem",   "ListBoxItem"  },
    {   7, "listbox",       "ListBox"      },
    --  8
    {   9, "picture",       "Picture"      },
    {  10, "textbox",       "TextBox"      },
    {  11, "checkbox",      "CheckBox"     },
    {  12, "radiobutton",   "RadioButton"  },
    {  13, "scrollview",    "ScrollView"   },
    {  14, "scrollbar",     "ScrollBar"    },
    {  15, "slider",        "Slider"       },
    {  16, "progressbar",   "ProgressBar"  },
    {  17, "spinedit",      "SpinEdit"     },
    {  18, "separator",     "Separator"    },
    {  19, "spacer",        "Spacer"       },
    {  20, "panel",         "Panel"        },

    -- widgets go here ↑
    -- layouts go here ↓

    { 250, "tab_layout",    "TabLayout"    },
    { 251, "canvas_layout", "CanvasLayout" },
    { 252, "flow_layout",   "FlowLayout"   },
    { 253, "grid_layout",   "GridLayout"   },
    { 254, "dock_layout",   "DockLayout"   },
    { 255, "stack_layout",  "StackLayout"  },
},

types = 
{--   ID,  Name,         C++ Type
	{   0, "invalid",     "std::monostate" },
    {   1, "integer",     "int"            },
    {   2, "number",      "float"          },
    {   3, "string",      "std::string"    },
    {   4, "enumeration", "uint8_t"        },
    {   5, "margins",     "UIMargin"       },
    {   6, "color",       "UIColor"        },
    {   7, "size",        "SDL_Size"       },
    {   8, "point",       "SDL_Point"      }, 
    {   9, "resource",    "UIResourceID"   },
    {  10, "boolean",     "bool"           },
	{  11, "sizelist",    "UISizeList"     },
},

properties = 
{--   ID,  Code Name,              Style Name,             Type,
    {   1, "horizontalAlignment",  "horizontal-alignment",   "enumeration" },
    {   2, "verticalAlignment",    "vertical-alignment",     "enumeration" },
    {   3, "margins",              "margins",                "margins"     },
    {   4, "paddings",             "paddings",               "margins"     },
    {   5, "stackDirection",       "stack-direction",        "enumeration" },
    {   6, "dockSite",             "dock-site",              "enumeration" },
    {   7, "visibility",           "visibility",             "enumeration" },
    {   8, "sizeHint",             "size-hint",              "size"        },
    {   9, "fontFamily",           "font-family",            "enumeration" },
    {  10, "text",                 "text",                   "string"      },
    {  11, "minimum",              "minimum",                "number"      },
    {  12, "maximum",              "maximum",                "number"      },
    {  13, "value",                "value",                  "number"      },
    {  14, "displayProgressStyle", "display-progress-style", "enumeration" },
    {  15, "isChecked",            "is-checked",             "boolean"     },
    {  16, "tabTitle",             "tab-title",              "string"      },
    {  17, "selectedIndex",        "selected-index",         "integer"     },
	{  18, "columns",              "columns",                "sizelist"    },
	{  19, "rows",                 "rows",                   "sizelist"    },
	{  20, "left",                 "left",                   "integer"     },
	{  21, "top",                  "top",                    "integer"     },
},

groups = 
{
	["UIFont"]               = { "sans", "serif", "monospace" },
	["HAlignment"]           = { "stretch", "left", "center", "right" },
	["VAlignment"]           = { "stretch", "top", "middle", "bottom" },
	["Visibility"]           = { "visible", "collapsed", "hidden" },
	["StackDirection"]       = { "vertical", "horizontal" },
	["DockSite"]             = { "top", "bottom", "left", "right" },
	["DisplayProgressStyle"] = { "none", "percent", "absolute" },
},

};
