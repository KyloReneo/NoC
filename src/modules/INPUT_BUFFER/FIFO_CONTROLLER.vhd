-- FIFO CONTROLLER IMPLEMENTATION
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL; 
USE WORK.ROUTER_PKG.ALL; 

ENTITY FIFO_CONTROLLER IS
    GENERIC(
	DEPTH      : INTEGER := BUFFER_DEPTH;
	PTR_LENGTH : INTEGER := BUFFER_PTR_WIDTH
	);
    PORT(
        FC_CLK   : IN  STD_LOGIC;
        FC_RST   : IN  STD_LOGIC;
        FC_WR    : IN  STD_LOGIC;
        FC_RD    : IN  STD_LOGIC;
        FC_FULL  : OUT STD_LOGIC;
        FC_EMPTY : OUT STD_LOGIC;
	WR_EN    : OUT STD_LOGIC;
        WR_ADDR  : OUT STD_LOGIC_VECTOR(PTR_LENGTH - 1 DOWNTO 0);
        RE_ADDR  : OUT STD_LOGIC_VECTOR(PTR_LENGTH - 1 DOWNTO 0)
   	);
END FIFO_CONTROLLER;

ARCHITECTURE BEHAV OF FIFO_CONTROLLER IS

    SIGNAL WR_PTR     : UNSIGNED(PTR_LENGTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL RE_PTR     : UNSIGNED(PTR_LENGTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL COUNT      : INTEGER RANGE 0 TO DEPTH := 0;
    SIGNAL ONES       : UNSIGNED(PTR_LENGTH - 2 DOWNTO 0) := (OTHERS => '1');
    SIGNAL ZEROS      : UNSIGNED(PTR_LENGTH - 2 DOWNTO 0) := (OTHERS => '0');
    
BEGIN

    -- ==========================================================================
    -- SYNCHRONOUS PROCESS
    -- ==========================================================================
    PROCESS(FC_CLK, FC_RST)
    BEGIN
        IF FC_RST = '1' THEN
            WR_PTR <= (OTHERS => '0');
            RE_PTR <= (OTHERS => '0');
            COUNT  <= 0;
        ELSIF RISING_EDGE(FC_CLK) THEN
            -- WRITE OPERATION
            IF FC_WR = '1' AND COUNT < DEPTH THEN
                IF WR_PTR(PTR_LENGTH - 2 DOWNTO 0) = ONES THEN
                    WR_PTR <= NOT(WR_PTR(PTR_LENGTH - 1)) & ZEROS;
                ELSE
                    WR_PTR <= WR_PTR + 1;
                END IF;
            END IF;
            
            -- READ OPERATION
            IF FC_RD = '1' AND COUNT > 0 THEN
                IF RE_PTR(PTR_LENGTH - 2 DOWNTO 0) = ONES THEN
                    RE_PTR <= NOT(RE_PTR(PTR_LENGTH - 1)) & ZEROS;
                ELSE
                    RE_PTR <= RE_PTR + 1;
                END IF;
            END IF;
            
            -- UPDATING COUNT
            IF FC_WR = '1' AND COUNT < DEPTH AND FC_RD = '1' AND COUNT > 0 THEN
                COUNT <= COUNT;  
            ELSIF FC_WR = '1' AND COUNT < DEPTH THEN
                COUNT <= COUNT + 1;
            ELSIF FC_RD = '1' AND COUNT > 0 THEN
                COUNT <= COUNT - 1;
            END IF;
        END IF;
    END PROCESS;

    -- ==========================================================================
    -- COMBINATIONAL OUTPUT LOGIC
    -- ==========================================================================
    WR_ADDR <= STD_LOGIC_VECTOR(WR_PTR);
    RE_ADDR <= STD_LOGIC_VECTOR(RE_PTR);
    
    WR_EN   <= FC_WR WHEN COUNT < DEPTH ELSE '0';
    
    FC_FULL  <= '1' WHEN COUNT = DEPTH ELSE '0';
    FC_EMPTY <= '1' WHEN COUNT = 0 ELSE '0';

END BEHAV;
