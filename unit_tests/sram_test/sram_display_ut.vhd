--------------------------------------------------------------------------------
-- Filename     : sram_display_ut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : sram_display_ut
-- Description  : Unit Test (ut) to test an SRAM coontroller.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.Numeric_std.all;

--------------
--  Entity  --
--------------
entity sram_display_ut is
port
(
  I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                      -- System reset (active low)
  O_HEX0_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 0
  O_HEX1_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 1
  O_HEX2_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 2
  O_HEX3_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 3
  O_HEX4_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 4
  O_HEX5_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 5

  O_SRAM_ADDR    : out std_logic_vector(17 downto 0);
  IO_SRAM_DATA   : inout std_logic_vector(15 downto 0);
  O_SRAM_WE_N    : out std_logic;
  O_SRAM_OE_N    : out std_logic;
  O_SRAM_UB_N    : out std_logic;
  O_SRAM_LB_N    : out std_logic;
  O_SRAM_CE_N    : out std_logic

);
end entity sram_display_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of sram_display_ut is

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

  component sram_driver is
  generic
  (
    C_CLK_FREQ_MHZ    : integer       -- System clock frequency in MHz
  );
  port
  (
    I_CLK             : in std_logic; -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N         : in std_logic; -- System reset (active low)

    I_SRAM_ENABLE     : in std_logic;
    I_COMMAND_TRIGGER : in std_logic;
    I_RW              : in std_logic;
    I_ADDRESS         : in std_logic_vector(17 downto 0);
    I_DATA            : in std_logic_vector(15 downto 0);
    O_BUSY            : out std_logic;
    O_DATA            : out std_logic_vector(15 downto 0);

    -- Low level pass through signals
    IO_SRAM_DATA      : inout std_logic_vector(15 downto 0);
    O_SRAM_ADDR       : out std_logic_vector(17 downto 0);
    O_SRAM_WE_N       : out std_logic;
    O_SRAM_OE_N       : out std_logic;
    O_SRAM_UB_N       : out std_logic;
    O_SRAM_LB_N       : out std_logic;
    O_SRAM_CE_N       : out std_logic
  );
  end component sram_driver;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ : integer := 50;                  -- System clock frequency in MHz

  -------------
  -- SIGNALS --
  -------------

  signal s_address_toggle : std_logic;                      -- Address toggle signal

  signal s_display_enable : std_logic;                      -- Display's enable control

  signal s_current_address : unsigned(17 downto 0);

  signal s_sram_enable      : std_logic;
  signal s_sram_trigger     : std_logic;
  signal s_sram_rw          : std_logic;
  signal s_sram_busy        : std_logic;
  signal s_sram_read_data   : std_logic_vector(15 downto 0);

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
    I_DATA_BITS      => s_sram_read_data,
    I_ADDR_BITS      => s_current_address(7 downto 0),
    O_HEX0_N         => O_HEX0_N,
    O_HEX1_N         => O_HEX1_N,
    O_HEX2_N         => O_HEX2_N,
    O_HEX3_N         => O_HEX3_N,
    O_HEX4_N         => O_HEX4_N,
    O_HEX5_N         => O_HEX5_N
  );

  SRAM_CONTROLLER: sram_driver
  generic
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port
  (
    I_CLK             => I_CLK,
    I_RESET_N         => I_RESET_N,
    I_SRAM_ENABLE     => s_sram_enable,
    I_COMMAND_TRIGGER => s_sram_trigger,
    I_RW              => s_sram_rw,
    I_ADDRESS         => s_current_address,
    I_DATA            => s_current_address(15 downto 0),
    O_BUSY            => s_sram_busy,
    O_DATA            => s_sram_read_data,
    IO_SRAM_DATA      => IO_SRAM_DATA,
    O_SRAM_ADDR       => O_SRAM_ADDR,
    O_SRAM_WE_N       => O_SRAM_WE_N,
    O_SRAM_OE_N       => O_SRAM_OE_N,
    O_SRAM_UB_N       => O_SRAM_UB_N,
    O_SRAM_LB_N       => O_SRAM_LB_N,
    O_SRAM_CE_N       => O_SRAM_CE_N
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
    variable v_address_toggle_max_count : integer := C_CLK_FREQ_MHZ * 1000000;  -- 1HZ
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
  -- Process Name     : SRAM_DISPLAY_TEST
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   :
  --                    s_display_enable : Digit enable for display
  -- Description      : A process to pass data from preloaded ROM to a display
  --                    controller.
  ------------------------------------------------------------------------------
  SRAM_DISPLAY_TEST: process (I_CLK, I_RESET_N)
    variable v_max_address     : unsigned(17 downto 0) := to_unsigned(16, 18);
  begin
    if (I_RESET_N = '0') then
      s_display_enable  <= '0';
      s_sram_enable     <= '0';
      s_current_address <= (others=>'0');
      s_sram_trigger    <= '0';
      s_sram_rw         <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Enable (turn on) the display
      s_display_enable <= '1';

      -- Enable (turn on) the sram
      s_sram_enable    <= '1';

      -- Increment address
      if (s_address_toggle = '1') then
        if (s_current_address = v_max_address) then
          s_current_address <= (others=>'0');
        else
          s_current_address <= s_current_address + 1;
        end if;
      else
        s_current_address <= s_current_address;
      end if;

      -- Trigger SRAM
      if (s_address_toggle = '1') then
        s_sram_trigger <= '1';
      else
        s_sram_trigger <= '0';
      end if;

      -- Write until max address is reached first time, then read
      if (s_address_toggle = '1') then
        if (s_current_address = v_max_address) then
          s_sram_rw <= '1';
        else
          s_sram_rw <= s_sram_rw;
        end if;
      else
        s_sram_rw <= s_sram_rw;
      end if;
    end if;
  end process SRAM_DISPLAY_TEST;
  ------------------------------------------------------------------------------

end architecture behavioral;
