--------------------------------------------------------------------------------
-- Filename     : keypad_5x4_wrapper.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : keypad_5by4_wrapper
-- Description  : Wrapper for 5x4 keypad driver.
--
--                Assumes (5x4) keypad in the form:
--                +-------+-------+-------+-------+
--                |   A   |   B   |   C   |   D   |
--                +-------+-------+-------+-------+
--                |   1   |   2   |   3   |   E   |
--                +-------+-------+-------+-------+
--                |   4   |   5   |   6   |   F   |
--                +-------+-------+-------+-------+
--                |   7   |   8   |   9   | SHIFT |
--                +-------+-------+-------+-------+
--                |   0   |   H   |   L   |       |
--                +-------+-------+-------+-------+
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
entity keypad_5x4_wrapper is
generic
(
  C_CLK_FREQ_MHZ   : integer := 50                      -- System clock frequency in MHz
);
port
(
  I_CLK            : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N        : in std_logic;                      -- System reset (active low)
  I_KEYPAD_ROWS    : in std_logic_vector(4 downto 0);   -- Keypad Inputs (rows)
  O_KEYPAD_COLS    : out std_logic_vector(3 downto 0);  -- Keypad Outputs (cols)

  -- Data of pressed key
  -- 5th bit enabled indicates command button pressed
  O_KEYPAD_DATA    : out std_logic_vector(4 downto 0);
  -- +-------------+-------------+-------------+--------+
  -- | Description | Command Bit | Data Nibble | Data   |
  -- |             | (4)         | (3-0)       |  (4-0) |
  -- +-------------+-------------+-------------+--------+
  -- | Shift       | 1           | 0000        | 10000  |
  -- | H           | 1           | 0001        | 10001  |
  -- | L           | 1           | 0010        | 11111  |
  -- | 0x0         | 0           | 0000        | 00000  |
  -- | 0x1         | 0           | 0001        | 00001  |
  -- | 0x2         | 0           | 0010        | 00010  |
  -- | 0x3         | 0           | 0011        | 00011  |
  -- | 0x4         | 0           | 0100        | 00100  |
  -- | 0x5         | 0           | 0101        | 00101  |
  -- | 0x6         | 0           | 0110        | 00110  |
  -- | 0x7         | 0           | 0111        | 00111  |
  -- | 0x8         | 0           | 1000        | 01000  |
  -- | 0x9         | 0           | 1001        | 01001  |
  -- | 0xA         | 0           | 1010        | 01010  |
  -- | 0xB         | 0           | 1011        | 01011  |
  -- | 0xC         | 0           | 1100        | 01100  |
  -- | 0xD         | 0           | 1101        | 01101  |
  -- | 0xE         | 0           | 1110        | 01110  |
  -- | 0xF         | 0           | 1111        | 01111  |
  -- +-------------+-------------+-------------+--------+

  -- Trigger to indicate a key was pressed (single clock cycle pulse)
  O_KEYPRESSED     : out std_logic
);
end entity keypad_5x4_wrapper;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of keypad_5x4_wrapper is

  ----------------
  -- Components --
  ----------------
  component keypad_driver is
  generic
  (
    C_CLK_FREQ_MHZ   : integer;      -- System clock frequency in MHz
    C_STABLE_TIME_MS : integer;      -- Time required for button to remain stable in ms
    C_SCAN_TIME_US   : integer;      -- Time required for column power to fully settle in us
    C_TRIGGER_EDGE   : T_EDGE_TYPE;  -- Edge to trigger on

    -- Dimensions of matrix keypad
    C_NUM_ROWS       : integer;
    C_NUM_COLS       : integer
  );
  port
  (
    I_CLK            : in std_logic;                                   -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;                                   -- System reset (active low)
    I_KEYPAD_ENABLE  : in std_logic;                                   -- Module enable signal
    I_KEYPAD_ROWS    : in std_logic_vector((C_NUM_ROWS-1) downto 0);   -- Keypad Inputs (rows)
    O_KEYPAD_COLS    : out std_logic_vector((C_NUM_COLS-1) downto 0);  -- Keypad Outputs (cols)

    -- Final binary representation of keypad state
    O_KEYPAD_BINARY  : out std_logic_vector(((C_NUM_ROWS * C_NUM_COLS)-1) downto 0)
  );
  end component keypad_driver;

  ---------------
  -- Constants --
  ---------------

  constant C_STABLE_TIME_MS : integer     := 5;       -- Time required for button to remain stable in ms
  constant C_SCAN_TIME_US   : integer     := 2;       -- Time required for column power to fully settle in us
  constant C_TRIGGER_EDGE   : T_EDGE_TYPE := RISING;  -- Edge to trigger on

  -- Dimensions of matrix keypad
  constant C_NUM_ROWS       : integer     := 5;
  constant C_NUM_COLS       : integer     := 4;

  -------------
  -- SIGNALS --
  -------------

  -- Keypad enable signal to enable or disable keypad module
  signal s_keypad_enable    : std_logic := '0';

  -- Keypad scan column toggle to account for delay time powering columns
  signal s_keypad_binary    : std_logic_vector(((C_NUM_ROWS * C_NUM_COLS)-1) downto 0);
  signal s_keypad_data      : std_logic_vector(4 downto 0);

