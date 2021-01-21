--------------------------------------------------------------------------------
-- Filename     : keypad_shift_reg_display_ut.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : keypad_shift_reg_display_ut
-- Description  : Unit Test (ut) to test shift register functionality for the
--                data and address input.
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
entity keypad_shift_reg_display_ut is
port
(
  I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                      -- System reset (active low)
  I_KEYPAD_ROWS  : in std_logic_vector(4 downto 0);   -- Keypad Inputs (rows)
  O_KEYPAD_COLS  : out std_logic_vector(3 downto 0);  -- Keypad Outputs (cols)
  O_HEX0_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 0
  O_HEX1_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 1
  O_HEX2_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 2
  O_HEX3_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 3
  O_HEX4_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 4
  O_HEX5_N       : out std_logic_vector(6 downto 0)   -- Segment data for seven segment display 5
);
end entity keypad_shift_reg_display_ut;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of keypad_shift_reg_display_ut is

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

  component keypad_5x4_wrapper is
    generic
    (
      C_CLK_FREQ_MHZ   : integer      -- System clock frequency in MHz
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

      -- Trigger to indicate a key was pressed (single clock cycle pulse)
      O_KEYPRESSED     : out std_logic
    );
    end component keypad_5x4_wrapper;

  ---------------
  -- Constants --
  ---------------

  constant C_CLK_FREQ_MHZ : integer := 50;                  -- System clock frequency in MHz

  -------------
  -- SIGNALS --
  -------------

  signal s_keypad_data    : std_logic_vector(4 downto 0);   -- Data from keypress
  signal s_keypressed     : std_logic;                      -- Whether a key was pressed
  signal s_display_enable : std_logic;                      -- Display's enable control
  signal s_data_shift_reg : std_logic_vector(15 downto 0);  -- Data to display
  signal s_addr_shift_reg : std_logic_vector(7 downto 0);   -- Address to display
  signal s_addr_data_mode : std_logic;                      -- Signal to hold current entry mode (address = 1, data = 0)

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
    I_DATA_BITS      => s_data_shift_reg,
    I_ADDR_BITS      => s_addr_shift_reg,
    O_HEX0_N         => O_HEX0_N,
    O_HEX1_N         => O_HEX1_N,
    O_HEX2_N         => O_HEX2_N,
    O_HEX3_N         => O_HEX3_N,
    O_HEX4_N         => O_HEX4_N,
    O_HEX5_N         => O_HEX5_N
  );

  -- Device driver for keypad
  matrix_keypad_driver: keypad_5x4_wrapper
  generic map
  (
    C_CLK_FREQ_MHZ   => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK,
    I_RESET_N        => I_RESET_N,
    I_KEYPAD_ROWS    => I_KEYPAD_ROWS,
    O_KEYPAD_COLS    => O_KEYPAD_COLS,
    O_KEYPAD_DATA    => s_keypad_data,
    O_KEYPRESSED     => s_keypressed
  );

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_SHIFT_REGISTER
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   :
  --                    s_display_enable : Digit enable for display
  -- Description      : A process add data from
  ------------------------------------------------------------------------------
  KEYPAD_SHIFT_REGISTER: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_display_enable                  <= '0';
      s_addr_data_mode                  <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Enable (turn on) the display
      s_display_enable                  <= '1';

      -- Toggle selected register
      if (s_keypressed = '1' and s_keypad_data = "10001") then -- H key pressed
        s_addr_data_mode                <= not s_addr_data_mode;
      else
        s_addr_data_mode                <= s_addr_data_mode;
      end if;

      -- Add data to register
      if (s_keypressed = '1' and s_keypad_data /= "10001") then -- Data (0-F) key pressed
        if (s_addr_data_mode = '1') then -- Address mode
          s_addr_shift_reg(7 downto 4)  <= s_addr_shift_reg(3 downto 0);
          s_addr_shift_reg(3 downto 0)  <= s_keypad_data(3 downto 0);
        else                             -- Data mode
          s_data_shift_reg(15 downto 4) <= s_data_shift_reg(11 downto 0);
          s_data_shift_reg(3 downto 0)  <= s_data_shift_reg(3 downto 0);
        end if;
      else
        s_addr_shift_reg                <= s_addr_shift_reg;
        s_data_shift_reg                <= s_data_shift_reg;
      end if;
    end if;
  end process KEYPAD_SHIFT_REGISTER;
  ------------------------------------------------------------------------------

end architecture behavioral;
