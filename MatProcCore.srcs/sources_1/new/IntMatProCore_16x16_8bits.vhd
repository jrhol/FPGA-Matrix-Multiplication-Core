----------------------------------------------------------------------------------
-- Company: UON
-- Engineer: James Holdsworth
-- 
-- Create Date: 26.03.2024 11:38:19
-- Design Name: IntMatProCore_16x16_8bits
-- Module Name: IntMatProCore_16x16_8bits - Behavioral
-- Project Name: 16x16 Signed 8Bit Matrix Processing Core
-- Target Devices: **********************xc7a15tcsg324-1***********************
-- Tool Versions: 
-- Description: Matrix Processing Core Design
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- Matrix multiplier : A * B * C = D 
-- Input matrix: A, B, C - Size: 16 x 16 - 8 bits (Signed)
-- Output matrix: D - Size: 16 x 16 - 56 bits
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Required entity declaration
-- BufferSel: "00" for input buffer A, "01" for input buffer B, "10" for input buffer C
entity IntMatProCore is
    port(
        Reset, Clock:                   in std_logic;                       --Reset and Clock 
        WriteEnable:                    in std_logic;                       --Enable Writing to buffer   
        BufferSel:                      in std_logic_vector (1 downto 0);   --Input buffer selection, BufferSel: "00" for input buffer A, "01" for input buffer B, "10"for input buffer C
       
        WriteAddress:                   in std_logic_vector (7 downto 0);   --Address to write data to
        WriteData:                      in std_logic_vector (7 downto 0);   --Data to write as input
        
        ReadAddress:                    in std_logic_vector (7 downto 0);   --Address to Read Data from
        ReadEnable:                     in std_logic;                       --Enable Reading 
        ReadData:                       out std_logic_vector (55 downto 0); --Data Output
        
        DataReady:                      out std_logic                       --Signals When Data is ready
);
end IntMatProCore;

architecture Behavioral of IntMatProCore is

