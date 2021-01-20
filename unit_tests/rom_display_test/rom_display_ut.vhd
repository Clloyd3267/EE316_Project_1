--------------------------------------------------------------------------------
-- Filename     : rom_display_ut
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : rom_display_ut
-- Description  : Unit Test (ut) to test the generated rom controller
--                (using Quartus MegaWizard tool) and seven segment displays
--                on the Altera DE2 Devkit.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.Numeric_std.all;

--------------
--  Entity  --
--------------
entity rom_display_ut is
port
(
  I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                      -- System reset (active low)
  O_HEX0_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 0
  O_HEX1_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 1
  O_HEX2_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 2
  O_HEX3_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 3
  O_HEX4_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 4
  O_HEX5_N       : out std_logic_vector(6 downto 0)   -- Segment data for seven segment display 5
);
end entity rom_display_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of rom_display_ut is

  ----------------
  -- Components --
  ----------------
  component de2_display_driver is
  generic
  (
    C_CLK_FREQ_MHZ   : integer := 50                      -- System clock frequency in MHz
  );
  port
  (
    I_CLK            : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;                      -- System reset (active low)
    I_DISPLAY_ENABLE : in std_logic;                      -- Control to enable or blank the display
    I_DATA_BITS      : in std_logic_vector(15 downto 0);  -- Input data to display
    I_ADDR_BITS      : in std_logic_vector(7 downto 0);   -- Input address to display
    O_HEX0_N         : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 0
    O_HEX1_N         : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 1
    O_HEX2_N         : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 2
    O_HEX3_N         : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 3
    O_HEX4_N         : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 4
    O_HEX5_N         : out std_logic_vector(6 downto 0)   -- Segment data for seven segment display 5
  );
  end component de2_display_driver;
  
  component rom_controller IS
  port
  (
    address		     : IN STD_LOGIC_VECTOR (7 downto 0);
    clock		     : IN std_logic  := '1';
    q		         : OUT std_logic_vector (15 downto 0)
  );
  end component rom_controller;  

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ : integer := 50;                  -- System clock frequency in MHz

  -------------
  -- SIGNALS --
  -------------

  signal s_address_toggle : std_logic;                      -- Address toggle signal
  signal s_display_enable : std_logic;                      -- Display's enable control
  signal s_data_bits      : std_logic_vector(15 downto 0);  -- Data to display
  signal s_addr_bits      : std_logic_vector(7 downto 0);   -- Address to display

begin

  -- Display controller to display data and address
  DISPLAY_CONTROLLER: de2_display_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => s_display_enable,
    I_DATA_BITS      => s_data_bits,
    I_ADDR_BITS      => s_addr_bits,
    O_HEX0_N         => O_HEX0_N,
    O_HEX1_N         => O_HEX1_N,
    O_HEX2_N         => O_HEX2_N,
    O_HEX3_N         => O_HEX3_N,
    O_HEX4_N         => O_HEX4_N,
    O_HEX5_N         => O_HEX5_N
  );
  
  -- Rom controller to get data from read only memory
  -- CDL=> ROM_CONTROLLER: rom_driver
  ROM_DRIVER: rom_controller
  port map
  (
    address          => s_addr_bits,
	clock            => I_CLK,
	q                => s_data_bits
  );

  ---------------
  -- Processes --
  ---------------

------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_TOGGLE_COUNTER
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_address_toggle : Pulsed signal to increment address
  -- Description      : Counter to delay changing address every 1 second
  ------------------------------------------------------------------------------
  ADDRESS_TOGGLE_COUNTER: process (I_CLK, I_RESET_N)
    variable v_address_toggle_max_count : integer := C_CLK_FREQ_MHZ * 1000000;
    variable v_address_toggle_cntr      : integer range 0 TO v_address_toggle_max_count := 0;
  begin
    if (I_RESET_N = '0') then
      v_address_toggle_cntr   :=  0;
      s_address_toggle        <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Address index output logic
      if (v_address_toggle_cntr = v_address_toggle_max_count) then
        s_address_toggle      <= '1';
      else
        s_address_toggle      <= '0';
      end if;

      -- Counter Logic
      if (v_address_toggle_cntr = v_address_toggle_max_count) then
        v_address_toggle_cntr := 0;
      else
        v_address_toggle_cntr := v_address_toggle_cntr + 1;
      end if;
    end if;
  end process ADDRESS_TOGGLE_COUNTER;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : ROM_DISPLAY_TEST
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   :
  --                    s_display_enable : Digit enable for display
  -- Description      : A process to pass data from preloaded ROM to a display
  --                    controller.
  ------------------------------------------------------------------------------
  ROM_DISPLAY_TEST: process (I_CLK, I_RESET_N)
    variable v_max_address     : unsigned(7 downto 0) := to_unsigned(255, 8);
    variable v_current_address : unsigned(7 downto 0) := (others=>'0');
  begin
    if (I_RESET_N = '0') then
      v_current_address  := (others=>'0');
      s_addr_bits <= (others=> '0');

    elsif (rising_edge(I_CLK)) then
      -- Enable (turn on) the display
      s_display_enable      <= '1';

      -- Increment address
      if (s_address_toggle = '1') then
        v_current_address := v_current_address + 1;
      else
        v_current_address := v_current_address;
      end if;

      s_addr_bits <= std_logic_vector(v_current_address);
    end if;
  end process ROM_DISPLAY_TEST;
  ------------------------------------------------------------------------------

end architecture behavioral;
