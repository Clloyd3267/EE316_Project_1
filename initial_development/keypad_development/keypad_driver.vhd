--------------------------------------------------------------------------------
-- Filename     : keypad_driver.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : keypad_driver
-- Description  : Driver code to return a binary representation of the output
--                of a NxM button keypad.
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
entity keypad_driver is
generic
(
  C_CLK_FREQ_MHZ   : integer     := 50;      -- System clock frequency in MHz
  C_STABLE_TIME_MS : integer     := 10;      -- Time required for button to remain stable in ms
  C_SCAN_TIME_US   : integer     := 2;       -- Time required for column power to fully settle in us
  C_TRIGGER_EDGE   : T_EDGE_TYPE := RISING;  -- Edge to trigger on

  -- Dimensions of matrix keypad
  C_NUM_ROWS       : integer     := 4;
  C_NUM_COLS       : integer     := 4
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
end entity keypad_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of keypad_driver is

  ----------------
  -- Components --
  ----------------
  component debounce_button is
  generic
  (
    C_CLK_FREQ_MHZ   : integer;       -- System clock frequency in MHz
    C_STABLE_TIME_MS : integer        -- Time required for button to remain stable in ms
  );
  port
  (
    I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;  -- System reset (active low)
    I_BUTTON         : in std_logic;  -- Button data to be debounced
    O_BUTTON         : out std_logic  -- Debounced button data
  );
  end component debounce_button;

  component edge_detector is
  generic
  (
    C_CLK_FREQ_MHZ   : integer;       -- System clock frequency in MHz
    C_TRIGGER_EDGE   : T_EDGE_TYPE    -- Edge to trigger on
  );
  port
  (
    I_CLK            : in std_logic;  -- System clk frequency of (C_CLK_FREQ_MHZ)
    I_RESET_N        : in std_logic;  -- System reset (active low)
    I_SIGNAL         : in std_logic;  -- Input signal to pass through edge detector
    O_EDGE_SIGNAL    : out std_logic  -- Output pulse on (C_TRIGGER_EDGE) edge
  );
  end component edge_detector;

  -------------
  -- SIGNALS --
  -------------

  -- Keypad scan column toggle to account for delay time powering columns
  signal s_scan_toggle             : std_logic := '0';

  -- State machine related signals
  type t_STATE is (IDLE_STATE, COL_POWER_STATE, COL_READ_STATE);
  signal s_keypad_state            : t_STATE := IDLE_STATE;

  -- Column index counter
  signal s_col_index_counter       : integer range 0 TO (C_NUM_COLS-1) := 0;

  -- Signals to allow current state of columns to be read as well as written to
  signal s_keypad_cols             : std_logic_vector((C_NUM_COLS-1) downto 0);

  -- Binary representation of keypad state (undebounced)
  signal s_keypad_binary_inital    : std_logic_vector(((C_NUM_ROWS * C_NUM_COLS)-1) downto 0);

  -- Binary representation of keypad state (debounced)
  signal s_keypad_binary_debounced : std_logic_vector(((C_NUM_ROWS * C_NUM_COLS)-1) downto 0);

  -- Binary representation of keypad state (edge detection)
  signal s_keypad_binary_edge      : std_logic_vector(((C_NUM_ROWS * C_NUM_COLS)-1) downto 0);

begin

  -- Debounce keypad outputs
  keypad_debounce: for i in 0 to ((C_NUM_ROWS * C_NUM_COLS)-1) generate
    debounce_keys: debounce_button
      generic map
      (
        C_CLK_FREQ_MHZ   => C_CLK_FREQ_MHZ,
        C_STABLE_TIME_MS => C_STABLE_TIME_MS
      )
      port map
      (
        I_CLK            => I_CLK,
        I_RESET_N        => I_RESET_N,
        I_BUTTON         => s_keypad_binary_inital(i),
        O_BUTTON         => s_keypad_binary_debounced(i)
      );
  end generate keypad_debounce;

  -- Capture edges for keypad outputs
  keypad_edge_detection: for i in 0 to ((C_NUM_ROWS * C_NUM_COLS)-1) generate
    edge_detect_keys: edge_detector
      generic map
      (
        C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ,
        C_TRIGGER_EDGE => C_TRIGGER_EDGE
      )
      port map
      (
        I_CLK          => I_CLK,
        I_RESET_N      => I_RESET_N,
        I_SIGNAL       => s_keypad_binary_debounced(i),
        O_EDGE_SIGNAL  => s_keypad_binary_edge(i)
      );
  end generate keypad_edge_detection;

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_EN_CNTR
  -- Sensitivity List : I_CLK           : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : s_scan_toggle   : Enable line to allow state to change
  --                                      in KEYPAD_STATE_MACHINE process
  --                                      (active high enable logic)
  -- Description      : Counter to delay the powering of the columns to negate
  --                    the delay of the Hardware. Every (C_SCAN_TIME_US) us,
  --                    s_scan_toggle gets driven high to allow for state
  --                    change in KEYPAD_STATE_MACHINE process.
  ------------------------------------------------------------------------------
  KEYPAD_EN_CNTR: process (I_CLK, I_RESET_N)
    variable v_keypad_en_max_count : integer := C_CLK_FREQ_MHZ * C_SCAN_TIME_US;
    variable v_keypad_en_counter   : integer range 0 TO v_keypad_en_max_count := 0;
  begin
    if (I_RESET_N = '0') then
      v_keypad_en_counter   :=  0;
      s_scan_toggle         <= '0';

    elsif (rising_edge(I_CLK)) then
      -- Only send enable signal on max count
      if (v_keypad_en_counter = v_keypad_en_max_count) then
        s_scan_toggle       <= '1';
      else
        s_scan_toggle       <= '0';
      end if;

      -- Counter logic
      if (v_keypad_en_counter = v_keypad_en_max_count) then
        v_keypad_en_counter :=  0;
      else
        v_keypad_en_counter := v_keypad_en_counter + 1;
      end if;
    end if;
  end process KEYPAD_EN_CNTR;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_STATE_MACHINE
  -- Sensitivity List : I_CLK               : System clock
  --                    I_RESET_N           : System reset (active low logic)
  -- Useful Outputs   : s_keypad_state      : Current state of keypad state machine
  --                    s_col_index_counter : Index of current column
  -- Description      : State machine to control different states for power and
  --                    and read of cols.
  ------------------------------------------------------------------------------
  KEYPAD_STATE_MACHINE: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_keypad_state      <= IDLE_STATE;
      s_col_index_counter <= 0;

    elsif (rising_edge(I_CLK)) then
      -- Ensure keypad module is enabled
      if (I_KEYPAD_ENABLE = '0') then
        s_keypad_state      <= IDLE_STATE;
        s_col_index_counter <= 0;
      else
        -- Column state machine logic
        if (s_scan_toggle = '1') then
          case s_keypad_state is
            when IDLE_STATE =>
                s_keypad_state <= COL_POWER_STATE;

            when COL_POWER_STATE =>
                s_keypad_state <= COL_READ_STATE;

            when COL_READ_STATE  =>
                s_keypad_state <= COL_POWER_STATE;

                -- Counter logic to increment column
                if (s_col_index_counter = (C_NUM_COLS-1)) then
                  s_col_index_counter <= 0;
                else
                  s_col_index_counter <= s_col_index_counter + 1;
                end if;

            -- Error condition, should never occur
            when others          =>
              s_keypad_state      <= IDLE_STATE;
              s_col_index_counter <= 0;
          end case;
        else
          s_keypad_state      <= s_keypad_state;
          s_col_index_counter <= s_col_index_counter;
        end if;
      end if;
    end if;
  end process KEYPAD_STATE_MACHINE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : KEYPAD_TO_BINARY
  -- Sensitivity List : I_CLK                  : System clock
  --                    I_RESET_N              : System reset (active low logic)
  -- Useful Outputs   : s_keypad_binary_inital : Binary representation of raw keypad state
  -- Description      : Entity to control the powering and reading of the
  --                    keypad columns and rows based on the current s_keypad_state.
  --                    Outputs the current binary number of keypad (0-15)
  ------------------------------------------------------------------------------
  KEYPAD_TO_BINARY: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_keypad_cols          <= (others=>'0');
      s_keypad_binary_inital <= (others=>'0');

    elsif ((rising_edge(I_CLK))) then

      -- Power the columns
      if (s_keypad_state = COL_POWER_STATE) then
        -- Only power current column
        s_keypad_cols                      <= (others=>'0');
        s_keypad_cols(s_col_index_counter) <= '1';
      else
        s_keypad_cols                      <= s_keypad_cols;
      end if;

      -- Read row state
      if (s_keypad_state = COL_READ_STATE) then
        for row in 0 to (C_NUM_ROWS-1) loop
          -- Set input of (R, C) to output (index) (2D -> 1D)
          s_keypad_binary_inital(4*row + s_col_index_counter) <= I_KEYPAD_ROWS(row);
        end loop;
      else
        s_keypad_binary_inital <= s_keypad_binary_inital;
      end if;
    end if;
  end process KEYPAD_TO_BINARY;
  ------------------------------------------------------------------------------

  -- Assign final outputs
  O_KEYPAD_COLS   <= s_keypad_cols;
  O_KEYPAD_BINARY <= s_keypad_binary_edge;

end architecture behavioral;