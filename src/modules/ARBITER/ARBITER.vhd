-- THE ARBITER IS IMPLEMENTED IN THE STATE REGISTER, NEXT-STATE LOGIC, OUTPUT LOGIC STYLE AND IT USES ROUND-ROBIN TO LOOP THROUGH INPUT BUFFERS
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.ROUTER_PKG.ALL;

ENTITY ARBITER IS
    PORT (
        CLK                 : IN STD_LOGIC;
        RST                 : IN STD_LOGIC;
        -- EMPTY FLAGS FROM INPUT BUFFERS
        EMPTY_IN_LOCAL      : IN STD_LOGIC;
        EMPTY_IN_NORTH      : IN STD_LOGIC;
        EMPTY_IN_EAST       : IN STD_LOGIC;
        EMPTY_IN_SOUTH      : IN STD_LOGIC;
        EMPTY_IN_WEST       : IN STD_LOGIC;
        -- DESTINATION ADDRESSES FROM INPUT BUFFERS
        DEST_ADDR_IN_LOCAL  : IN NETWORK_ADDR;
        DEST_ADDR_IN_NORTH  : IN NETWORK_ADDR;
        DEST_ADDR_IN_EAST   : IN NETWORK_ADDR;
        DEST_ADDR_IN_SOUTH  : IN NETWORK_ADDR;
        DEST_ADDR_IN_WEST   : IN NETWORK_ADDR;
        -- OUTPUTS TO ROUTING UNITS
        DEST_ADDR_OUT_LOCAL : OUT NETWORK_ADDR;
        DEST_ADDR_OUT_NORTH : OUT NETWORK_ADDR;
        DEST_ADDR_OUT_EAST  : OUT NETWORK_ADDR;
        DEST_ADDR_OUT_SOUTH : OUT NETWORK_ADDR;
        DEST_ADDR_OUT_WEST  : OUT NETWORK_ADDR;
        -- INPUTS FROM ROUTING UNIT
        ROUTE_DIR_IN_LOCAL  : IN DIRECTION;
        ROUTE_DIR_IN_NORTH  : IN DIRECTION;
        ROUTE_DIR_IN_EAST   : IN DIRECTION;
        ROUTE_DIR_IN_SOUTH  : IN DIRECTION;
        ROUTE_DIR_IN_WEST   : IN DIRECTION;
        -- GRANTS TO INPUT BUFFERS
        GRANT_OUT_LOCAL     : OUT STD_LOGIC;
        GRANT_OUT_NORTH     : OUT STD_LOGIC;
        GRANT_OUT_EAST      : OUT STD_LOGIC;
        GRANT_OUT_SOUTH     : OUT STD_LOGIC;
        GRANT_OUT_WEST      : OUT STD_LOGIC;
        -- CREDIT-BASED FLOW CONTROL
        CREDIT_IN_LOCAL     : IN STD_LOGIC;
        CREDIT_IN_NORTH     : IN STD_LOGIC;
        CREDIT_IN_EAST      : IN STD_LOGIC;
        CREDIT_IN_SOUTH     : IN STD_LOGIC;
        CREDIT_IN_WEST      : IN STD_LOGIC;
        -- WRITE REQUEST TO TARGET BUFFERS
        W_REQ_OUT_LOCAL     : OUT STD_LOGIC;
        W_REQ_OUT_NORTH     : OUT STD_LOGIC;
        W_REQ_OUT_EAST      : OUT STD_LOGIC;
        W_REQ_OUT_SOUTH     : OUT STD_LOGIC;
        W_REQ_OUT_WEST      : OUT STD_LOGIC;
        -- SELECT SIGNALS FOR CROSSBARS
        SEL_LOCAL           : OUT DIRECTION;
        SEL_NORTH           : OUT DIRECTION;
        SEL_EAST            : OUT DIRECTION;
        SEL_SOUTH           : OUT DIRECTION;
        SEL_WEST            : OUT DIRECTION;
        -- CREDIT OUT TO GRANTED INPUT BUFFER
        CREDIT_OUT          : OUT STD_LOGIC
    );
END ENTITY ARBITER;

