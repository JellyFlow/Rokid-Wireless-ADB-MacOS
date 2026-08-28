import os

application = defines["app"]
background_image = defines["background"]
install_guide = defines["guide"]
app_name = os.path.basename(application)
guide_name = os.path.basename(install_guide)

files = [application, install_guide]
symlinks = {"Applications": "/Applications"}

window_rect = ((160, 120), (760, 520))
background = background_image
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
default_view = "icon-view"
include_icon_view_settings = True

icon_size = 112
text_size = 16
icon_locations = {
    app_name: (170, 300),
    "Applications": (590, 300),
    guide_name: (380, 400),
}

format = "UDZO"
compression_level = 9
