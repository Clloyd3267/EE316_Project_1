--------------------------------------------------------------------------------
-- Filename     : debounce_button.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : debounce_button
-- Description  : Debounce a single button input for input stability.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--------------
--  Entity  --
--------------
entity debounce_button is
generic
(
  -- System clock frequency in MHz
  C_CLK_FREQ_MHZ    : integer := 50;

  -- Time required for button to remain stable in ms
  C_STABLE_TIME_MS  : integer := 10
);
port
(
  -- Clocks & Resets
  I_RESET_N : in std_logic;
  I_CLK     : in std_logic;

  -- Button data
  I_BUTTON  : in std_logic;

  -- Debounced button data
  O_BUTTON  : out std_logic
);
end entity debounce_button;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture rtl of debounce_button is

  -------------
  -- SIGNALS --
  -------------
  signal s_button_previous : std_logic := '0';
  signal s_button_output   : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- Process Name     : DEBOUNCE_CNTR
  -- Sensitivity List : I_CLK           : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : s_button_output : The debounced button signal
  -- Description      : Process to debounce an input from push button.
  ------------------------------------------------------------------------------
  DEBOUNCE_CNTR: process (I_CLK, I_RESET_N)
    variable v_max_count      : integer := C_CLK_FREQ_MHZ * C_STABLE_TIME_MS * 1000;
    variable v_debounce_count : integer range 0 TO v_max_count := '0';
  begin
    if (I_RESET_N = '0') then
      v_debounce_count   := '0';
      s_button_output    <= '0';
      s_button_previous  <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Counter logic (while signal has not changed, increment counter)
      if (s_button_previous xor I_BUTTON) then
        v_debounce_count := '0';
      else
        v_debounce_count := v_debounce_count + 1;
      end if;

      -- Output logic (output when input has been stable for counter period)
      if (v_debounce_count = v_max_count) then
        s_button_output  <= I_BUTTON;
      else
        s_button_output  <= s_button_output;
      end if;

      -- Set previous value to current value
      s_button_previous  <= I_BUTTON;
    end if;
  end process DEBOUNCE_CNTR;
  ------------------------------------------------------------------------------

  O_BUTTON <= s_button_output;