ARCHITECTURE FSM OF ARBITER IS

    -- 11-STATE FSM : 5 STATES FOR REQUEST CHECKING + 5 STATES FOR GRANT + 1 STATE FOR IDLE
    TYPE ARB_STATE_TYPE IS (
        ARB_IDLE,
        REQ_CHECK_LOCAL,
        REQ_CHECK_NORTH, 
        REQ_CHECK_EAST,
        REQ_CHECK_SOUTH,
        REQ_CHECK_WEST,
        GRANT_LOCAL,
        GRANT_NORTH,
        GRANT_EAST,
        GRANT_SOUTH,
        GRANT_WEST
    );
    
    SIGNAL STATE_REG, STATE_NEXT : ARB_STATE_TYPE;
    
    -- REGISTERED SIGNALS
    SIGNAL GRANTED_INPUT_REG, GRANTED_INPUT_NEXT       : DIRECTION;
    SIGNAL REQUESTED_OUTPUT_REG, REQUESTED_OUTPUT_NEXT : DIRECTION;
    SIGNAL LAST_CHECKED_REG, LAST_CHECKED_NEXT         : DIRECTION;
    
    -- NEW SIGNALS FOR PACKET TRACKING
    SIGNAL HEADER_GRANTED_REG, HEADER_GRANTED_NEXT       : STD_LOGIC;
    SIGNAL TAIL_GRANT_INPUT_REG, TAIL_GRANT_INPUT_NEXT   : DIRECTION;
    SIGNAL TAIL_GRANT_OUTPUT_REG, TAIL_GRANT_OUTPUT_NEXT : DIRECTION;
    
    -- REQUEST SIGNALS
    SIGNAL REQ_LOCAL, REQ_NORTH, REQ_EAST, REQ_SOUTH, REQ_WEST : STD_LOGIC;
    
    -- CREDIT AVAILABLE SIGNALS (COMBINATIONAL)
    SIGNAL CREDIT_AVAIL_LOCAL, CREDIT_AVAIL_NORTH, CREDIT_AVAIL_EAST : STD_LOGIC;
    SIGNAL CREDIT_AVAIL_SOUTH, CREDIT_AVAIL_WEST                     : STD_LOGIC;
    
    -- VALID REQUEST SIGNALS (COMBINATIONAL - HAS DATA AND CREDIT AVAILABLE)
    SIGNAL VALID_REQ_LOCAL, VALID_REQ_NORTH, VALID_REQ_EAST : STD_LOGIC;
    SIGNAL VALID_REQ_SOUTH, VALID_REQ_WEST                  : STD_LOGIC;

