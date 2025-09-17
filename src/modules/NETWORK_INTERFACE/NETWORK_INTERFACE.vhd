-- NETWORK INTERFACE OF ROUTER
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.ROUTER_PKG.ALL;

ENTITY NETWORK_INTERFACE IS
    GENERIC (
        NODE_ADDR  : NETWORK_ADDR 
    );
    PORT (
        CLK                     : IN STD_LOGIC;
        RST                     : IN STD_LOGIC;
        -- IP CORE SIDE
        -- TO INJECTOR CHANNEL
        FLIT_DEST_ADDR_FORM_IP  : IN  NETWORK_ADDR;
        HEAD_OR_TAIL            : IN  STD_LOGIC;
        VALID_IN_FROM_IP        : IN  STD_LOGIC;
        READY_OUT_TO_IP         : OUT STD_LOGIC; -- NI IS READY TO ACCEPT DATA FROM IP
        -- FROM EXTRACTOR CHANNEL
        READY_FROM_IP           : IN  STD_LOGIC;
        VALID_TO_IP             : OUT STD_LOGIC;
        PAYLOAD_TO_IP           : OUT STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 DOWNTO 0);
        -- ROUTER SIDE 
        -- TO ROUTER'S LOCAL INPUT BUFFER (BUFFERED OUTPUT)
        LOCAL_IB_FULL   : IN  STD_LOGIC;  -- LOCAL INPUT BUFFER'S FULL FLAG
        LOCAL_IB_WR     : OUT STD_LOGIC;  -- WRITE ENABLE SIGNAL TO LOCAL INPUT BUFFER
        LOCAL_IB_DATA   : OUT FLIT;       -- DATA TO LOCAL INPUT BUFFER
        -- FROM ROUTER'S CROSSBAR TO EXTRACTOR CHANNEL (UNBUFFERED OUTPUT OF ROUTER)
        ROUTER_TO_NI    : IN  FLIT;       -- DIRECTLY COMES FROM CROSSBAR OUTPUT
        -- CONTROLLING SIGNALS TO AND FROM ARBITER FOR THE EXTRACTOR CHANNEL
        EXT_W_REQ_IN    : IN  STD_LOGIC;
        EXT_CREDIT_OUT  : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE BEHAV OF NETWORK_INTERFACE IS

    -- EXTRACTOR CHANNEL DECLARATION
    COMPONENT EXTRACTOR_BUFFER
        PORT(
            CLK            : IN  STD_LOGIC;
            RST            : IN  STD_LOGIC;
            WRITE_REQUEST  : IN  STD_LOGIC;
            GRANT          : IN  STD_LOGIC;
            IP_REQ         : IN  STD_LOGIC;
            DATA           : IN  FLIT;
            CREDIT_OUT     : OUT STD_LOGIC;                    
            EMPTY          : OUT STD_LOGIC;
            OUTPUT         : OUT FLIT
        );
    END COMPONENT;

    TYPE STATE_TYPE IS (IDLE, SEND_HEADER, SEND_TAIL, RECEIVING_HEADER, RECEIVING_TAIL);
    SIGNAL STATE_REG, STATE_NEXT : STATE_TYPE;
    
    -- EXTRACTOR CHANNEL SIGNALS
    SIGNAL EXT_FLIT_IN, EXT_FLIT_OUT : FLIT;
    SIGNAL EXT_IB_WR_EN, EXT_IB_RD_EN, EXT_IB_IP_REQ : STD_LOGIC;
    SIGNAL EXT_IB_FULL, EXT_IB_EMPTY : STD_LOGIC;
    
    -- INTERNAL REGISTERS
    SIGNAL LOCAL_IB_WR_REG,     LOCAL_IB_WR_NEXT : STD_LOGIC;
    SIGNAL LOCAL_IB_DATA_REG,   LOCAL_IB_DATA_NEXT : FLIT;
    SIGNAL READY_OUT_TO_IP_REG, READY_OUT_TO_IP_NEXT : STD_LOGIC;
    SIGNAL VALID_TO_IP_REG,     VALID_TO_IP_NEXT : STD_LOGIC;
    SIGNAL PAYLOAD_TO_IP_REG,   PAYLOAD_TO_IP_NEXT : STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 DOWNTO 0);
    SIGNAL EXT_IB_RD_EN_REG,    EXT_IB_RD_EN_NEXT : STD_LOGIC;
    
