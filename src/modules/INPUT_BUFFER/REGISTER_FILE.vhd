-- REGISTER FILE OF INPUT BUFFER
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.ROUTER_PKG.ALL;

ENTITY REGISTER_FILE IS
    PORT (
        RF_CLK             : IN  STD_LOGIC;
        RF_RST             : IN  STD_LOGIC;
        WR_EN              : IN  STD_LOGIC;
        GRANT              : IN  STD_LOGIC;
        CREDIT_IN          : IN  STD_LOGIC;
        EMPTY              : IN  STD_LOGIC;
        WR_ADDR            : IN  STD_LOGIC_VECTOR(BUFFER_PTR_WIDTH - 1 DOWNTO 0);
        RE_ADDR            : IN  STD_LOGIC_VECTOR(BUFFER_PTR_WIDTH - 1 DOWNTO 0);
        DATA_IN            : IN  FLIT;
        REQUEST_TO_ARBITER : OUT NETWORK_ADDR;
        DATA_OUT           : OUT FLIT
    );
END REGISTER_FILE;

ARCHITECTURE STRUCT OF REGISTER_FILE IS

    TYPE REGISTER_ARRAY IS ARRAY(0 TO BUFFER_DEPTH - 1) OF FLIT;
    SIGNAL RF : REGISTER_ARRAY := (OTHERS => (OTHERS => '0'));
    
    SIGNAL READ_DATA_COMB  : FLIT := (OTHERS => '0');
    SIGNAL DATA_OUT_COMB   : FLIT := (OTHERS => '0');

BEGIN

    -- ==========================================================================
    -- COMBINATIONAL READ LOGIC (IMMEDIATE OUTPUT)
    -- ==========================================================================
    READ_DATA_COMB <= RF(TO_INTEGER(UNSIGNED(RE_ADDR)));
    
    DATA_OUT_COMB <= READ_DATA_COMB WHEN (GRANT = '1' AND CREDIT_IN = '0' AND EMPTY = '0') ELSE
                     (OTHERS => '0');
    
    DATA_OUT <= DATA_OUT_COMB;
    
    -- ADDRESS TO ARBITER
    REQUEST_TO_ARBITER <= RF(TO_INTEGER(UNSIGNED(RE_ADDR)))(ADDRESS_WIDTH - 1 DOWNTO 0);

    -- ==========================================================================
    -- SYNCHRONOUS WRITE LOGIC (CLOCKED)
    -- ==========================================================================
    PROCESS(RF_CLK, RF_RST)
    BEGIN
        IF RF_RST = '1' THEN
            RF <= (OTHERS => (OTHERS => '0'));
        ELSIF RISING_EDGE(RF_CLK) THEN
            IF WR_EN = '1' THEN
                RF(TO_INTEGER(UNSIGNED(WR_ADDR))) <= DATA_IN;
            END IF;
        END IF;
    END PROCESS;

END STRUCT;
