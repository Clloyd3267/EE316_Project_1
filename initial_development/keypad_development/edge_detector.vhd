--------------------------------------------------------------------------------
-- Filename     : edge_detector.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : edge_detector
-- Description  : Create an edge trigger for a smooth (debounced) input.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.edge_detector_utilities.all;

--------------
--  Entity  --
--------------
entity edge_detector is
generic
(
  C_CLK_FREQ_MHZ   : integer     := 50;   -- System clock frequency in MHz
  C_TRIGGER_EDGE   : T_EDGE_TYPE := NONE  -- Edge to trigger on
);
port
(
  I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N        : in std_logic;  -- System reset (active low)
  I_SIGNAL         : in std_logic;  -- Input signal to pass through edge detector
  O_EDGE_SIGNAL    : out std_logic  -- Output pulse on (C_TRIGGER_EDGE) edge
);
end entity edge_detector;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of edge_detector is

  -------------
  -- SIGNALS --
  -------------
  signal s_signal_previous : std_logic := '0';
  signal s_signal_output   : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- Process Name     : EDGE_DETECTOR
  -- Sensitivity List : I_CLK           : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : s_signal_output : Output edge trigger signal
  -- Description      : Process to output a pulse when (C_TRIGGER_EDGE) edge is detected.
  ------------------------------------------------------------------------------
  EDGE_DETECTOR: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_signal_previous <= '0';
      s_signal_output   <= '0';

    elsif (rising_edge(I_CLK)) then

      -- Output logic (output pulse when (C_TRIGGER_EDGE) edge detected)
      case C_TRIGGER_EDGE is
        when RISING  =>
          s_signal_output <= ((not s_signal_previous) and I_SIGNAL);

        when FALLING =>
          s_signal_output <= (s_signal_previous and (not I_SIGNAL));

        when EITHER  =>
          s_signal_output <= (s_signal_previous xor I_SIGNAL);

        when NONE    =>
          s_signal_output <= I_SIGNAL;

        -- Error condition, should never occur
        when others  =>
          s_signal_output <= '0';
      end case;

      -- Set previous value to current value
      s_signal_previous <= I_SIGNAL;
    end if;
  end process EDGE_DETECTOR;
  ------------------------------------------------------------------------------

  -- Assign final edge detection
  O_EDGE_SIGNAL <= s_signal_output;

end architecture behavioral;