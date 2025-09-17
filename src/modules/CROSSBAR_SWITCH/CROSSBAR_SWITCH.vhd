-- CROSSBAR SWITCH
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE WORK.ROUTER_PKG.ALL;

ENTITY CROSSBAR_SWITCH IS
    PORT (
        -- DATA INPUTS FROM ALL INPUT BUFFERS
        DATA_LOCAL_IN  : IN  FLIT;
        DATA_NORTH_IN  : IN  FLIT;
        DATA_EAST_IN   : IN  FLIT;
        DATA_SOUTH_IN  : IN  FLIT;
        DATA_WEST_IN   : IN  FLIT;
        
        -- SELECTORS THAT COME FROM ARBITER
	-- EACH ONE CONTROLS THE OUTPUT OF IT'S MULTIPLEXER
        SEL_LOCAL      : IN  DIRECTION;  
        SEL_NORTH      : IN  DIRECTION;   
        SEL_EAST       : IN  DIRECTION;  
        SEL_SOUTH      : IN  DIRECTION;  
        SEL_WEST       : IN  DIRECTION;  
        
        -- DATA OUTPUTS TO ADJACENT ROUTERS
        DATA_LOCAL_OUT : OUT FLIT;  -- TO LOCAL NETWORK INTERFACE (EXTRACTOR CHANNEL)
        DATA_NORTH_OUT : OUT FLIT;  -- TO NORTH ROUTER
        DATA_EAST_OUT  : OUT FLIT;  -- TO EAST  ROUTER
        DATA_SOUTH_OUT : OUT FLIT;  -- TO SOUTH ROUTER
        DATA_WEST_OUT  : OUT FLIT   -- TO WEST  ROUTER
    );
END ENTITY CROSSBAR_SWITCH;

ARCHITECTURE STRUCT OF CROSSBAR_SWITCH IS

    -- LOCAL OUTPUT MUX
    COMPONENT CROSSBAR_MUX_LOCAL 
        PORT (
            NORTH_IN : IN  FLIT;
            EAST_IN  : IN  FLIT;
            SOUTH_IN : IN  FLIT;
            WEST_IN  : IN  FLIT;
            SEL      : IN  DIRECTION;  
            DATA_OUT : OUT FLIT
        );
    END COMPONENT;

    -- NORTH OUTPUT MUX
    COMPONENT CROSSBAR_MUX_NORTH
        PORT (
            LOCAL_IN : IN  FLIT;
            EAST_IN  : IN  FLIT;
            SOUTH_IN : IN  FLIT;
            WEST_IN  : IN  FLIT;
            SEL      : IN  DIRECTION;  
            DATA_OUT : OUT FLIT
        );
    END COMPONENT;

    -- EAST OUTPUT MUX
    COMPONENT CROSSBAR_MUX_EAST
        PORT (
            LOCAL_IN : IN  FLIT;
            NORTH_IN : IN  FLIT;
            SOUTH_IN : IN  FLIT;
            WEST_IN  : IN  FLIT;
            SEL      : IN  DIRECTION;  
            DATA_OUT : OUT FLIT
        );
    END COMPONENT;

    -- SOUTH OUTPUT MUX
    COMPONENT CROSSBAR_MUX_SOUTH
        PORT (
            LOCAL_IN : IN  FLIT;
            NORTH_IN : IN  FLIT;
            EAST_IN  : IN  FLIT;
            WEST_IN  : IN  FLIT;
            SEL      : IN  DIRECTION; 
            DATA_OUT : OUT FLIT
        );
    END COMPONENT;

    -- WEST OUTPUT MUX
    COMPONENT CROSSBAR_MUX_WEST
        PORT (
            LOCAL_IN : IN  FLIT;
            NORTH_IN : IN  FLIT;
            EAST_IN  : IN  FLIT;
            SOUTH_IN : IN  FLIT;
            SEL      : IN  DIRECTION;  
            DATA_OUT : OUT FLIT
        );
    END COMPONENT;

BEGIN

    -- LOCAL OUTPUT MUX (EXTRACTOR CHANNEL TO IP CORE)
    MUX_LOCAL : CROSSBAR_MUX_LOCAL
        PORT MAP (
            NORTH_IN => DATA_NORTH_IN,
            EAST_IN  => DATA_EAST_IN,
            SOUTH_IN => DATA_SOUTH_IN,
            WEST_IN  => DATA_WEST_IN,
            SEL      => SEL_LOCAL,  
            DATA_OUT => DATA_LOCAL_OUT
        );

    -- NORTH OUTPUT MUX (TO NORTH ROUTER)
    MUX_NORTH : CROSSBAR_MUX_NORTH
        PORT MAP (
            LOCAL_IN => DATA_LOCAL_IN,
            EAST_IN  => DATA_EAST_IN,
            SOUTH_IN => DATA_SOUTH_IN,
            WEST_IN  => DATA_WEST_IN,
            SEL      => SEL_NORTH,  
            DATA_OUT => DATA_NORTH_OUT
        );

    -- EAST OUTPUT MUX (TO EAST ROUTER)
    MUX_EAST : CROSSBAR_MUX_EAST
        PORT MAP (
            LOCAL_IN => DATA_LOCAL_IN,
            NORTH_IN => DATA_NORTH_IN,
            SOUTH_IN => DATA_SOUTH_IN,
            WEST_IN  => DATA_WEST_IN,
            SEL      => SEL_EAST, 
            DATA_OUT => DATA_EAST_OUT
        );

    -- SOUTH OUTPUT MUX (TO SOUTH ROUTER)
    MUX_SOUTH : CROSSBAR_MUX_SOUTH
        PORT MAP (
            LOCAL_IN => DATA_LOCAL_IN,
            NORTH_IN => DATA_NORTH_IN,
            EAST_IN  => DATA_EAST_IN,
            WEST_IN  => DATA_WEST_IN,
            SEL      => SEL_SOUTH,  
            DATA_OUT => DATA_SOUTH_OUT
        );

    -- WEST OUTPUT MUX (TO WEST ROUTER)
    MUX_WEST : CROSSBAR_MUX_WEST
        PORT MAP (
            LOCAL_IN => DATA_LOCAL_IN,
            NORTH_IN => DATA_NORTH_IN,
            EAST_IN  => DATA_EAST_IN,
            SOUTH_IN => DATA_SOUTH_IN,
            SEL      => SEL_WEST,  
            DATA_OUT => DATA_WEST_OUT
        );

END ARCHITECTURE STRUCT;
