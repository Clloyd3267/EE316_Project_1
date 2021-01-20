--------------------------------------------------------------------------------
-- Filename     : de2_display_driver.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : de2_display_driver
-- Description  : Map an address (8-bit) and data (16-bit) to onboard seven
--                segment displays HEX5-HEX0.
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
entity de2_display_driver is
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
end entity de2_display_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of de2_display_driver is

  ----------------
  -- Components --
  ----------------
  component seven_seg_driver is
    generic
    (
      C_CLK_FREQ_MHZ   : integer                           -- System clock frequency in MHz
    );
    port
    (
      I_CLK            : in std_logic;                     -- System clk frequency of (C_CLK_FREQ_MHZ)
      I_RESET_N        : in std_logic;                     -- System reset (active low)
      I_DISPLAY_ENABLE : in std_logic;                     -- Control to enable or blank the display
      I_DATA_NIBBLE    : in std_logic_vector(3 downto 0);  -- Input data (hex nibble) to display
      O_SEGMENT_N      : out std_logic_vector(6 downto 0)  -- Output segments (active low)
    );
    end component seven_seg_driver;

begin

  -- Device Driver for seven segment display 0
  hex0: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_DATA_BITS(3 downto 0),
    O_SEGMENT_N      => O_HEX0_N
  );

  -- Device Driver for seven segment display 1
  hex1: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_DATA_BITS(7 downto 4),
    O_SEGMENT_N      => O_HEX1_N
  );

  -- Device Driver for seven segment display 2
  hex2: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_DATA_BITS(11 downto 8),
    O_SEGMENT_N      => O_HEX2_N
  );

  -- Device Driver for seven segment display 3
  hex3: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_DATA_BITS(15 downto 12),
    O_SEGMENT_N      => O_HEX3_N
  );

  -- Device Driver for seven segment display 4
  hex4: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_ADDR_BITS(3 downto 0),
    O_SEGMENT_N      => O_HEX4_N
  );

  -- Device Driver for seven segment display 5
  hex5: seven_seg_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => I_DISPLAY_ENABLE,
    I_DATA_NIBBLE    => I_ADDR_BITS(7 downto 4),
    O_SEGMENT_N      => O_HEX5_N
  );

end architecture behavioral;
