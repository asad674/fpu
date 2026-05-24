if {![info exists OP]} { set OP "add" }
if {![info exists MODE]} { set MODE "RNE" }
if {![info exists IN]} { set IN "$(PROJECT_PATH)/add/vectors" }
if {![info exists OUT]} { set OUT "$(PROJECT_PATH)/add/vectors" }

quit -sim

# Load the compiled design (only if not already loaded)
if {[catch {vsim work_${OP}.${OP}_tb}]} {
    echo "Design already loaded"
} else {
     vsim work_${OP}.${OP}_tb +MODE=$MODE +IN=$IN +OUT=$OUT
}


# Add signals to the waveform
#add wave -position insertpoint sim:/add_tb/*
add wave -r sim:/${OP}_tb/*

radix signal in1 float32
radix signal in2 float32
radix signal out float32
radix signal exp_res float32

# Ensure the wave window is visible
view wave

# Run the simulation
run -all
