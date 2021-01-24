--------------------------------------------------------------------------------
-- Filename     : memory_control_top.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : memory_control_top
-- Description  : Multi Mode memory control system which loads default data from
--                ROM and stores it in SRAM. The data withing SRAM can be
--                altered (Program Mode) and displayed in a rotating fashion
--                (operation mode).
--------------------------------------------------------------------------------

-- Package for SRAM replacement data buffer --CDL=> Replace with SRAM
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.Numeric_std.all;
package buffer_util is
  type t_data_buffer is array (255 downto 0) of std_logic_vector(15 downto 0);
end package buffer_util;

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.buffer_util.all;

--------------
--  Entity  --
--------------
entity memory_control_top is
port
(
  I_CLK_50_MHZ   : in std_logic;                      -- System clk (50 MHZ)
  I_RESET_N      : in std_logic;                      -- System reset (active low)
  I_KEYPAD_ROWS  : in std_logic_vector(4 downto 0);   -- Keypad Inputs (rows)
  O_KEYPAD_COLS  : out std_logic_vector(3 downto 0);  -- Keypad Outputs (cols)
  O_HEX0_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 0
  O_HEX1_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 1
  O_HEX2_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 2
  O_HEX3_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 3
  O_HEX4_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 4
  O_HEX5_N       : out std_logic_vector(6 downto 0);  -- Segment data for seven segment display 5
  O_MODE_LED     : out std_logic                      -- LED to display current mode: On (OP) else Off
);
end entity memory_control_top;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of memory_control_top is

  ----------------
  -- Components --
  ----------------
  component de2_display_driver is
  generic
  (
    C_CLK_FREQ_MHZ   : integer                            -- System clock frequency in MHz
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
    C_CLK_FREQ_MHZ   : integer                            -- System clock frequency in MHz
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

  component rom_driver is
  port
  (
    address		       : in std_logic_vector(7 downto 0);
    clock		         : in std_logic;
    q		             : out std_logic_vector(15 downto 0)
  );
  end component rom_driver;

  ---------------
  -- Constants --
  ---------------

  -- System clock frequency in MHz
  constant C_CLK_FREQ_MHZ       : integer := 50;

  -- Max address of SRAM and ROM (255)
  constant C_MAX_ADDRESS        : unsigned(7 downto 0) := to_unsigned(255, 8);

  -------------
  -- SIGNALS --
  -------------

  -- Signal to toggle (increment/decrement) address
  signal s_address_toggle       : std_logic := '0';

  -- Current counter address
  signal s_current_address      : unsigned(7 downto 0) := (others=>'0');

  -- Direction and enabling control of address counter
  signal s_address_cntr_enabled : std_logic := '0';
  signal s_address_cntr_forward : std_logic := '0';

  -- Mode state machine signals
  type t_MODE_STATE is (INIT_STATE, OP_STATE, PROG_STATE);
  signal s_current_mode         : t_MODE_STATE := INIT_STATE;
  signal s_previous_mode        : t_MODE_STATE := INIT_STATE;

  -- Address/data shift registers and control for data input from keypad
  signal s_addr_data_mode       : std_logic := '0';
  signal s_data_shift_reg       : std_logic_vector(15 downto 0) := (others=>'0');
  signal s_addr_shift_reg       : unsigned(7 downto 0)          := (others=>'0');

  -- Display enable
  signal s_display_enable       : std_logic := '0';
  -- Global address for ROM, Display, and SRAM
  signal s_addr_bits            : std_logic_vector(7 downto 0)  := (others=>'0');
  -- Data going to display
  signal s_display_data_bits    : std_logic_vector(15 downto 0) := (others=>'0');
  -- Data buffer as a temporary replacement for SRAM
  signal s_data_buffer          : t_data_buffer                 := (others=>(others=>('0')));

  -- Data from ROM memory
  signal s_rom_data_bits        : std_logic_vector(15 downto 0);

  -- Data from keypress
  signal s_keypad_data          : std_logic_vector(4 downto 0);
  -- Whether a key was pressed
  signal s_keypressed           : std_logic;

begin

  -- Display controller to display data and address
  DISPLAY_CONTROLLER: de2_display_driver
  generic map
  (
    C_CLK_FREQ_MHZ => C_CLK_FREQ_MHZ
  )
  port map
  (
    I_CLK            => I_CLK_50_MHZ,
    I_RESET_N        => I_RESET_N,
    I_DISPLAY_ENABLE => s_display_enable,
    I_DATA_BITS      => s_display_data_bits,
    I_ADDR_BITS      => s_addr_bits,
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
    I_CLK            => I_CLK_50_MHZ,
    I_RESET_N        => I_RESET_N,
    I_KEYPAD_ROWS    => I_KEYPAD_ROWS,
    O_KEYPAD_COLS    => O_KEYPAD_COLS,
    O_KEYPAD_DATA    => s_keypad_data,
    O_KEYPRESSED     => s_keypressed
  );

  -- Rom controller to get data from read only memory
  ROM_CONTROLLER: rom_driver
  port map
  (
    address          => s_addr_bits,
	  clock            => I_CLK_50_MHZ,
	  q                => s_rom_data_bits
  );

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_TOGGLE_COUNTER
  -- Sensitivity List : I_CLK_50_MHZ     : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_address_toggle : Pulsed signal to toggle address
  -- Description      : Counter to delay changing address at a rate of either
  --                    255Hz (INIT_STATE) or 1Hz (OP_STATE).
  ------------------------------------------------------------------------------
  ADDRESS_TOGGLE_COUNTER: process (I_CLK_50_MHZ, I_RESET_N)
    constant C_1HZ_MAX_COUNT       : integer := C_CLK_FREQ_MHZ * 1000000;
    constant C_255HZ_MAX_COUNT     : integer := C_CLK_FREQ_MHZ * 4000;
    variable v_address_toggle_cntr : integer range 0 TO C_1HZ_MAX_COUNT := 0;
  begin
    if (I_RESET_N = '0') then
      v_address_toggle_cntr     :=  0;
      s_address_toggle          <= '0';

    elsif (rising_edge(I_CLK_50_MHZ)) then

      -- Only count if enabled
      if (s_address_cntr_enabled = '0') then
        v_address_toggle_cntr   :=  0;
        s_address_toggle        <= '0';

      else
        -- Address index output logic (Create toggle pulse on max count)
        if (s_current_mode = INIT_STATE and v_address_toggle_cntr = C_255HZ_MAX_COUNT) or
           (s_current_mode = OP_STATE and v_address_toggle_cntr = C_1HZ_MAX_COUNT) then
          s_address_toggle      <= '1';
        else
          s_address_toggle      <= '0';
        end if;

        -- Counter and rollover logic
        if (s_current_mode = INIT_STATE and v_address_toggle_cntr = C_255HZ_MAX_COUNT) or
           (s_current_mode = OP_STATE and v_address_toggle_cntr = C_1HZ_MAX_COUNT) then
          v_address_toggle_cntr := 0;
        else
          v_address_toggle_cntr := v_address_toggle_cntr + 1;
        end if;
      end if;
    end if;
  end process ADDRESS_TOGGLE_COUNTER;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_INDEX_COUNTER
  -- Sensitivity List : I_CLK_50_MHZ      : System clock
  --                    I_RESET_N         : System reset (active low logic)
  -- Useful Outputs   : s_current_address : Current address of counter
  -- Description      : A process to adjust address depending on mode.
  ------------------------------------------------------------------------------
  ADDRESS_INDEX_COUNTER: process (I_CLK_50_MHZ, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_current_address     <= (others=>'0');

    elsif (rising_edge(I_CLK_50_MHZ)) then

      -- Reset address to zero when exiting programming state
      if (s_current_mode = OP_STATE) and
         (s_previous_mode = PROG_STATE) then
        s_current_address   <= (others=>'0');

      -- Increment address when toggle signal occurs and direction is forward
      elsif (s_address_toggle = '1') and
            (s_address_cntr_forward = '1') then
          s_current_address <= s_current_address + 1;

      -- Decrement address when toggle signal occurs and direction is reverse
      elsif (s_address_toggle = '1') and
            (s_address_cntr_forward = '0') then
          s_current_address <= s_current_address - 1;

      else
        s_current_address   <= s_current_address;
      end if;
    end if;
  end process ADDRESS_INDEX_COUNTER;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : ADDRESS_COUNTER_CONTROL
  -- Sensitivity List : I_CLK_50_MHZ           : System clock
  --                    I_RESET_N              : System reset (active low logic)
  -- Useful Outputs   : s_address_cntr_enabled : Whether the address counter
  --                                             is enabled
  --                    s_address_cntr_forward : Whether the counter is counting
  --                                             forward '1' or backwards '0'
  -- Description      : A process to control address counter enable and
  --                    direction signals
  ------------------------------------------------------------------------------
  ADDRESS_COUNTER_CONTROL: process (I_CLK_50_MHZ, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_address_cntr_enabled   <= '1';
      s_address_cntr_forward   <= '1';

    elsif (rising_edge(I_CLK_50_MHZ)) then
      -- Reset address to zero when exiting programming state
      if (s_current_mode = OP_STATE) and
         (s_previous_mode = PROG_STATE) then
        s_address_cntr_enabled <= '0';

      -- Enable (turn on) the address counter if H key pressed in OP mode
      elsif (s_current_mode = OP_STATE) and
         (s_keypressed = '1' and s_keypad_data = "10001") then -- H key pressed
        s_address_cntr_enabled <= not s_address_cntr_enabled;
      else
        s_address_cntr_enabled <= s_address_cntr_enabled;
      end if;

      -- CDL=> Should direction be reset to forward when going from OP state to prog state?
      -- Control direction of counter depending on mode
      if (s_current_mode = OP_STATE) and
         (s_keypressed = '1' and s_keypad_data = "10010") then -- L key pressed
        s_address_cntr_forward <= not s_address_cntr_forward;
      else
        s_address_cntr_forward <= s_address_cntr_forward;
      end if;
    end if;
  end process ADDRESS_COUNTER_CONTROL;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : MODE_STATE_MACHINE
  -- Sensitivity List : I_CLK_50_MHZ    : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : s_current_mode  : Current mode of the system
  --                    s_previous_mode : Mode of system last clock edge
  -- Description      : State machine to control different modes for
  --                    initialization, programming, and operation of system.
  ------------------------------------------------------------------------------
  MODE_STATE_MACHINE: process (I_CLK_50_MHZ, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_current_mode     <= INIT_STATE;
      s_previous_mode    <= INIT_STATE;

    elsif (rising_edge(I_CLK_50_MHZ)) then

      -- Initialization mode
      if (s_current_mode = INIT_STATE) then
        -- Wait for ROM data to be loaded into SRAM
        if (s_current_address = C_MAX_ADDRESS) and
           (s_address_toggle = '1') then
          s_current_mode <= OP_STATE;
        else
          s_current_mode <= s_current_mode;
        end if;

      -- Operational mode
      elsif (s_current_mode = OP_STATE) then
       -- Change mode when Shift key pressed
        if (s_keypressed = '1' and s_keypad_data = "10000") then
          s_current_mode <= PROG_STATE;
        else
          s_current_mode <= s_current_mode;
        end if;

      -- Programming mode
      elsif (s_current_mode = PROG_STATE) then
       -- Change mode when Shift key pressed
        if (s_keypressed = '1' and s_keypad_data = "10000") then
          s_current_mode <= OP_STATE;
        else
          s_current_mode <= s_current_mode;
        end if;

      -- Error condition, should never occur
      else
        s_current_mode   <= INIT_STATE;
      end if;

      -- Store previous mode for use in detecting mode "changes"
      s_previous_mode    <= s_current_mode;

    end if;
  end process MODE_STATE_MACHINE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : INPUT_SHIFT_REGISTER
  -- Sensitivity List : I_CLK_50_MHZ     : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : s_data_shift_reg : Shift register for inputted data
  --                    s_addr_shift_reg : Shift register for inputted address
  -- Description      : A process to control inputted data from the keypad.
  ------------------------------------------------------------------------------
  INPUT_SHIFT_REGISTER: process (I_CLK_50_MHZ, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_addr_data_mode                    <= '0';
		  s_data_shift_reg                    <= (others=>'0');
		  s_addr_shift_reg                    <= (others=>'0');

    elsif (rising_edge(I_CLK_50_MHZ)) then
      if (s_current_mode = PROG_STATE) then
        -- Toggle selected register
        if (s_keypressed = '1' and s_keypad_data = "10001") then -- H key pressed
          s_addr_data_mode                <= not s_addr_data_mode;
        else
          s_addr_data_mode                <= s_addr_data_mode;
        end if;

        -- Add (data/addr) to shift registers when 0-F is pressed
        if (s_keypressed = '1' and s_keypad_data(4) /= '1') then
          if (s_addr_data_mode = '1') then  -- Data mode
            s_data_shift_reg(15 downto 4) <= s_data_shift_reg(11 downto 0);
            s_data_shift_reg(3 downto 0)  <= s_keypad_data(3 downto 0);
          else                              -- Address mode
            s_addr_shift_reg(7 downto 4)  <= s_addr_shift_reg(3 downto 0);
            s_addr_shift_reg(3 downto 0)  <= unsigned(s_keypad_data(3 downto 0));
          end if;
        else
          s_data_shift_reg                <= s_data_shift_reg;
          s_addr_shift_reg                <= s_addr_shift_reg;
        end if;
      else
        s_addr_data_mode                  <= s_addr_data_mode;
        s_data_shift_reg                  <= s_data_shift_reg;
        s_addr_shift_reg                  <= s_addr_shift_reg;
      end if;
    end if;
  end process INPUT_SHIFT_REGISTER;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : DATA_FLOW_CONTROL
  -- Sensitivity List : I_CLK_50_MHZ        : System clock
  --                    I_RESET_N           : System reset (active low logic)
  -- Useful Outputs   : s_display_enable    : Digit enable for display
  --                    s_addr_bits         : Global address
  --                    s_display_data_bits : Data going to display
  --                    s_data_buffer       : Data buffer as a drop in for SRAM
  -- Description      : A process to control the flow of data goes depending
  --                    on mode.
  ------------------------------------------------------------------------------
  DATA_FLOW_CONTROL: process (I_CLK_50_MHZ, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_display_enable      <= '0';
      s_addr_bits           <= (others=>'0');
      s_display_data_bits   <= (others=>'0');
      s_data_buffer         <= (others=>(others=>('0')));

    elsif (rising_edge(I_CLK_50_MHZ)) then
      -- Enable (turn on) the display depending on mode
      if (s_current_mode = INIT_STATE) then
        s_display_enable    <= '0';
      else
        s_display_enable    <= '1';
      end if;

      -- Control address and data routing
      if (s_current_mode = OP_STATE or s_current_mode = INIT_STATE) then
        s_addr_bits         <= std_logic_vector(s_current_address);
        s_display_data_bits <= s_data_buffer(to_integer(s_current_address));
      else
        s_addr_bits         <= std_logic_vector(s_addr_shift_reg);
        s_display_data_bits <= s_data_shift_reg;
      end if;

      -- Get SRAM data from ROM when in init mode
      if (s_current_mode = INIT_STATE) then
        s_data_buffer(to_integer(s_current_address)) <= s_rom_data_bits;

      -- Get SRAM data from shift registers when in programming mode and
      -- load key (L) is pressed
      elsif (s_current_mode = PROG_STATE) and
            (s_keypressed = '1' and s_keypad_data = "10010") then -- L key pressed
        s_data_buffer       <= s_data_buffer;
		    s_data_buffer(to_integer(s_addr_shift_reg)) <= s_data_shift_reg;
      else
        s_data_buffer       <= s_data_buffer;
      end if;
    end if;
  end process DATA_FLOW_CONTROL;
  ------------------------------------------------------------------------------

  -- Selection for mode LED
  with s_current_mode select
    O_MODE_LED <= '1' when OP_STATE,
                  '0' when others;

end architecture behavioral;
