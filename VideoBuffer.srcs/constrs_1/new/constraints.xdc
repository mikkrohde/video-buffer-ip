#Set the RAM style to block ram
set_property RAM_STYLE BLOCK [get_cells -hierarchical *u_line_buffer/mem_reg]
set_property RAM_STYLE BLOCK [get_cells -hierarchical *u_frame_buffer/mem_reg]