------------- dpram256x8 COMPONENT Declaration ------
COMPONENT dpram256x8
  PORT (
    clka    :   IN STD_LOGIC;
    wea     :   IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    dina    :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb    :   IN STD_LOGIC;
    enb     :   IN STD_LOGIC;
    addrb   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    doutb   :   OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;
------ End COMPONENT Declaration ------------

------------- dpram256x32 COMPONENT Declaration ------
COMPONENT dpram256x32
  PORT (
    clka    :   IN STD_LOGIC;
    wea     :   IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    dina    :   IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb    :   IN STD_LOGIC;
    enb     :   IN STD_LOGIC;
    addrb   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    doutb   :   OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;
------ End COMPONENT Declaration ------------

------------- dpram256x56 COMPONENT Declaration ------
COMPONENT dpram256x56
  PORT (
    clka    :   IN STD_LOGIC;
    wea     :   IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    dina    :   IN STD_LOGIC_VECTOR(55 DOWNTO 0);
    clkb    :   IN STD_LOGIC;
    enb     :   IN STD_LOGIC;
    addrb   :   IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    doutb   :   OUT STD_LOGIC_VECTOR(55 DOWNTO 0)
  );
END COMPONENT;
------ End COMPONENT Declaration ------------

-- State definitions
type StateType is ( stIdle,               -- Idle state
                    stWriteBufferA,       -- Write buffer A state : Write matrix A to RAM A
                    stWriteBufferB,       -- Write buffer B state : Write matrix B to RAM B
                    stWriteBufferC,       -- Write buffer C state : Write matrix C to RAM C
                    
                    stReadBufferAB,             -- Read buffer A and B state : Read RAM A and B ,then do the MAC
                    
                    stWaitWriteBufferTemp,      -- Wait to write to Temp Buffer during first Mac
                    stWriteBufferTemp,          -- Write result from A and B into temp buffer
                    
                    stReadBufferCTemp,          -- Read buffer C and buffer Temp state : Read RAM C and Temp, then do second MAC
                    
                    stWaitWriteBufferD,      -- Wait to write to buffer D state
                    stWriteBufferD,          -- Write buffer D state : Write matrix D to RAM D
                    
                    stComplete              -- Complete state
                  );
                  
-- Internal signals definitions--                  
--State Buffers
signal presState: stateType;
signal nextState: stateType;

--Control Signals
    --Writing Enable Signals
    signal  iWriteEnableA, iWriteEnableB, iWriteEnableC, iWriteEnableTemp, iWriteEnableD: std_logic_vector(0 downto 0); 
    --Reading Enable Signals 
    signal  iReadEnableAB, iReadEnableCTemp : std_logic;
    --Adressing Signals: 8 bits for 2^8=256 elements in a 16x16 matrix.
    signal  iReadAddressA, iReadAddressB, iReadAddressC,iReadAddressTemp,iWriteAddressTemp,iWriteAddressTemp1,iWriteAddressD, iWriteAddressD1: std_logic_vector(7 downto 0);

-- Data signals
    --Reading Data Signals (Each Data is 8 bits)
    signal iReadDataA, iReadDataB, iReadDataC: std_logic_vector (7 downto 0);
    --Reading Data Signals (Temp Data is 32 bits)
    signal iReadDataTemp: std_logic_vector (31 downto 0);

-- Matrix Adressing signals
    --Resets and Enables
    signal  iCountReset, iRowCountAReset, iColCountAReset, iRowCountBReset, iColCountBReset: std_logic;         --Resets
    signal  iCountEnable, iRowCountAEnable, iColCountAEnable, iRowCountBEnable, iColCountBEnable: std_logic;    --Enables
    --Counters
    signal  iColCountA: unsigned(3 downto 0);               --4 bit Counter, Counts Which Column Element in the matrix we are at
    signal  iRowCountA, iColCountB: unsigned(4 downto 0);   --5 bit Counter, Counts which row in the array we are on (up to 15), Overflow used to check when complete
    signal  iCount: unsigned(7 downto 0);                   --8 bit counter, make sure cannot write more than 256 items to input buffers

-- Multiply-Accumulate (MAC) Signals
signal  iMacReset, iMacEnable1, iMacEnable2: std_logic;            --Reset and Enable Signals for MAC
signal  iMacResult1: std_logic_vector (31 downto 0); --Accumalted Result for the first  MAC (32 Bit)
signal  iMacResult2: std_logic_vector (55 downto 0); --Accumalted Result for the second MAC (56 Bit)

begin
	-- Write enable is 'master enable' for all input buffers.
	-- BufferSel determines which one is written to: '00' for A, '01' for B and '10' for C
    iWriteEnableA(0) <= '1' when (WriteEnable = '1' and BufferSel = "00") else '0' ;
    iWriteEnableB(0) <= '1' when (WriteEnable = '1' and BufferSel = "01") else '0' ;
    iWriteEnableC(0) <= '1' when (WriteEnable = '1' and BufferSel = "10") else '0' ;

------------- InputBufferA dpram256x8 INSTANTIATION -----
InputBufferA : dpram256x8
  PORT MAP (
    clka  => Clock,
    wea   => iWriteEnableA,
    addra => WriteAddress,
    dina  => WriteData,
    clkb  => Clock,
    enb   => iReadEnableAB,
    addrb => iReadAddressA,
    doutb => iReadDataA
  );
------ End INSTANTIATION ---------

------------- InputBufferB dpram256x8 INSTANTIATION -----
InputBufferB : dpram256x8
  PORT MAP (
    clka  => Clock,
    wea   => iWriteEnableB,
    addra => WriteAddress,
    dina  => WriteData,
    clkb  => Clock,
    enb   => iReadEnableAB,
    addrb => iReadAddressB,
    doutb => iReadDataB
  );
------ End INSTANTIATION ---------

------------- InputBufferC dpram256x8 INSTANTIATION -----
InputBufferC : dpram256x8
  PORT MAP (
    clka  => Clock,
    wea   => iWriteEnableC,
    addra => WriteAddress,
    dina  => WriteData,
    clkb  => Clock,
    enb   => iReadEnableCTemp,
    addrb => iReadAddressC,
    doutb => iReadDataC
  );
------ End INSTANTIATION ---------

----------- TempBuffer dpram256x32 INSTANTIATION -----
TempBuffer : dpram256x32
  PORT MAP (
    clka  => Clock,
    wea   => iWriteEnableTemp,
    addra => iWriteAddressTemp,
    dina  => iMacResult1,
    clkb  => Clock,
    enb   => iReadEnableCTemp,
    addrb => iReadAddressTemp,
    doutb => iReadDataTemp
  );
---- End INSTANTIATION ---------

------------- TempBuffer dpram256x56 INSTANTIATION -----
OutputBufferD : dpram256x56
  PORT MAP (
    clka  => Clock,
    wea   => iWriteEnableD,
    addra => iWriteAddressD,
    dina  => iMacResult2,
    clkb  => Clock,
    enb   => ReadEnable,
    addrb => ReadAddress,
    doutb => ReadData
  );
------ End INSTANTIATION ---------

	-- Multiply-Accumulate Unit Process
	process (Clock)
	begin
		if rising_edge(Clock) then		
			-- Reset Multiply-Accumulate Result 
			if iMacReset = '1' then
				iMacResult1 <= (others=>'0');   --Clear First MAC Result
				iMacResult2 <= (others=>'0');   --Clear Second MAC Result
			elsif iMacEnable1 = '1' then
				-- Compute new MAC result = Old result + (A * B)
				-- New = Old + (A * B)
				-- multiplication gives 16 bit result, addition adds an overflow bit each time so output buffer must be 16+15=31 bits (round to 32 as multiple of 4)
				iMacResult1 <= std_logic_vector(signed(iReadDataA) * signed(iReadDataB) + signed(iMacResult1));
			elsif iMacEnable2 = '1' then
			    -- multiplication gives 40 bit result, addition adds an overflow bit each time so output buffer must be 40+15=55 bits (round to 56 as multiple of 4)
				iMacResult2 <= std_logic_vector(signed(iReadDataTemp) * signed(iReadDataC) + signed(iMacResult2));
			end if;
		end if;
	end process;
	
	
	-- Map the matrix address to the RAM address
    -- Computed the address to read from the input buffers	
	iReadAddressA      <= std_logic_vector(iRowCountA(3 downto 0) & iColCountA);
    iReadAddressB      <= std_logic_vector(iColCountA & iColCountB(3 downto 0));
    
    iReadAddressTemp    <= std_logic_vector(iRowCountA(3 downto 0) & iColCountA); 
	iReadAddressC <= std_logic_vector(iColCountA & iColCountB(3 downto 0));
	
    -- Configure the enable signals for MAC
	process (Clock)
	begin
		if rising_edge(Clock) then		
			iMacEnable1 <= iReadEnableAB;        --Enable MAC 1 for A*B
			iMacEnable2 <= iReadEnableCTemp;     --Enable MAC 2 for Temp * C
			-- Compute address in output buffer
			iWriteAddressTemp1	<= std_logic_vector(iRowCountA(3 downto 0) & iColCountB(3 downto 0)); -- Was 1 downto 0 but need 0-15 + OF)
			iWriteAddressTemp	<= iWriteAddressTemp1;
			
			iWriteAddressD1	<= std_logic_vector(iRowCountA(3 downto 0) & iColCountB(3 downto 0));
			iWriteAddressD  <= iWriteAddressD1;
		end if;
	end process;	
	
	
	 -- Configure the state machine and the counters 
    process (Clock, Reset)
    begin
        if rising_edge (Clock) then
            -- Progress state machine
            if Reset = '1' then
                presState <= stIdle;
            else
                presState <= nextState;
            end if;
            
            -- Increment/reset counter
            if iCountReset = '1' then
                iCount <= (others=>'0');
            elsif iCountEnable = '1' then
                iCount <= iCount + 1;
            end if;

            -- Increment/reset Input Buffer A Row Count
            if iRowCountAReset = '1' then
                iRowCountA <= (others=>'0');
            elsif iRowCountAEnable = '1' then
                iRowCountA <= iRowCountA + 1;
            end if;

            -- Increment/reset Input Buffer A Column Count
            if iColCountAReset = '1' then
                iColCountA <= (others=>'0');
            elsif iColCountAEnable = '1' then
                iColCountA <= iColCountA + 1;
            end if;        

            -- Increment/reset Input Buffer B Column Count
            if iColCountBReset = '1' then
                iColCountB <= (others=>'0');
            elsif iColCountBEnable = '1' then
                iColCountB <= iColCountB + 1;
            end if;
            
        end if;
    end process;


    -- State machine
    process (presState, WriteEnable, BufferSel, iCount, iRowCountA, iColCountA, iColCountB)
    begin
        -- signal defaults
        iCountReset <= '0';
        iCountEnable <= '1'; 

        iRowCountAReset <= '0';
        iRowCountAEnable <= '0';

        iColCountAReset <= '0';
        iColCountAEnable <= '0';

        iColCountBReset <= '0';
        iColCountBEnable <= '0';

        iReadEnableAB <= '0';
        iReadEnableCTemp <= '0';
        
        
        iWriteEnableTemp(0) <= '0';
        iWriteEnableD(0) <= '0';
        iMacReset <= '0';

        DataReady <= '0';

        case presState is
        
            -- In the idle state, capture BufferSel signals and go to the stWriteBufferA.
            when stIdle =>
                if (WriteEnable = '1' and BufferSel = "00") then
                    -- Write to Input Buffer A if WE set and BufferSel set to A
                    nextState <= stWriteBufferA;
                else
                    iCountReset <= '1';
                    nextState <= stIdle;
                end if;
            
            -- Write RAM A form matrix A until iCount = 256 (i.e., 16x16=256 elements)
            when stWriteBufferA =>
            -- If finished writing input buffer A, switch to buffer B
                if iCount = x"FF" then
                    iCountReset <= '1';
                    nextState <= stWriteBufferB;
                 else
                    nextState <= stWriteBufferA;
                end if;
            
            -- Write RAM B form matrix B until iCount = 256 (i.e., 16x16=256 elements)
            when stWriteBufferB =>
                -- If finished writing input buffer B, switch to buffer C
                if iCount = x"FF" then
                    iCountReset <= '1';
                    nextState <= stWriteBufferC;
                 else
                    nextState <= stWriteBufferB;
                end if;
            
            -- Write RAM C form matrix C until iCount = 255 (i.e., 16x16=256 elements)
            when stWriteBufferC =>
                -- If finished writing input buffer C, reset all counters and start reading from buffers for multiplication
                if iCount = x"FF" then
                    iCountReset <= '1';
                    iRowCountAReset <= '1';
                    iColCountAReset <= '1';
                    iColCountBReset <= '1';
                    iMacReset <= '1';              
                    nextState <= stReadBufferAB;
                 else
                    nextState <= stWriteBufferC;
                end if;
            
            -- When finished writing all the RAMs, read RAM A and RAM B, then do first MAC.
            -- Start reading from the buffer
            when stReadBufferAB =>
                -- If finished all rows, reset counters and read Buffer C to perform second mac
                if iRowCountA = "10000" then
                    iRowCountAReset <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    iCountReset <= '1'; --Added
                    nextState <= stReadBufferCTemp;
                -- If finished the columns in B, reset appropriate counters
                elsif iColCountB = "10000" then
                    iRowCountAEnable <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    nextState <= stReadBufferAB;
                -- If finished columns in A, progress to writing output buffer
                elsif iColCountA = "1111" then
                    iReadEnableAB <= '1';
                    iColCountAReset <= '1';
                    nextState <= stWaitWriteBufferTemp;
                else
                    iReadEnableAB <= '1';
                    iReadEnableCTemp <= '0';
                    iColCountAEnable <= '1';
                    nextState <= stReadBufferAB;
                end if;
            
            when stWaitWriteBufferTemp =>
            		iColCountBEnable <= '1';
				    nextState <= stWriteBufferTemp;
		    
		    when stWriteBufferTemp =>
		            -- Set output buffer write enable
				    iWriteEnableTemp(0) <= '1';
				    -- Reset Multiply-Accumulate register
				    iMacReset <= '1';
				    nextState <= stReadBufferAB;
            
            -- When finished doing first MAC each time, read matrix C and Temp
            when stReadBufferCTemp =>
                if iRowCountA = "10000" then
                    iRowCountAReset <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    nextState <= stComplete;
                -- If finished the columns in B, reset appropriate counters
                elsif iColCountB = "10000" then
                    iRowCountAEnable <= '1';
                    iColCountBReset <= '1';
                    iColCountAReset <= '1';
                    nextState <= stReadBufferCTemp;
                -- If finished columns in A, progress to writing output buffer
                elsif iColCountA = "1111" then
                    iReadEnableCTemp <= '1';
                    iColCountAReset <= '1';
                    nextState <= stWaitWriteBufferD;
                else
                    iReadEnableCTemp <= '1';
                    iReadEnableAB <= '0';
                    iColCountAEnable <= '1';
                    nextState <= stReadBufferCTemp;
                end if;
            
            -- set enable bit???
			when stWaitWriteBufferD =>
				iColCountBEnable <= '1';
				nextState <= stWriteBufferD;

            when stWriteBufferD =>
                -- Set output buffer write enable
                iWriteEnableD(0) <= '1';
                -- Reset Multiply-Accumulate register
				iMacReset <= '1';
                -- Go back to reading from buffer
                nextState <= stReadBufferCTemp;
            
            -- When finished calculating all the elements, go to the idle state
            -- and set the DataReady signal to '1'
            -- When finished set DataReady bit
            when stComplete =>
                DataReady <= '1';
                nextState <= stIdle;
                
        end case;
    end process;

end Behavioral;
