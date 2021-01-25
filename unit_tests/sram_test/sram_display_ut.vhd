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

  component sram_ctrl is
    port(
      clk, reset_n: in std_logic;
      mem: in std_logic;
      rw: in std_logic;
      addr: in std_logic_vector(17 downto 0);
      data_f2s: in std_logic_vector(15 downto 0);
      ready: out std_logic;
      data_s2f_r, data_s2f_ur: out std_logic_vector(15 downto 0);

      ad: out std_logic_vector(17 downto 0);
      ub_n, lb_n, we_n, oe_n: out std_logic;
      dio: inout std_logic_vector(7 downto 0);
      ce_n: out std_logic);
  end component sram_ctrl;

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
  signal s_addr_bits      : std_logic_vector(17 downto 0);   -- Address to display
  signal s_write_mode     : std_logic;
  signal s_trigger        : std_logic;

  signal s_mem: std_logic;
  signal s_rw: std_logic;
  signal s_addr: std_logic_vector(17 downto 0);
  signal s_data_f2s: std_logic_vector(15 downto 0);
  signal s_ready: std_logic;
  signal s_data_s2f_r, s_data_s2f_ur: std_logic_vector(15 downto 0);
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
    I_DATA_BITS      => s_data_bits,
    I_ADDR_BITS      => s_addr_bits(7 downto 0),
    O_HEX0_N         => O_HEX0_N,
    O_HEX1_N         => O_HEX1_N,
    O_HEX2_N         => O_HEX2_N,
    O_HEX3_N         => O_HEX3_N,
    O_HEX4_N         => O_HEX4_N,
    O_HEX5_N         => O_HEX5_N
  );

  -- CDL=> Add SRAM port map here
  SRAM_CONTROLLER: sram_ctrl
  port map(
    clk => I_CLK,
    reset_n => I_RESET_N,
    mem => s_mem,
    rw => s_rw,
    addr => s_addr_bits,
    data_f2s => s_data_f2s,
    ready => s_ready,
    data_s2f_r => s_data_s2f_r,
    data_s2f_ur => s_data_s2f_ur,
    ad => O_SRAM_ADDR,
    ub_n => O_SRAM_UB_N,
    lb_n => O_SRAM_LB_N,
    we_n => O_SRAM_WE_N
    oe_n => O_SRAM_OE_N,
    dio => IO_SRAM_DATA,
    ce_n => O_SRAM_CE_N
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
    variable v_max_address     : unsigned(7 downto 0) := to_unsigned(16, 8);
  begin
    if (I_RESET_N = '0') then
      s_current_address <= (others=>'0');
      s_addr_bits <= (others=> '0');
      s_rw                  <= '0';
      s_trigger <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Enable (turn on) the display
      s_display_enable      <= '1';

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
        s_trigger <= '1';
      else
        s_trigger <= '0';
      end if;

      if (s_current_address = v_max_address) then
        s_rw <= '1';
      else
        s_rw <= s_rw;
      end if;

      s_mem <= s_trigger;
      s_addr_bits <= (others=>'0');
      s_addr_bits(7 downto 0) <= std_logic_vector(s_current_address);
      s_data_f2s <= (others=>'0');
      s_data_f2s(7 downto 0) <= std_logic_vector(s_current_address);
      s_data_bits <= s_data_s2f_r;
    end if;
  end process SRAM_DISPLAY_TEST;
  ------------------------------------------------------------------------------

end architecture behavioral;
