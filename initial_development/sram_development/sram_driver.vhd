--------------------------------------------------------------------------------
-- Filename     : sram_driver.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Entity       : sram_driver
-- Description  : Driver code to control SRAM to store and recall data
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
entity sram_driver is
generic
(
  C_CLK_FREQ_MHZ    : integer := 50  -- System clock frequency in MHz
);
port
(
  I_CLK             : in std_logic; -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N         : in std_logic; -- System reset (active low)

  I_SRAM_ENABLE     : in std_logic;
  I_COMMAND_TRIGGER : in std_logic;
  I_RW              : in std_logic;
  I_ADDRESS         : in std_logic_vector(17 downto 0);
  I_DATA            : in std_logic_vector(15 downto 0);
  O_BUSY            : out std_logic;
  O_DATA            : out std_logic_vector(15 downto 0);

  -- Low level pass through signals
  IO_SRAM_DATA      : inout std_logic_vector(15 downto 0);
  O_SRAM_ADDR       : out std_logic_vector(17 downto 0);
  O_SRAM_WE_N       : out std_logic;
  O_SRAM_OE_N       : out std_logic;
  O_SRAM_UB_N       : out std_logic;
  O_SRAM_LB_N       : out std_logic;
  O_SRAM_CE_N       : out std_logic
);
end entity sram_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of sram_driver is

  -------------
  -- SIGNALS --
  -------------

  -- State machine related signals
  type t_SRAM_STATE is (INIT_STATE,    IDLE_STATE,
                        READ_1_STATE,  READ_2_STATE,
                        WRITE_1_STATE, WRITE_2_STATE);
  signal s_sram_previous_state : t_SRAM_STATE := INIT_STATE;
  signal s_sram_current_state  : t_SRAM_STATE := INIT_STATE;

  signal s_data_write_en       : std_logic := '0';               -- Enable signal for tristate
  signal s_data_out            : std_logic_vector(15 downto 0);  -- Output read data

begin

  ------------------------------------------------------------------------------
  -- Process Name     : SRAM_STATE_MACHINE
  -- Sensitivity List : I_CLK                 : System clock
  --                    I_RESET_N             : System reset (active low logic)
  -- Useful Outputs   : s_sram_previous_state : Previous state of the sram
  --                    s_sram_current_state  : Current state of the sram
  --                    O_BUSY                : Busy signal for sram system
  -- Description      : State machine to control different states for a sram
  --                    read or write operation.
  ------------------------------------------------------------------------------
  SRAM_STATE_MACHINE: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_sram_previous_state          <= INIT_STATE;
      s_sram_current_state           <= INIT_STATE;
      O_BUSY                         <= '1';

    elsif (rising_edge(I_CLK)) then

      -- Busy signal logic
      if (s_sram_current_state = IDLE_STATE) then
        O_BUSY                       <= '0';
      else
        O_BUSY                       <= '1';
      end if;

      -- Ensure sram module is enabled
      if (I_SRAM_ENABLE = '0') then
        s_sram_previous_state        <= INIT_STATE;
        s_sram_current_state         <= INIT_STATE;
      else
        -- Store previous state for use in detecting state "changes"
        s_sram_previous_state        <= s_sram_current_state;

        -- SRAM state machine logic
        case s_sram_current_state is

          when INIT_STATE =>
            s_sram_current_state     <= IDLE_STATE;

          when IDLE_STATE =>
            if (I_COMMAND_TRIGGER = '1') then
              if (I_RW = '1') then  -- Read
                s_sram_current_state <= READ_1_STATE;
              else
                s_sram_current_state <= WRITE_1_STATE;
              end if;
            else
              s_sram_current_state   <= s_sram_current_state;
            end if;

          when READ_1_STATE =>
            s_sram_current_state     <= READ_2_STATE;

          when READ_2_STATE =>
            s_sram_current_state     <= IDLE_STATE;

          when WRITE_1_STATE =>
            s_sram_current_state     <= WRITE_2_STATE;

          when WRITE_2_STATE =>
            s_sram_current_state     <= IDLE_STATE;

          -- Error condition, should never occur
          when others =>
            s_sram_previous_state    <= INIT_STATE;
            s_sram_current_state     <= INIT_STATE;
        end case;
      end if;
    end if;
  end process SRAM_STATE_MACHINE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Process Name     : SRAM_DATA_FLOW
  -- Sensitivity List : I_CLK           : System clock
  --                    I_RESET_N       : System reset (active low logic)
  -- Useful Outputs   : s_data_out      : Output read data
  --                    s_data_write_en : Tristate data flow control (write = '1')
  --                    O_SRAM_WE_N     : SRAM write enable (active low logic)
  --                    O_SRAM_OE_N     : SRAM output enable (active low logic)
  -- Description      : Control the flow of internal and external sram signals
  --                    based on current state of system.
  ------------------------------------------------------------------------------
  SRAM_DATA_FLOW: process (I_CLK, I_RESET_N)
  begin
    if (I_RESET_N = '0') then
      s_data_out          <= (others=>'0');
      s_data_write_en     <= '0';
      O_SRAM_WE_N         <= '1';
      O_SRAM_OE_N         <= '1';

    elsif (rising_edge(I_CLK)) then

      -- SRAM control of data flow
      case s_sram_current_state is

        when INIT_STATE =>
          s_data_out      <= (others=>'0');
          s_data_write_en <= '0';
          O_SRAM_WE_N     <= '1';
          O_SRAM_OE_N     <= '1';

        when IDLE_STATE =>
          s_data_out      <= s_data_out;
          s_data_write_en <= '0';
          O_SRAM_WE_N     <= '1';
          O_SRAM_OE_N     <= '1';

        when READ_1_STATE =>
          s_data_out      <= s_data_out;
          s_data_write_en <= '0';
          O_SRAM_WE_N     <= '1';
          O_SRAM_OE_N     <= '0';

        when READ_2_STATE =>
          s_data_out      <= IO_SRAM_DATA;
          s_data_write_en <= '0';
          O_SRAM_WE_N     <= '1';
          O_SRAM_OE_N     <= '0';

        when WRITE_1_STATE =>
          s_data_out      <= s_data_out;
          s_data_write_en <= '1';
          O_SRAM_WE_N     <= '0';
          O_SRAM_OE_N     <= '1';

        when WRITE_2_STATE =>
          s_data_out      <= s_data_out;
          s_data_write_en <= '1';
          O_SRAM_WE_N     <= '0';
          O_SRAM_OE_N     <= '1';

        -- Error condition, should never occur
        when others =>
          s_data_out      <= (others=>'0');
          s_data_write_en <= '0';
          O_SRAM_WE_N     <= '1';
          O_SRAM_OE_N     <= '1';
      end case;
    end if;
  end process SRAM_DATA_FLOW;
  ------------------------------------------------------------------------------

  O_SRAM_CE_N  <= not I_SRAM_ENABLE;
  O_SRAM_ADDR  <= I_ADDRESS;
  IO_SRAM_DATA <= I_DATA when s_data_write_en = '1' else (others=>'Z');
  O_SRAM_UB_N  <= '0';
  O_SRAM_LB_N  <= '0';
  O_DATA       <= s_data_out;

end architecture behavioral;