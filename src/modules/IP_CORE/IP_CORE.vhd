-- IP CORE
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.ROUTER_PKG.ALL;

ENTITY IP_CORE IS
    GENERIC (
        NODE_ADDR  : NETWORK_ADDR := NODE5_ADDRESS
    );
    PORT (
        CLK                  : IN  STD_LOGIC;
        RST                  : IN  STD_LOGIC;
        -- CONFIGURATION THAT COMES FROM TESTBENCH
        FLIT_DEST_ADDR       : IN  NETWORK_ADDR;
        CONFIG_START         : IN  STD_LOGIC;
        CONFIG_DONE          : OUT STD_LOGIC;
        -- NI SIDE FORM THE INJECTOR CHANNEL
	READY_FROM_NI        : IN   STD_LOGIC;  -- NI IS READY TO ACCEPT DATA FROM IP CORE
        FLIT_DEST_ADDR_TO_NI : OUT  NETWORK_ADDR;
        VALID_TO_NI          : OUT  STD_LOGIC;
        -- NI SIDE FORM THE EXTRACTOR CHANNEL  
        PAYLOAD_FORM_NI      : IN   STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 DOWNTO 0); -- FOR THIS PROJECT WE ASSUME THAT THE PAYLOAD IS SOURCE ADDRESS OF THE FLIT THAT RECEIVED AT THE NI EXTRACTOR CHANNEL OK?!
        VALID_FROM_NI        : IN   STD_LOGIC;  -- DATA IN NI IS READY
        READY_TO_NI          : OUT  STD_LOGIC;  -- IP CORE IS READY TO RECEIVE DATA FROM NI
        -- IP CORE STATUS
        BUSY                 : OUT  STD_LOGIC
    );
END ENTITY;

ARCHITECTURE BEHAV OF IP_CORE IS
    TYPE   STATE_TYPE IS (IDLE, WAIT_FOR_NI, SENDING, RECEIVING);
    SIGNAL STATE : STATE_TYPE;
    
    SIGNAL SEND_COMPLETE  : STD_LOGIC;
    SIGNAL RECEIVE_BUFFER : STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 DOWNTO 0);
BEGIN

    PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            STATE                 <= IDLE;
            VALID_TO_NI           <= '0';
            READY_TO_NI           <= '0';
	    FLIT_DEST_ADDR_TO_NI  <= (OTHERS => '0');
            CONFIG_DONE           <= '0';
            BUSY                  <= '0';
            SEND_COMPLETE         <= '0';
            RECEIVE_BUFFER        <= (OTHERS => '0');
            
        ELSIF RISING_EDGE(CLK) THEN
            -- SETTING DEFAULT VALUES
            VALID_TO_NI      <= '0';
            READY_TO_NI      <= '1'; -- IP CORE IS ALWAYS READY TO RECEIVE DATA
            CONFIG_DONE      <= '0';
            BUSY             <= '0';
            SEND_COMPLETE    <= '0';
            
            CASE STATE IS
                WHEN IDLE =>
                    IF CONFIG_START = '1' THEN
                        -- START TO SEND DATA THAT COMES FROM TESTBNCH
	    		FLIT_DEST_ADDR_TO_NI  <= FLIT_DEST_ADDR;
                        STATE                 <= WAIT_FOR_NI;
                        BUSY                  <= '1';
                    ELSIF VALID_FROM_NI = '1' THEN
                        -- DATA IS AVAILABLE IN NI, FORM THE EXTRACTOR BUFFER
                        RECEIVE_BUFFER <= PAYLOAD_FORM_NI;
                        STATE <= RECEIVING;
                        BUSY <= '1';
                    END IF;
                    
                WHEN WAIT_FOR_NI =>
                    BUSY <= '1';
                    IF READY_FROM_NI = '1' THEN
                        -- NI IS READY TO ACCEPT DATA FROM IP CORE, INJECTOR PATH IN NOT BUSY
                        VALID_TO_NI <= '1';
                        STATE <= SENDING;
                    END IF;
                    
                WHEN SENDING =>
                    BUSY <= '1';
                    IF READY_FROM_NI = '0' THEN
                        -- NI HAS ACCEPTED OUR DATA AND THE HANDSHAKE HAS BEEN COMPLETED 
                        VALID_TO_NI <= '0';
                        SEND_COMPLETE <= '1';
                        STATE <= IDLE;
                        -- REPORT THE SENT PACKET
                        REPORT "NODE " & TO_STRING(NODE_ADDR) & " SENT PACKET TO NODE " & TO_STRING(FLIT_DEST_ADDR)& " SUCCESSFULLY!";
                    END IF;
                    
                WHEN RECEIVING =>
                    BUSY <= '1';
                    -- RECEIVING DATA PROCESS
                    REPORT "NODE " & TO_STRING(NODE_ADDR) & " RECEVIED PAYLOAD FROM NODE " & TO_STRING(RECEIVE_BUFFER) & " SUCCESSFULLY!";
                    STATE <= IDLE;
                    
            END CASE;
            
            -- SETTING FLAGS WHEN THE SEND IS COMPLETE
            IF SEND_COMPLETE = '1' THEN
                CONFIG_DONE <= '1';
            END IF;
            
        END IF;
    END PROCESS;

END ARCHITECTURE BEHAV;
