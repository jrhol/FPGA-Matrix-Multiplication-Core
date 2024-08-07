----------------------------------------------------------------------------------
-- Company: UON
-- Engineer: James Holdsworth
-- 
-- Create Date: 26.03.2024 11:38:19
-- Design Name: IntMatProCore_16x16_8bits
-- Module Name: tb_IntMatProCore_16x16_8bits - tb
-- Project Name: 16x16 Signed 8Bit Matrix Processing Core
-- Target Devices: **********************xc7a15tcsg324-1***********************
-- Tool Versions: 
-- Description: Matrix Processing Core Design test bench
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity tb_IntMatProCore_16x16_8bits is
end tb_IntMatProCore_16x16_8bits;

architecture tb of tb_IntMatProCore_16x16_8bits is

-- BufferSel: "00" for input buffer A, "01" for input buffer B, "10" for input buffer C
component IntMatProCore
    Port(
        Reset, Clock, WriteEnable:      in std_logic;
        BufferSel:                      in std_logic_vector (1 downto 0);
        
        WriteAddress:                   in std_logic_vector (7 downto 0);
        WriteData:                      in std_logic_vector (7 downto 0);
        
        ReadAddress:                    in std_logic_vector (7 downto 0);
        ReadEnable:                     in std_logic;
        ReadData:                       out std_logic_vector (55 downto 0);
        
        DataReady:                      out std_logic
        );
end component;

-- Signals used for testbench definitions
signal tb_Reset:            std_logic := '0';
signal tb_Clock:            std_logic := '0';
signal tb_WriteEnable:      std_logic := '0';
signal tb_BufferSel:        std_logic_vector (1 downto 0) := (others => '0');

signal tb_WriteAddress:     std_logic_vector (7 downto 0) := (others => '0');
signal tb_WriteData:        std_logic_vector (7 downto 0) := (others => '0');
signal tb_ReadEnable:       std_logic := '0';
signal tb_ReadAddress:      std_logic_vector (7 downto 0) := (others => '0');

signal tb_ReadData:         std_logic_vector (55 downto 0) := (others => '0');
signal tb_DataReady:        std_logic := '0';

-- Clock definition
-- Clock frequency = 5 MHz
constant period : time := 200 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut_IntMatProCore : IntMatProCore
        Port Map(
            Reset           => tb_Reset,
            Clock           => tb_Clock,
            WriteEnable     => tb_WriteEnable,
            BufferSel       => tb_BufferSel,
            
            WriteAddress    => tb_WriteAddress,
            WriteData       => tb_WriteData,
            
            ReadAddress     => tb_ReadAddress,
            ReadEnable      => tb_ReadEnable,
            ReadData        => tb_ReadData,
            
            DataReady       => tb_DataReady
        );
        
    -- Clock generation process
    process is
    begin
        while now <= 20000 * period loop 
            tb_Clock <= '0';
            wait for period / 2;
            tb_Clock <= '1';
            wait for period / 2;
        end loop;
        wait;
    end process;

    -- Reset generation process
    process is
    begin
        tb_Reset <= '1';
        wait for 10 * period;
        tb_Reset <= '0';
        wait;   --Run Once and then Wait   
    end process;
    
    --Now Writing the Input Data into the buffers
	writing: process is						
		--Creating Objects to Handle the Input Files
		file FIA: TEXT open READ_MODE is "AMatrix.txt";    
		file FIB: TEXT open READ_MODE is "BMatrix.txt";    
		file FIC: TEXT open READ_MODE is "CMatrix.txt";
		--Define Extra Variables for Write Process
		variable L: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);    -- Pre-character space: "    '"
		variable tb_MatrixData: std_logic_vector(7 downto 0); -- Each value inhte matrix contains 8 bits of data
	begin
	   --Init
		tb_WriteEnable <= '0';
		tb_WriteAddress <= x"FF"; --Write Address set to max (we add +1 first so overflows and starts at 0)
		
		wait for 20*period;
		
		--Write "InputA.txt" to RAM A
		while not ENDFILE(FIA)  loop
			READLINE(FIA, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			--Iterate through all addresses
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "00";
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
		
		--Write "InputB.txt" to RAM B	
		while not ENDFILE(FIB)  loop
			READLINE(FIB, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			--Iterate through all addresses
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "01";
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
		
	   --Write "InputC.txt" to RAM C	
		while not ENDFILE(FIC)  loop
			READLINE(FIC, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			--Iterate through all addresses
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "10";
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
		
		wait for period;
		tb_WriteEnable <= '0';	
--		tb_BufferSel <= "00";                 --Set Write buffer back to 0	
--		tb_WriteAddress <= (others => '0');   --Set write address to 0
--		tb_WriteData <= (others => '0');      --Set Write data to 0
		wait;     --End Writing Process after it has run once
	end process;    
    
    --Now Perform the Reading Process
    reading: process is				
        --Creating File Objects		
		file FO: TEXT open WRITE_MODE is "OutputD.txt";       --File To output to
		file FI: TEXT open READ_MODE is "DMatrix_Matlab.txt"; --File containing matlab calculated answer, used as comparison
		-- Define variables
		variable L, Lm: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);    -- Pre-character space: "    '"
		variable v_ReadDatam: std_logic_vector(55 downto 0);  -- Each matrix element contains 56 bits data
		variable v_OK: boolean;                               --Comparison Variable
	begin
		tb_ReadEnable <= '0';
		tb_ReadAddress <=(others =>'0');
		
		---wait for Matrix Multiplication to be done	
		wait until rising_edge(tb_DataReady); 
		wait until falling_edge(tb_DataReady); 

        -- Write to "OutputD.txt"
		Write(L, STRING'("Matrix Multiplication Results"));
		WRITELINE(FO, L); --Newline
		Write(L, STRING'("Data from Matlab"), Left, 20);
		Write(L, STRING'("Data from Simulation"), Left, 20);
		WRITELINE(FO, L); --Newline
		tb_ReadEnable<= '1';
		while not ENDFILE(FI)  loop
			wait until rising_edge(tb_Clock);
			wait for 10 ns;      --Wait for data to reach 'Read Data' Port
			
			READLINE(FI, Lm);    --Read Matlab Data
			READ(Lm, tb_PreCharacterSpace);      -- Pre-character space: "    '"
			HREAD(Lm, v_ReadDatam);		
			if v_ReadDatam = tb_ReadData then    --Compare Matlab data to calculated data
				v_OK := True;
			else
				v_OK := False;
			end if;
			HWRITE(L, v_ReadDatam, Left, 20);    --Write matlab data
			HWRITE(L, tb_ReadData, Left, 20);    --Write Buffer D data
			WRITE(L, v_OK, Left, 10);			 -- Write Outcome of Comparison
			WRITELINE(FO, L);    --Newline	

			tb_ReadAddress <= std_logic_vector(unsigned(tb_ReadAddress)+1); --increment address

		end loop;
		Write(L, STRING'("---------------- EOF ----------------")); --Finish
        WRITELINE(FO, L);
		tb_ReadEnable <= '0';
		wait;  --End Reading Process after it has run once
	end process;
          

end tb;
