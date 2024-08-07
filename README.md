# A Matrix Processing Core Design written in VHDL
## Target: xc7a15tcsg324-1

**Additional Comments:**
Matrix multiplier : A * B * C = D 
Input matrix: A, B, C - Size: 16 x 16 - 8 bits (Signed)
Output matrix: D - Size: 16 x 16 - 56 bits

This matrix processing core is able to do matrix multiplication (Fig. 1) for matrixes with the size of 16 x 16 and an 8-bit signed integer for each element of the input matrixes (A, B and C). The design was verified via both behavioural and implementation simulations.
<img width="1173" alt="Screenshot 2024-08-07 at 09 36 18" src="https://github.com/user-attachments/assets/2dce4150-3e7d-444d-af3e-a1570b051e9b">
<p align=center> (Fig.1) </p>

                                                
# Getting Everything Running
1. Install Vivado (Version 2018.3)
2. Clone this Repository
3. Open the included Vivado Project File

## Notes
- When running a simulation, the testbench uses a set of files in the 'MatProcCore.sim/sim_1/behav/xsim' to load in the matrix data for the A,B,C matricies. The output from the FPGA is compared to the output from a matlab script. 
- Viewing output.txt will show the result of the multiplication.
