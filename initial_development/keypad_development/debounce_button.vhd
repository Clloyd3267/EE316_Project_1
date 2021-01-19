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
  C_CLK_FREQ_MHZ   : integer := 50;  -- System clock frequency in MHz
  C_STABLE_TIME_MS : integer := 10   -- Time required for button to remain stable in ms
);
port
(
  I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N        : in std_logic;  -- System reset (active low)
  I_BUTTON         : in std_logic;  -- Button data to be debounced
  O_BUTTON         : out std_logic  -- Debounced button data
);
end entity debounce_button;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of debounce_button is

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
    variable v_debounce_max_count : integer := C_CLK_FREQ_MHZ * C_STABLE_TIME_MS * 1000;
    variable v_debounce_counter   : integer range 0 TO v_debounce_max_count := 0;
  begin
    if (I_RESET_N = '0') then
      v_debounce_counter :=  0;
      s_button_output    <= '0';
      s_button_previous  <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Output logic (output when input has been stable for counter period)
      if (v_debounce_counter = v_debounce_max_count) then
        s_button_output <= I_BUTTON;
      else
        s_button_output <= s_button_output;
      end if;

      -- Counter logic (while signal has not changed, increment counter)
      if ((s_button_previous = '1') xor (I_BUTTON = '1')) then
        v_debounce_counter := 0;
      elsif (v_debounce_counter = v_debounce_max_count) then
        v_debounce_counter := 0;
      else
        v_debounce_counter := v_debounce_counter + 1;
      end if;

      -- Set previous value to current value
      s_button_previous <= I_BUTTON;
    end if;
  end process DEBOUNCE_CNTR;
  ------------------------------------------------------------------------------

  -- Assign final debounced output
  O_BUTTON <= s_button_output;

end architecture behavioral;