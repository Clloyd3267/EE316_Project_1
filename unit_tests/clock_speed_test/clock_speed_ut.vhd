--------------------------------------------------------------------------------
-- Filename     : clock_speed_ut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : clock_speed_ut
-- Description  : Unit Test (ut) to test the use of different speeds to control
--                the generated rom controller and seven segment displays
--                on the Altera DE2 Devkit.
--------------------------------------------------------------------------------

-- Package for SRAM replacement data buffer
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.Numeric_std.all;
package buffer_util is
  type t_data_buffer is array (255 downto 0) of std_logic_vector(15 downto 0);
end package buffer_util;

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.buffer_util.all;

--------------
--  Entity  --
--------------
entity clock_speed_ut is
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
end entity clock_speed_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of clock_speed_ut is

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

  component rom_driver is
  port
  (
    address		      : in std_logic_vector(7 downto 0);
    clock		        : in std_logic  := '1';
    q		            : out std_logic_vector(15 downto 0)
  );
  end component rom_driver;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ    : integer := 50;                         -- System clock frequency in MHz
  constant C_1HZ_MAX_COUNT   : integer := C_CLK_FREQ_MHZ * 1000000;   -- Max count for 1 Hz counter
  constant C_255HZ_MAX_COUNT : integer := C_CLK_FREQ_MHZ * 255000000; -- Max count for 255 Hz counter
  constant C_MAX_ADDRESS     : unsigned(7 downto 0) := to_unsigned(255, 8);

  -------------
  -- SIGNALS --
  -------------

  signal s_address_toggle_cntr : integer range 0 TO C_255HZ_MAX_COUNT := 0;
  signal s_address_toggle      : std_logic; -- Address toggle signal

  -- State machine related signals
  type t_MODE_STATE is (INIT_STATE, OP_STATE);
  signal s_current_mode   : t_MODE_STATE := INIT_STATE;

  -- Data buffer
  signal s_data_buffer    : t_data_buffer;

  signal s_display_enable : std_logic;                      -- Display's enable control
  signal s_rom_data_bits      : std_logic_vector(15 downto 0);  -- Data to display

  signal s_display_data_bits      : std_logic_vector(15 downto 0);  -- Data to display
  signal s_addr_bits      : std_logic_vector(7 downto 0);   -- Address to display

  signal s_current_address : unsigned(7 downto 0) := (others=>'0');

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
    I_DATA_BITS      => s_display_data_bits,
    I_ADDR_BITS      => s_addr_bits,
    O_HEX0_N         => O_HEX0_N,
    O_HEX1_N         => O_HEX1_N,
    O_HEX2_N         => O_HEX2_N,
    O_HEX3_N         => O_HEX3_N,
    O_HEX4_N         => O_HEX4_N,
    O_HEX5_N         => O_HEX5_N
  );

  -- Rom controller to get data from read only memory
  ROM_CONTROLLER: rom_driver
  port map
  (
    address          => s_addr_bits,
	  clock            => I_CLK,
	  q                => s_rom_data_bits
  );

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : MODE_STATE_MACHINE
  -- Sensitivity List : I_CLK               : System clock
  --                    I_RESET_N           : System reset (active low logic)
  -- Useful Outputs   : s_current_mode      : Current mode of the system
  -- Description      : State machine to control different states for
  --                    initialization and operation of system.
  ------------------------------------------------------------------------------
  MODE_STATE_MACHINE: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_current_mode      <= INIT_STATE;

    elsif (rising_edge(I_CLK)) then
      case s_current_mode is
        when INIT_STATE =>
          if (s_current_address = C_MAX_ADDRESS)
            s_current_mode <= OP_STATE;
          else
            s_current_mode <= s_current_mode;
          end if;
        when OP_STATE =>
          s_current_mode <= s_current_mode;

        -- Error condition, should never occur
        when others =>
          s_current_mode <= INIT_STATE;
      end case;
    end if;
  end process MODE_STATE_MACHINE;
  ------------------------------------------------------------------------------

------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_TOGGLE_COUNTER
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_address_toggle : Pulsed signal to increment address
  -- Description      : Counter to delay changing address every 1 second
  ------------------------------------------------------------------------------
  ADDRESS_TOGGLE_COUNTER: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_address_toggle_cntr   :=  0;
      s_address_toggle        <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Address index output logic
      if (s_current_mode = INIT_STATE and s_address_toggle_cntr = C_255HZ_MAX_COUNT) or
         (s_current_mode = OP_STATE and s_address_toggle_cntr = C_1HZ_MAX_COUNT) then
        s_address_toggle      <= '1';
      else
        s_address_toggle      <= '0';
      end if;

      -- Counter Logic
      if (s_current_mode = INIT_STATE and s_address_toggle_cntr = C_255HZ_MAX_COUNT) or
         (s_current_mode = OP_STATE and s_address_toggle_cntr = C_1HZ_MAX_COUNT) then
        s_address_toggle_cntr := 0;
      else
        s_address_toggle_cntr := s_address_toggle_cntr + 1;
      end if;
    end if;
  end process ADDRESS_TOGGLE_COUNTER;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_INCREMENT
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_current_address
  -- Description      : A process to increment address depending on mode.
  ------------------------------------------------------------------------------
  ADDRESS_INCREMENT: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_current_address  := (others=>'0');

    elsif (rising_edge(I_CLK)) then

      -- Increment address
      if (s_address_toggle = '1') then
        s_current_address := s_current_address + 1;
      else
        s_current_address := s_current_address;
      end if;
    end if;
  end process ADDRESS_INCREMENT;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : DATA_FLOW_CONTROL
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_data_buffer    : Data buffer as a drop in for SRAM
  --                    s_display_enable : Digit enable for display
  -- Description      : A process to control where data goes depending on mode.
  ------------------------------------------------------------------------------
  ADDRESS_INCREMENT: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_display_enable <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Enable (turn on) the display depending on mode
      if (s_current_mode = INIT_STATE) then
        s_display_enable <= '0';
      else
        s_display_enable <= '1';
      end if;

      -- Control whether to get data from rom depending on mode
      if (s_current_mode = INIT_STATE) then
        s_data_buffer(to_integer(s_current_address)) <= s_rom_data_bits;
      else
        s_data_buffer <= s_data_buffer;
      end if;
    end if;
  end process ADDRESS_INCREMENT;
  ------------------------------------------------------------------------------

  s_addr_bits <= std_logic_vector(s_current_address);
  s_display_data_bits <= s_data_buffer(to_integer(s_current_address));

end architecture behavioral;