BEGIN

    -- ==========================================================================
    -- COMBINATIONAL LOGIC FOR FASTER PROCESSING
    -- ==========================================================================
    
    -- CREATE ACTIVE-HIGH REQUEST SIGNALS (IMMEDIATE)
    REQ_LOCAL <= NOT EMPTY_IN_LOCAL;
    REQ_NORTH <= NOT EMPTY_IN_NORTH;
    REQ_EAST  <= NOT EMPTY_IN_EAST;
    REQ_SOUTH <= NOT EMPTY_IN_SOUTH;
    REQ_WEST  <= NOT EMPTY_IN_WEST;
    
    -- CREDIT AVAILABLE SIGNALS (IMMEDIATE)
    CREDIT_AVAIL_LOCAL <= NOT CREDIT_IN_LOCAL;
    CREDIT_AVAIL_NORTH <= NOT CREDIT_IN_NORTH;
    CREDIT_AVAIL_EAST  <= NOT CREDIT_IN_EAST;
    CREDIT_AVAIL_SOUTH <= NOT CREDIT_IN_SOUTH;
    CREDIT_AVAIL_WEST  <= NOT CREDIT_IN_WEST;
    
    -- VALID REQUEST CALCULATION (COMBINATIONAL - NO CLOCK DELAY)
    VALID_REQ_LOCAL <= '1' WHEN REQ_LOCAL = '1' AND (
        (ROUTE_DIR_IN_LOCAL = LOCAL AND CREDIT_AVAIL_LOCAL = '1') OR
        (ROUTE_DIR_IN_LOCAL = NORTH AND CREDIT_AVAIL_NORTH = '1') OR
        (ROUTE_DIR_IN_LOCAL = EAST  AND CREDIT_AVAIL_EAST  = '1') OR
        (ROUTE_DIR_IN_LOCAL = SOUTH AND CREDIT_AVAIL_SOUTH = '1') OR
        (ROUTE_DIR_IN_LOCAL = WEST  AND CREDIT_AVAIL_WEST  = '1')
    ) ELSE '0';
    
    VALID_REQ_NORTH <= '1' WHEN REQ_NORTH = '1' AND (
        (ROUTE_DIR_IN_NORTH = LOCAL AND CREDIT_AVAIL_LOCAL = '1') OR
        (ROUTE_DIR_IN_NORTH = NORTH AND CREDIT_AVAIL_NORTH = '1') OR
        (ROUTE_DIR_IN_NORTH = EAST  AND CREDIT_AVAIL_EAST  = '1') OR
        (ROUTE_DIR_IN_NORTH = SOUTH AND CREDIT_AVAIL_SOUTH = '1') OR
        (ROUTE_DIR_IN_NORTH = WEST  AND CREDIT_AVAIL_WEST  = '1')
    ) ELSE '0';
    
    VALID_REQ_EAST <= '1' WHEN REQ_EAST = '1' AND (
        (ROUTE_DIR_IN_EAST = LOCAL AND CREDIT_AVAIL_LOCAL = '1') OR
        (ROUTE_DIR_IN_EAST = NORTH AND CREDIT_AVAIL_NORTH = '1') OR
        (ROUTE_DIR_IN_EAST = EAST  AND CREDIT_AVAIL_EAST  = '1') OR
        (ROUTE_DIR_IN_EAST = SOUTH AND CREDIT_AVAIL_SOUTH = '1') OR
        (ROUTE_DIR_IN_EAST = WEST  AND CREDIT_AVAIL_WEST  = '1')
    ) ELSE '0';
    
    VALID_REQ_SOUTH <= '1' WHEN REQ_SOUTH = '1' AND (
        (ROUTE_DIR_IN_SOUTH = LOCAL AND CREDIT_AVAIL_LOCAL = '1') OR
        (ROUTE_DIR_IN_SOUTH = NORTH AND CREDIT_AVAIL_NORTH = '1') OR
        (ROUTE_DIR_IN_SOUTH = EAST  AND CREDIT_AVAIL_EAST  = '1') OR
        (ROUTE_DIR_IN_SOUTH = SOUTH AND CREDIT_AVAIL_SOUTH = '1') OR
        (ROUTE_DIR_IN_SOUTH = WEST  AND CREDIT_AVAIL_WEST  = '1')
    ) ELSE '0';
    
    VALID_REQ_WEST <= '1' WHEN REQ_WEST = '1' AND (
        (ROUTE_DIR_IN_WEST = LOCAL AND CREDIT_AVAIL_LOCAL = '1') OR
        (ROUTE_DIR_IN_WEST = NORTH AND CREDIT_AVAIL_NORTH = '1') OR
        (ROUTE_DIR_IN_WEST = EAST  AND CREDIT_AVAIL_EAST  = '1') OR
        (ROUTE_DIR_IN_WEST = SOUTH AND CREDIT_AVAIL_SOUTH = '1') OR
        (ROUTE_DIR_IN_WEST = WEST  AND CREDIT_AVAIL_WEST  = '1')
    ) ELSE '0';

    -- ROUTE DESTINATION ADDRESSES DIRECTLY TO ROUTING UNITS (COMBINATIONAL)
    DEST_ADDR_OUT_LOCAL <= DEST_ADDR_IN_LOCAL;
    DEST_ADDR_OUT_NORTH <= DEST_ADDR_IN_NORTH;
    DEST_ADDR_OUT_EAST  <= DEST_ADDR_IN_EAST;
    DEST_ADDR_OUT_SOUTH <= DEST_ADDR_IN_SOUTH;
    DEST_ADDR_OUT_WEST  <= DEST_ADDR_IN_WEST;

    -- ==========================================================================
    -- STATE REGISTER PROCESS
    -- ==========================================================================
    STATE_REGISTER : PROCESS(CLK, RST)
    BEGIN
        IF RST = '1' THEN
            STATE_REG             <= ARB_IDLE;
            GRANTED_INPUT_REG     <= LOCAL;
            REQUESTED_OUTPUT_REG  <= LOCAL;
            LAST_CHECKED_REG      <= LOCAL;
            HEADER_GRANTED_REG    <= '0';
            TAIL_GRANT_INPUT_REG  <= LOCAL;
            TAIL_GRANT_OUTPUT_REG <= LOCAL;
        ELSIF RISING_EDGE(CLK) THEN
            STATE_REG             <= STATE_NEXT;
            GRANTED_INPUT_REG     <= GRANTED_INPUT_NEXT;
            REQUESTED_OUTPUT_REG  <= REQUESTED_OUTPUT_NEXT;
            LAST_CHECKED_REG      <= LAST_CHECKED_NEXT;
            HEADER_GRANTED_REG    <= HEADER_GRANTED_NEXT;
            TAIL_GRANT_INPUT_REG  <= TAIL_GRANT_INPUT_NEXT;
            TAIL_GRANT_OUTPUT_REG <= TAIL_GRANT_OUTPUT_NEXT;
        END IF;
    END PROCESS;

    -- ==========================================================================
    -- NEXT STATE LOGIC PROCESS (11-STATE FSM)
    -- ==========================================================================
    NEXT_STATE_LOGIC : PROCESS(STATE_REG, VALID_REQ_LOCAL, VALID_REQ_NORTH, 
                              VALID_REQ_EAST, VALID_REQ_SOUTH, VALID_REQ_WEST,
                              ROUTE_DIR_IN_LOCAL, ROUTE_DIR_IN_NORTH, 
                              ROUTE_DIR_IN_EAST,  ROUTE_DIR_IN_SOUTH, 
                              ROUTE_DIR_IN_WEST,  LAST_CHECKED_REG,
                              HEADER_GRANTED_REG, TAIL_GRANT_INPUT_REG,
                              TAIL_GRANT_OUTPUT_REG, GRANTED_INPUT_REG, REQUESTED_OUTPUT_REG)
    BEGIN
        -- DEFAULT VALUES
        STATE_NEXT <= STATE_REG;
        GRANTED_INPUT_NEXT <= GRANTED_INPUT_REG;
        REQUESTED_OUTPUT_NEXT <= REQUESTED_OUTPUT_REG;
        LAST_CHECKED_NEXT <= LAST_CHECKED_REG;
        HEADER_GRANTED_NEXT <= HEADER_GRANTED_REG;
        TAIL_GRANT_INPUT_NEXT <= TAIL_GRANT_INPUT_REG;
        TAIL_GRANT_OUTPUT_NEXT <= TAIL_GRANT_OUTPUT_REG;

	

        CASE STATE_REG IS
            WHEN ARB_IDLE =>
                -- CHECK IF WE NEED TO GRANT TAIL FLIT FIRST
                IF HEADER_GRANTED_REG = '1' THEN
                    -- GRANT TAIL FLIT TO THE SAME INPUT AND OUTPUT
                    GRANTED_INPUT_NEXT <= TAIL_GRANT_INPUT_REG;
                    REQUESTED_OUTPUT_NEXT <= TAIL_GRANT_OUTPUT_REG;
                    HEADER_GRANTED_NEXT <= '0'; -- RESET AFTER TAIL GRANT
                    
                    -- TRANSITION TO APPROPRIATE GRANT STATE
                    CASE TAIL_GRANT_INPUT_REG IS
                        WHEN LOCAL => STATE_NEXT <= GRANT_LOCAL;
                        WHEN NORTH => STATE_NEXT <= GRANT_NORTH;
                        WHEN EAST  => STATE_NEXT <= GRANT_EAST;
                        WHEN SOUTH => STATE_NEXT <= GRANT_SOUTH;
                        WHEN WEST  => STATE_NEXT <= GRANT_WEST;
			WHEN DISCONNECTED => NULL;
			
                    END CASE;
                ELSE
                    -- START ROUND-ROBIN ARBITRATION FROM THE NEXT INPUT
                    CASE LAST_CHECKED_REG IS
                        WHEN LOCAL => STATE_NEXT <= REQ_CHECK_NORTH;
                        WHEN NORTH => STATE_NEXT <= REQ_CHECK_EAST;
                        WHEN EAST  => STATE_NEXT <= REQ_CHECK_SOUTH;
                        WHEN SOUTH => STATE_NEXT <= REQ_CHECK_WEST;
                        WHEN WEST  => STATE_NEXT <= REQ_CHECK_LOCAL;
			WHEN DISCONNECTED => NULL;
			
                    END CASE;
                END IF;
                
            WHEN REQ_CHECK_LOCAL =>
                IF VALID_REQ_LOCAL = '1' THEN
                    GRANTED_INPUT_NEXT <= LOCAL;
                    REQUESTED_OUTPUT_NEXT <= ROUTE_DIR_IN_LOCAL;
                    -- STORE FOR TAIL FLIT GRANT
                    HEADER_GRANTED_NEXT <= '1';
                    TAIL_GRANT_INPUT_NEXT <= LOCAL;
                    TAIL_GRANT_OUTPUT_NEXT <= ROUTE_DIR_IN_LOCAL;
                    STATE_NEXT <= GRANT_LOCAL;
                ELSE
                    STATE_NEXT <= REQ_CHECK_NORTH;
                END IF;
                LAST_CHECKED_NEXT <= LOCAL;
                
            WHEN REQ_CHECK_NORTH =>
                IF VALID_REQ_NORTH = '1' THEN
                    GRANTED_INPUT_NEXT <= NORTH;
                    REQUESTED_OUTPUT_NEXT <= ROUTE_DIR_IN_NORTH;
                    -- STORE FOR TAIL FLIT GRANT
                    HEADER_GRANTED_NEXT <= '1';
                    TAIL_GRANT_INPUT_NEXT <= NORTH;
                    TAIL_GRANT_OUTPUT_NEXT <= ROUTE_DIR_IN_NORTH;
                    STATE_NEXT <= GRANT_NORTH;
                ELSE
                    STATE_NEXT <= REQ_CHECK_EAST;
                END IF;
                LAST_CHECKED_NEXT <= NORTH;
                
            WHEN REQ_CHECK_EAST =>
                IF VALID_REQ_EAST = '1' THEN
                    GRANTED_INPUT_NEXT <= EAST;
                    REQUESTED_OUTPUT_NEXT <= ROUTE_DIR_IN_EAST;
                    -- STORE FOR TAIL FLIT GRANT
                    HEADER_GRANTED_NEXT <= '1';
                    TAIL_GRANT_INPUT_NEXT <= EAST;
                    TAIL_GRANT_OUTPUT_NEXT <= ROUTE_DIR_IN_EAST;
                    STATE_NEXT <= GRANT_EAST;
                ELSE
                    STATE_NEXT <= REQ_CHECK_SOUTH;
                END IF;
                LAST_CHECKED_NEXT <= EAST;
                
            WHEN REQ_CHECK_SOUTH =>
                IF VALID_REQ_SOUTH = '1' THEN
                    GRANTED_INPUT_NEXT <= SOUTH;
                    REQUESTED_OUTPUT_NEXT <= ROUTE_DIR_IN_SOUTH;
                    -- STORE FOR TAIL FLIT GRANT
                    HEADER_GRANTED_NEXT <= '1';
                    TAIL_GRANT_INPUT_NEXT <= SOUTH;
                    TAIL_GRANT_OUTPUT_NEXT <= ROUTE_DIR_IN_SOUTH;
                    STATE_NEXT <= GRANT_SOUTH;
                ELSE
                    STATE_NEXT <= REQ_CHECK_WEST;
                END IF;
                LAST_CHECKED_NEXT <= SOUTH;
                
            WHEN REQ_CHECK_WEST =>
                IF VALID_REQ_WEST = '1' THEN
                    GRANTED_INPUT_NEXT <= WEST;
                    REQUESTED_OUTPUT_NEXT <= ROUTE_DIR_IN_WEST;
                    -- STORE FOR TAIL FLIT GRANT
                    HEADER_GRANTED_NEXT <= '1';
                    TAIL_GRANT_INPUT_NEXT <= WEST;
                    TAIL_GRANT_OUTPUT_NEXT <= ROUTE_DIR_IN_WEST;
                    STATE_NEXT <= GRANT_WEST;
                ELSE
                    STATE_NEXT <= ARB_IDLE;
                END IF;
                LAST_CHECKED_NEXT <= WEST;
                
            -- GRANT STATES (EACH LAST FOR ONE CLOCK CYCLE)
            WHEN GRANT_LOCAL =>
                STATE_NEXT <= ARB_IDLE;
                
            WHEN GRANT_NORTH =>
                STATE_NEXT <= ARB_IDLE;
                
            WHEN GRANT_EAST =>
                STATE_NEXT <= ARB_IDLE;
                
            WHEN GRANT_SOUTH =>
                STATE_NEXT <= ARB_IDLE;
                
            WHEN GRANT_WEST =>
                STATE_NEXT <= ARB_IDLE;
                
        END CASE;
    END PROCESS;

    -- ==========================================================================
    -- OUTPUT LOGIC PROCESS (10-STATE)
    -- ==========================================================================
    OUTPUT_LOGIC : PROCESS(STATE_REG, REQUESTED_OUTPUT_REG,
                          CREDIT_IN_LOCAL, CREDIT_IN_NORTH, CREDIT_IN_EAST,
                          CREDIT_IN_SOUTH, CREDIT_IN_WEST)
    BEGIN
        -- DEFAULT OUTPUTS
        GRANT_OUT_LOCAL <= '0';
        GRANT_OUT_NORTH <= '0';
        GRANT_OUT_EAST  <= '0';
        GRANT_OUT_SOUTH <= '0';
        GRANT_OUT_WEST  <= '0';

        W_REQ_OUT_LOCAL <= '0';
        W_REQ_OUT_NORTH <= '0';
        W_REQ_OUT_EAST  <= '0';
        W_REQ_OUT_SOUTH <= '0';
        W_REQ_OUT_WEST  <= '0';

        SEL_LOCAL <= DISCONNECTED;
        SEL_NORTH <= DISCONNECTED;
        SEL_EAST  <= DISCONNECTED;
        SEL_SOUTH <= DISCONNECTED;
        SEL_WEST  <= DISCONNECTED;

        CREDIT_OUT <= '0';

        CASE STATE_REG IS
            WHEN GRANT_LOCAL =>
                GRANT_OUT_LOCAL <= '1';
                CASE REQUESTED_OUTPUT_REG IS
                    WHEN LOCAL => 
                        W_REQ_OUT_LOCAL <= '1';
                        CREDIT_OUT <= CREDIT_IN_LOCAL;
                        SEL_LOCAL <= LOCAL;
                    WHEN NORTH => 
                        W_REQ_OUT_NORTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_NORTH;
                        SEL_NORTH <= LOCAL;
                    WHEN EAST  => 
                        W_REQ_OUT_EAST <= '1';
                        CREDIT_OUT <= CREDIT_IN_EAST;
                        SEL_EAST <= LOCAL;
                    WHEN SOUTH => 
                        W_REQ_OUT_SOUTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_SOUTH;
                        SEL_SOUTH <= LOCAL;
                    WHEN WEST  => 
                        W_REQ_OUT_WEST <= '1';
                        CREDIT_OUT <= CREDIT_IN_WEST;
                        SEL_WEST <= LOCAL;
		    WHEN DISCONNECTED => NULL;
                END CASE;
                
            WHEN GRANT_NORTH =>
                GRANT_OUT_NORTH <= '1';
                CASE REQUESTED_OUTPUT_REG IS
                    WHEN LOCAL => 
                        W_REQ_OUT_LOCAL <= '1';
                        CREDIT_OUT <= CREDIT_IN_LOCAL;
                        SEL_LOCAL <= NORTH;
                    WHEN NORTH => 
                        W_REQ_OUT_NORTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_NORTH;
                        SEL_NORTH <= NORTH;
                    WHEN EAST  => 
                        W_REQ_OUT_EAST <= '1';
                        CREDIT_OUT <= CREDIT_IN_EAST;
                        SEL_EAST <= NORTH;
                    WHEN SOUTH => 
                        W_REQ_OUT_SOUTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_SOUTH;
                        SEL_SOUTH <= NORTH;
                    WHEN WEST  => 
                        W_REQ_OUT_WEST <= '1';
                        CREDIT_OUT <= CREDIT_IN_WEST;
                        SEL_WEST <= NORTH;
		    WHEN DISCONNECTED => NULL;
                END CASE;
                
            WHEN GRANT_EAST =>
                GRANT_OUT_EAST <= '1';
                CASE REQUESTED_OUTPUT_REG IS
                    WHEN LOCAL => 
                        W_REQ_OUT_LOCAL <= '1';
                        CREDIT_OUT <= CREDIT_IN_LOCAL;
                        SEL_LOCAL <= EAST;
                    WHEN NORTH => 
                        W_REQ_OUT_NORTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_NORTH;
                        SEL_NORTH <= EAST;
                    WHEN EAST  => 
                        W_REQ_OUT_EAST <= '1';
                        CREDIT_OUT <= CREDIT_IN_EAST;
                        SEL_EAST <= EAST;
                    WHEN SOUTH => 
                        W_REQ_OUT_SOUTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_SOUTH;
                        SEL_SOUTH <= EAST;
                    WHEN WEST  => 
                        W_REQ_OUT_WEST <= '1';
                        CREDIT_OUT <= CREDIT_IN_WEST;
                        SEL_WEST <= EAST;
		    WHEN DISCONNECTED => NULL;
                END CASE;
                
            WHEN GRANT_SOUTH =>
                GRANT_OUT_SOUTH <= '1';
                CASE REQUESTED_OUTPUT_REG IS
                    WHEN LOCAL => 
                        W_REQ_OUT_LOCAL <= '1';
                        CREDIT_OUT <= CREDIT_IN_LOCAL;
                        SEL_LOCAL <= SOUTH;
                    WHEN NORTH => 
                        W_REQ_OUT_NORTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_NORTH;
                        SEL_NORTH <= SOUTH;
                    WHEN EAST  => 
                        W_REQ_OUT_EAST <= '1';
                        CREDIT_OUT <= CREDIT_IN_EAST;
                        SEL_EAST <= SOUTH;
                    WHEN SOUTH => 
                        W_REQ_OUT_SOUTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_SOUTH;
                        SEL_SOUTH <= SOUTH;
                    WHEN WEST  => 
                        W_REQ_OUT_WEST <= '1';
                        CREDIT_OUT <= CREDIT_IN_WEST;
                        SEL_WEST <= SOUTH;
		    WHEN DISCONNECTED => NULL;
                END CASE;
                
            WHEN GRANT_WEST =>
                GRANT_OUT_WEST <= '1';
                CASE REQUESTED_OUTPUT_REG IS
                    WHEN LOCAL => 
                        W_REQ_OUT_LOCAL <= '1';
                        CREDIT_OUT <= CREDIT_IN_LOCAL;
                        SEL_LOCAL <= WEST;
                    WHEN NORTH => 
                        W_REQ_OUT_NORTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_NORTH;
                        SEL_NORTH <= WEST;
                    WHEN EAST  => 
                        W_REQ_OUT_EAST <= '1';
                        CREDIT_OUT <= CREDIT_IN_EAST;
                        SEL_EAST <= WEST;
                    WHEN SOUTH => 
                        W_REQ_OUT_SOUTH <= '1';
                        CREDIT_OUT <= CREDIT_IN_SOUTH;
                        SEL_SOUTH <= WEST;
                    WHEN WEST  => 
                        W_REQ_OUT_WEST <= '1';
                        CREDIT_OUT <= CREDIT_IN_WEST;
                        SEL_WEST <= WEST;
		    WHEN DISCONNECTED => NULL;
                END CASE;
                
            WHEN OTHERS =>
                -- NO GRANTS IN OTHER STATES
                NULL;
                
        END CASE;
    END PROCESS;
		
		
               

END ARCHITECTURE FSM;