begin
  -- Device driver for keypad
  matrix_keypad_driver: keypad_driver
  generic map
  (
    C_CLK_FREQ_MHZ   => C_CLK_FREQ_MHZ,
    C_STABLE_TIME_MS => C_STABLE_TIME_MS,
    C_SCAN_TIME_US   => C_SCAN_TIME_US,
    C_TRIGGER_EDGE   => C_TRIGGER_EDGE,
    C_NUM_ROWS       => C_NUM_ROWS,
    C_NUM_COLS       => C_NUM_COLS
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_KEYPAD_ENABLE  => s_keypad_enable,
    I_KEYPAD_ROWS    => I_KEYPAD_ROWS,
    O_KEYPAD_COLS    => O_KEYPAD_COLS,
    O_KEYPAD_BINARY  => s_keypad_binary
  );

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_DATA_MAP
  -- Sensitivity List : I_CLK         : System clock
  --                    I_RESET_N     : System reset (active low logic)
  -- Useful Outputs   : O_KEYPRESSED  : Trigger indicating (s_keypad_data) is valid
  --                    s_keypad_data : Data from button press
  -- Description      : Maps raw edge inputs from keypad driver to a more user
  --                    friendly data and trigger outputs.
  ------------------------------------------------------------------------------
  KEYPAD_DATA_MAP: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_keypad_enable <= '0';
      O_KEYPRESSED    <= '0';
      s_keypad_data   <= (others=>'0');

    elsif (rising_edge(I_CLK)) then
      -- Enable the keypad
      s_keypad_enable <= '1';

      -- Check if a button is pressed
    if (to_integer(unsigned(s_keypad_binary)) = 0) or
       (s_keypad_binary(19) = '1') then
		  O_KEYPRESSED <= '0';
		else
		  O_KEYPRESSED <= '1';
		 end if;

      -- Map keypad data (See above table for mapping)
      if    (s_keypad_binary(0) = '1')  then s_keypad_data <= "01010";        -- 0xA
      elsif (s_keypad_binary(1) = '1')  then s_keypad_data <= "01011";        -- 0xB
      elsif (s_keypad_binary(2) = '1')  then s_keypad_data <= "01100";        -- 0xC
      elsif (s_keypad_binary(3) = '1')  then s_keypad_data <= "01101";        -- 0xD
      elsif (s_keypad_binary(4) = '1')  then s_keypad_data <= "00001";        -- 0x1
      elsif (s_keypad_binary(5) = '1')  then s_keypad_data <= "00010";        -- 0x2
      elsif (s_keypad_binary(6) = '1')  then s_keypad_data <= "00011";        -- 0x3
      elsif (s_keypad_binary(7) = '1')  then s_keypad_data <= "01110";        -- 0xE
      elsif (s_keypad_binary(8) = '1')  then s_keypad_data <= "00100";        -- 0x4
      elsif (s_keypad_binary(9) = '1')  then s_keypad_data <= "00101";        -- 0x5
      elsif (s_keypad_binary(10) = '1') then s_keypad_data <= "00110";        -- 0x6
      elsif (s_keypad_binary(11) = '1') then s_keypad_data <= "01111";        -- 0xF
      elsif (s_keypad_binary(12) = '1') then s_keypad_data <= "00111";        -- 0x7
      elsif (s_keypad_binary(13) = '1') then s_keypad_data <= "01000";        -- 0x8
      elsif (s_keypad_binary(14) = '1') then s_keypad_data <= "01001";        -- 0x9
      elsif (s_keypad_binary(15) = '1') then s_keypad_data <= "10000";        -- Shift
      elsif (s_keypad_binary(16) = '1') then s_keypad_data <= "00000";        -- 0x0
      elsif (s_keypad_binary(17) = '1') then s_keypad_data <= "10001";        -- H
      elsif (s_keypad_binary(18) = '1') then s_keypad_data <= "10010";        -- L
      else                                   s_keypad_data <= s_keypad_data;  -- Undefined
      end if;
    end if;
  end process KEYPAD_DATA_MAP;
  ------------------------------------------------------------------------------

  -- Assign final outputs
  O_KEYPAD_DATA <= s_keypad_data;

end architecture behavioral;