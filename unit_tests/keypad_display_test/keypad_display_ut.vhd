--------------------------------------------------------------------------------
-- Filename     : keypad_display_ut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : keypad_display_ut
-- Description  : Test the matrix keypad and seven segment displays on the
--                Altera DE2 Devkit.
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
entity keypad_display_ut is
port
(
  I_CLK          : in std_logic;                     -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                     -- System reset (active low)
  I_DATA_NIBBLE  : in Std_logic_Vector(3 downto 0);  -- Input data (hex nibble) to display
  O_SEGMENT_N    : out Std_logic_Vector(6 downto 0)  -- Output segments (active low)
  );
  end entity keypad_display_ut;

  constant <constant_name> : <type> := <value>;
--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of keypad_display_ut is
begin

  ----------------
  -- Components --
  ----------------

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

    elsif (rising_edge(I_CLK)) then

    end if;
  end process HEX_DECODER;
  ------------------------------------------------------------------------------
end architecture behavioral;
