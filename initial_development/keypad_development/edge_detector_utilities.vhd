--------------------------------------------------------------------------------
-- Filename     : edge_detector_utilities.vhd
-- Author(s)    : Chris Lloyd
-- Class        : EE316 (Project 1)
-- Due Date     : 2021-01-28
-- Target Board : Altera DE2 Devkit
-- Package      : edge_detector_utilities
-- Description  : Defines useful types for edge_detector.
--------------------------------------------------------------------------------

-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

---------------
--  Package  --
---------------
package edge_detector_utilities is
  type T_EDGE_TYPE is (RISING, FALLING, EITHER, NONE);
end package edge_detector_utilities;