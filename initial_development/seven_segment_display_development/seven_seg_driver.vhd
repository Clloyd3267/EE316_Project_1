--------------------------------------------------------------------------------
-- Filename     : seven_seg_driver.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : seven_seg_driver
-- Description  : Map a 4-bit nibble of hex data to segment pins for a single
--                seven segment display.
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
entity seven_seg_driver is
generic
(
  C_CLK_FREQ_MHZ : integer := 50                     -- System clock frequency in MHz
);
port
(
  I_CLK          : in std_logic;                     -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                     -- System reset (active low)
  I_DATA_NIBBLE  : in Std_logic_Vector(3 downto 0);  -- Input data (hex nibble) to display
  O_SEGMENT_N    : out Std_logic_Vector(6 downto 0)  -- Output segments (active low)
);
end entity seven_seg_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of seven_seg_driver is
begin

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : HEX_DECODER
  -- Sensitivity List : I_CLK           : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : O_SEGMENT_N     : Seven segment display digit data
  -- Description      : Logic to map a binary nibble (0-F) to an active low
  --                    seven segment display.
  ------------------------------------------------------------------------------
  HEX_DECODER: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      O_SEGMENT_N     <= "1111111";   -- ' '

    elsif (rising_edge(I_CLK)) then
      case(I_DATA_NIBBLE) is
        when "0000" =>
          O_SEGMENT_N <= "1000000";   -- '0'
        when "0001" =>
          O_SEGMENT_N <= "1111001";   -- '1'
        when "0010" =>
          O_SEGMENT_N <= "0100100";   -- '2'
        when "0011" =>
          O_SEGMENT_N <= "0110000";   -- '3'
        when "0100" =>
          O_SEGMENT_N <= "0011001";   -- '4'
        when "0101" =>
          O_SEGMENT_N <= "0010010";   -- '5'
        when "0110" =>
          O_SEGMENT_N <= "0000010";   -- '6'
        when "0111" =>
          O_SEGMENT_N <= "1111000";   -- '7'
        when "1000" =>
          O_SEGMENT_N <= "0000000";   -- '8'
        when "1001" =>
          O_SEGMENT_N <= "0010000";   -- '9'
        when "1010" =>
          O_SEGMENT_N <= "0001000";   -- 'A'
        when "1011" =>
          O_SEGMENT_N <= "0000011";   -- 'b'
        when "1100" =>
          O_SEGMENT_N <= "1000110";   -- 'C'
        when "1101" =>
          O_SEGMENT_N <= "0100001";   -- 'd'
        when "1110" =>
          O_SEGMENT_N <= "0000110";   -- 'E'
        when "1111" =>
          O_SEGMENT_N <= "0001110";   -- 'F'
        when others =>
          O_SEGMENT_N <= "1111111";   -- ' '
      end case;
    end if;
  end process HEX_DECODER;
  ------------------------------------------------------------------------------
end architecture behavioral;