BEGIN

    -- EXTRACTOR FIFO
    EXTRACTOR_CHANNEL : EXTRACTOR_BUFFER
        PORT MAP (
            CLK           => CLK,
            RST           => RST,
            WRITE_REQUEST => EXT_IB_WR_EN,
            GRANT         => EXT_IB_RD_EN,
            IP_REQ        => EXT_IB_IP_REQ,
            DATA          => EXT_FLIT_IN,
            CREDIT_OUT    => EXT_IB_FULL,
            EMPTY         => EXT_IB_EMPTY,
            OUTPUT        => EXT_FLIT_OUT
        );

    -- CONNECTING SIGNALS
    EXT_FLIT_IN     <= ROUTER_TO_NI;
    EXT_IB_WR_EN    <= EXT_W_REQ_IN;
    EXT_IB_IP_REQ   <= READY_FROM_IP;
    EXT_CREDIT_OUT  <= EXT_IB_FULL;
    EXT_IB_RD_EN    <= EXT_IB_RD_EN_REG;

    -- OUTPUT ASSIGNMENTS
    LOCAL_IB_WR     <= LOCAL_IB_WR_REG;
    LOCAL_IB_DATA   <= LOCAL_IB_DATA_REG;
    READY_OUT_TO_IP <= READY_OUT_TO_IP_REG;
    VALID_TO_IP     <= VALID_TO_IP_REG;
    PAYLOAD_TO_IP   <= PAYLOAD_TO_IP_REG;

    -- STATE REGISTER PROCESS
    STATE_REGISTER_PROC : PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            STATE_REG           <= IDLE;
            LOCAL_IB_WR_REG     <= '0';
            LOCAL_IB_DATA_REG   <= (OTHERS => '0');
            READY_OUT_TO_IP_REG <= '0';
            VALID_TO_IP_REG     <= '0';
            PAYLOAD_TO_IP_REG   <= (OTHERS => '0');
            EXT_IB_RD_EN_REG    <= '0';
            
        ELSIF RISING_EDGE(CLK) THEN
            STATE_REG           <= STATE_NEXT;
            LOCAL_IB_WR_REG     <= LOCAL_IB_WR_NEXT;
            LOCAL_IB_DATA_REG   <= LOCAL_IB_DATA_NEXT;
            READY_OUT_TO_IP_REG <= READY_OUT_TO_IP_NEXT;
            VALID_TO_IP_REG     <= VALID_TO_IP_NEXT;
            PAYLOAD_TO_IP_REG   <= PAYLOAD_TO_IP_NEXT;
            EXT_IB_RD_EN_REG    <= EXT_IB_RD_EN_NEXT;
        END IF;
    END PROCESS;

    -- NEXT STATE LOGIC PROCESS (COMBINATORIAL)
    NEXT_STATE_LOGIC : PROCESS(STATE_REG, LOCAL_IB_FULL, VALID_IN_FROM_IP, HEAD_OR_TAIL, 
                              EXT_IB_EMPTY, FLIT_DEST_ADDR_FORM_IP, EXT_FLIT_OUT, READY_FROM_IP, LOCAL_IB_DATA_REG, VALID_TO_IP_REG, PAYLOAD_TO_IP_REG)
    BEGIN
        -- DEFAULT VALUES
        STATE_NEXT         <= STATE_REG;
        LOCAL_IB_WR_NEXT   <= '0';
        LOCAL_IB_DATA_NEXT <= LOCAL_IB_DATA_REG;
        READY_OUT_TO_IP_NEXT <= NOT LOCAL_IB_FULL;
        VALID_TO_IP_NEXT   <= VALID_TO_IP_REG;
        PAYLOAD_TO_IP_NEXT <= PAYLOAD_TO_IP_REG;
        EXT_IB_RD_EN_NEXT  <= '0';

        CASE STATE_REG IS
            WHEN IDLE =>
                READY_OUT_TO_IP_NEXT <= NOT LOCAL_IB_FULL;
                
                -- PRIORITY: IP CORE DATA FIRST
                IF VALID_IN_FROM_IP = '1' AND LOCAL_IB_FULL = '0' THEN
                    IF HEAD_OR_TAIL = '0' THEN
                        STATE_NEXT <= SEND_HEADER;
                    ELSE
                        STATE_NEXT <= SEND_TAIL;
                    END IF;
                -- THEN CHECK EXTRACTOR BUFFER
                ELSIF EXT_IB_EMPTY = '0' THEN
                    EXT_IB_RD_EN_NEXT <= '1';
                    STATE_NEXT <= RECEIVING_HEADER;
                END IF;

            WHEN SEND_HEADER =>
                IF LOCAL_IB_FULL = '0' THEN
                    -- CREATE HEADER FLIT
                    LOCAL_IB_DATA_NEXT(11 DOWNTO 10) <= "00";
                    LOCAL_IB_DATA_NEXT(9 DOWNTO 5)  <= NODE_ADDR;
                    LOCAL_IB_DATA_NEXT(4 DOWNTO 0)  <= FLIT_DEST_ADDR_FORM_IP;
                    LOCAL_IB_WR_NEXT <= '1';
                    STATE_NEXT <= IDLE;
                END IF;

            WHEN SEND_TAIL =>
                IF LOCAL_IB_FULL = '0' THEN
                    -- CREATE TAIL FLIT
                    LOCAL_IB_DATA_NEXT(11 DOWNTO 10) <= "10";
                    LOCAL_IB_DATA_NEXT(9 DOWNTO 5)  <= NODE_ADDR;
                    LOCAL_IB_DATA_NEXT(4 DOWNTO 0)  <= FLIT_DEST_ADDR_FORM_IP;
                    LOCAL_IB_WR_NEXT <= '1';
                    STATE_NEXT <= IDLE;
                END IF;

            WHEN RECEIVING_HEADER =>
                IF EXT_IB_EMPTY = '0' THEN
                    EXT_IB_RD_EN_NEXT <= '1';
                    IF EXT_FLIT_OUT(11 DOWNTO 10) = "10" THEN  -- TAIL FLIT
                        PAYLOAD_TO_IP_NEXT <= EXT_FLIT_OUT(9 DOWNTO 5);
                        VALID_TO_IP_NEXT <= '1';
                        STATE_NEXT <= IDLE;
                    ELSE
                        STATE_NEXT <= RECEIVING_TAIL;
                    END IF;
                END IF;

            WHEN RECEIVING_TAIL =>
                IF EXT_IB_EMPTY = '0' THEN
                    EXT_IB_RD_EN_NEXT <= '1';
                    IF EXT_FLIT_OUT(11 DOWNTO 10) = "10" THEN  -- TAIL FLIT
                        PAYLOAD_TO_IP_NEXT <= EXT_FLIT_OUT(9 DOWNTO 5);
                        VALID_TO_IP_NEXT <= '1';
                    END IF;
                    STATE_NEXT <= IDLE;
                END IF;

        END CASE;

        -- RESET VALID FLAG WHEN IP ACKNOWLEDGES
        IF READY_FROM_IP = '1' AND VALID_TO_IP_REG = '1' THEN
            VALID_TO_IP_NEXT <= '0';
        END IF;
    END PROCESS;

END ARCHITECTURE BEHAV;
