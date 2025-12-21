# ============================================================================
# Package VideoBuffer as Vivado IP Core
# Usage: vivado -mode batch -source scripts/package_ip.tcl
# ============================================================================

set ip_name "VideoBuffer"
set vendor "github.com/mikkrohde"
set library "video_ip"
set version "1.0"

set script_dir [file dirname [file normalize [info script]]]
set project_dir "${script_dir}/.."
set src_dir "${project_dir}/src"
set ip_repo_dir "${project_dir}/ip_repo"

# Create IP repo directory
file mkdir $ip_repo_dir

# Create temporary project
create_project -in_memory -part xc7z020clg484-1

# Add VideoBuffer source
add_files "${src_dir}/VideoBuffer.v"
update_compile_order -fileset sources_1

# Package IP
ipx::package_project -root_dir "${ip_repo_dir}/${ip_name}_v${version}" \
    -vendor $vendor -library $library -force

# Set core properties
set core [ipx::current_core]
set_property name $ip_name $core
set_property display_name "Video Buffer" $core
set_property description "Configurable line buffer and frame buffer for video processing" $core
set_property vendor $vendor $core
set_property version $version $core

# Infer bus interfaces
ipx::infer_bus_interface clk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface rst_n xilinx.com:signal:reset_rtl:1.0 $core

# Create GUI groupings for parameters
ipgui::add_page -name {Configuration} -component $core
set page [ipgui::get_pagespec -name "Configuration" -component $core]

ipgui::add_param -name {MAX_WIDTH} -component $core -parent $page
set_property display_name "Maximum Width" [ipgui::get_guiparamspec -name "MAX_WIDTH" -component $core]

ipgui::add_param -name {MAX_HEIGHT} -component $core -parent $page
set_property display_name "Maximum Height" [ipgui::get_guiparamspec -name "MAX_HEIGHT" -component $core]

ipgui::add_param -name {PIXEL_WIDTH} -component $core -parent $page
set_property display_name "Pixel Width (bits)" [ipgui::get_guiparamspec -name "PIXEL_WIDTH" -component $core]

ipgui::add_param -name {USE_LINE_BUFFER} -component $core -parent $page
set_property display_name "Enable Line Buffer" [ipgui::get_guiparamspec -name "USE_LINE_BUFFER" -component $core]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "USE_LINE_BUFFER" -component $core]

ipgui::add_param -name {USE_FRAME_BUFFER} -component $core -parent $page
set_property display_name "Enable Frame Buffer" [ipgui::get_guiparamspec -name "USE_FRAME_BUFFER" -component $core]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "USE_FRAME_BUFFER" -component $core]

# Save IP
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

puts "=========================================="
puts "IP packaged successfully!"
puts "Location: ${ip_repo_dir}/${ip_name}_v${version}"
puts "=========================================="

close_project
