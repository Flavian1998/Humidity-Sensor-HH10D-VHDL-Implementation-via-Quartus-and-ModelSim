library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
 
entity UP_COUNTER is
-- We set the same clock than in M_I2C and implement a counter wich returns the value 
-- in time of the humidity sensor (we must change it into frequency and after into humidity level)
  generic(
    input_clk : integer := 50;			--input clock speed from user logic in KHz
    bus_clk   : integer := 400;		   --speed the I2C_M bus (scl) will run at in MHz
	 input_clk_multiplier : integer := 1_000_000;			
    bus_clk_multiplier   : integer := 1_000);


    Port ( clk: in std_logic; -- clock input
           reset: in std_logic; -- reset input 
           counter: out std_logic_vector(7 downto 0) -- output 8-bit counter
	   data_rd   : out    std_logic_vector(7 downto 0); --data read from slave
     );
end UP_COUNTER;

architecture Behavioral of UP_COUNTER is
signal counter_up: std_logic_vector(7 downto 0);
begin
-- up counter
process(clk)
begin
if(rising_edge(clk)) then
    if(reset='1') then   			     -- we reset counter after using
         counter_up <= x"0";
    else
        counter_up <= counter_up + x"1";
    end if;
 end if;
end process;
 counter <= counter_up;

-- We must change time counter into frequency and then humidity level

===> Code in C

end Behavioral;