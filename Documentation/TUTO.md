# Introduction #
The main goal of the project is to read datas of a HH10D humidity sensor and transforms it into a humidity rate understable by everyone. To make you understand all our steps to arrive at this objective, we will discuss in this tuto about on our way of thinking and our comprehension of the subject. Follow us !

# Humidity sensor HH10D #

We will start by discovering the sensor and its different outputs.

![image](https://user-images.githubusercontent.com/82948794/121933034-d4b4fa80-cd45-11eb-90df-b36d201fbf00.png)

The HH10D humidity sensor is constitued by 3 physical outputs : 

- Fout : this output gives us a signal that we have to treat to extract a frequency we will need to compile humidity rate (RH%)
- SDA : the 2 datas that we have to extract will be by this bus : sensitivity and offset that are also needed to find RH% and we will read them with the I2C protocol.
- SCL : concerns the main clock of the system in an I2C protocol

All explanations about I2C protocol needed in the project are in this link : https://forum.digikey.com/t/i2c-master-vhdl/12797. It explains you the Master/Slave communication via I2C work and you will understand more it by look at our I2C_M in the section "State Machine". That describes all the same steps that is shown in the link.

The Fout output give us a square signal of a frequency we doesn't know but wich is includes in [5000 Hz;7500 Hz] (it is the ref signal) as we can see in the datasheet of the sensor [HH10](Documentation/HH10D.pdf). To determine this frequency in VHDL, we have to compare it with a very high frequency we choose (here 1 MHz, the test signal) . The goal of this counter is to determine how much times of the high frequency has a rising edge during a period of the frequency we search. This researched value is the output of our counter.

![image](https://user-images.githubusercontent.com/82948794/122133352-d3b2c480-ce3c-11eb-96df-1f6bae6dde47.png)

# Implementation in VHDL and C #
## Schematic of the project ##

![image](https://user-images.githubusercontent.com/82948794/122134408-ce567980-ce3e-11eb-8029-2d97a2aa38a5.png)


From that schematic, we will implement first the counter called "cmpt.vhd" that will return a value (counter) we will use later in the .C code named "codeC.c" 

The formula we have to implement in the end is (also given in datasheet) :

![image](https://user-images.githubusercontent.com/82948794/122189819-8ad92b00-ce91-11eb-9310-c5823cb3dca6.png)


## cmpt ##

As we have seen in the draw above, we have to use a high frequency clock of 1 MHz that will give us enough precision. But the basis clock is not at 1 MHz, so we have to divise the clock of the FPGA of 50 MHz into a clock of 1 MHz. We do that with a clock divider we can see in in our "cmpt.vhd" file.

```
-- Clock divider 50MHz to 1 MHz

entity Clock_Divider is
port ( clk,reset: in std_logic;
i_clock_test: out std_logic);
end Clock_Divider;

architecture bhv of Clock_Divider is

signal count: integer:=1;
signal tmp : std_logic := '0';

begin

process(clk,reset)
begin
if(reset='1') then
count<=1;
tmp<='0';
elsif(clk'event and clk='1') then
count <=count+1;
if (count = 50) then
tmp <= NOT tmp;
count <= 1;
end if;
end if;
i_clk_test <= tmp;
end process;
end entity;
```
The rest of the code return us the counter with the same way that we explained before.

## cmpt_TB ##

After, we have to test this code with a "Test Bench". The Test Bench simulates the behaviour of the sensor in a case we choose and have to confirms our expectations.

```
entity cmpt_TB is
end cmpt_TB;

architecture tb of cmpt_TB is
signal i_clk_ref            : std_logic;
signal i_clk_test           : std_logic;
signal i_rstb               : std_logic;
signal o_clock_freq         : std_logic;

constant T : time := 10e3 ns

begin

UUT : entity work.cmpt port map (i_clk_ref => i_clk_ref, i_clk_test => i_clk_test, o_clock_freq => o_clock_freq);

i_clk_ref <= '1', '0' after 0.835e5 ns, '1' after 1.67e5 ns, '0' after 0.835e5 ns;

-- clock of the process

process
begin
i_clock_test <= '0';
wait for T/2;
i_clock_test <= '1';
wait for T/2;
end process;

end tb;

```

That tests the counter and show us what we want : a value for the counter.

```

architecture rtl of clock_freq_counter is

-- r1_  register con clock reference domain
-- r2_  register con clock test domain

--  CLOCK REFERENCE signal declaration
signal r1_counter_ref              : unsigned(12 downto 0);  -- 12+1 bit: extra bit used for test counter control
signal r1_counter_test_ena         : std_logic;
signal r1_counter_test_strobe      : std_logic;
signal r1_counter_test_rstb        : std_logic;
--  CLOCK TEST signal declaration
signal r2_counter_test             : unsigned(15 downto 0); -- clock test can be up-to 16 times clock ref
signal r2_counter_test_ena         : std_logic;
signal r2_counter_test_strobe      : std_logic;
signal r2_counter_test_rstb        : std_logic;

begin
--  CLOCK REFERENCE domain
p_counter_ref : process (i_rstb,i_clk_ref)
begin
  if(i_rstb='0') then
    r1_counter_ref                 <= (others=>'0');
    r1_counter_test_ena            <= '0';
    r1_counter_test_strobe         <= '0';
    r1_counter_test_rstb           <= '0';
  elsif(rising_edge(i_clk_ref)) then
    r1_counter_ref            <= r1_counter_ref + 1;  -- free running

    -- use MSB to control test counter
    r1_counter_test_ena       <= not r1_counter_ref(r1_counter_ref'high);

    -- enable storing for 1024 clock cycle after 256 clock cycle
    if(r1_counter_ref>16#1100#) and (r1_counter_ref<16#1500#) then
      r1_counter_test_strobe     <= '1';
    else
      r1_counter_test_strobe     <= '0';
    end if;

    -- enable reset for 1024 clock cycle; after 1024 clock cycle from storing
    if(r1_counter_ref>16#1900#) and (r1_counter_ref<16#1D00#) then
      r1_counter_test_rstb    <= '0';
    else
      r1_counter_test_rstb    <= '1';
    end if;

  end if;
end process p_counter_ref;

------------------------------------------------------------------------------------------------------------------------

p_clk_test_resync : process (i_clk_test)
begin
  if(rising_edge(i_clk_test)) then
    r2_counter_test_ena        <= r1_counter_test_ena     ;
    r2_counter_test_strobe     <= r1_counter_test_strobe  ;
    r2_counter_test_rstb       <= r1_counter_test_rstb    ;
  end if;
end process p_clk_test_resync;

p_counter_test : process (r2_counter_test_rstb,i_clk_test)
begin
  if(r2_counter_test_rstb='0') then
    r2_counter_test         <= (others=>'0');
  elsif(rising_edge(i_clk_test)) then
    if(r2_counter_test_ena='1') then
      r2_counter_test    <= r2_counter_test + 1;
    end if;
  end if;
end process p_counter_test;

p_counter_test_out : process (i_rstb,i_clk_test)
begin
  if(i_rstb='0') then
    o_clock_freq         <= (others=>'1');  -- set all bit to '1' at reset and if test clock is not present
  elsif(rising_edge(i_clk_test)) then
    if(r2_counter_test_strobe='1') then
		o_clock_freq         <= std_logic_vector(r2_counter_test);
    end if;
  end if;
end process p_counter_test_out;

end rtl;

```

## I2C_M ##

Then, we get back to the sensor and see what it can bring us. We know that it still contains 2 important variables "offset" and "sensitivity" which are necessary to obtain the humidity rate. To attempt these values, we have to search in registries of the sensor the information we want. Then, we will do this search with an I2C protocol code named "I2C_M" that will extract "offset" and "sensitivity" and put them into registries we will use just after. The I2C driver will find values of "offset" and "sensibility" that we could considered as constant before.

Then, we can go to the I2C driver. How does a I2C driver work ? First, we consider a driver by its state machine. This means that we implement lines that explain the behaviour of the FPGA and how it has to go step by step. The following picture is quite interesting to understand the work of the driver.

![image](https://user-images.githubusercontent.com/82948794/122188590-6466c000-ce90-11eb-9e5c-fea19a2fda71.png)

The explanation of how it runs is developed in this links : https://forum.digikey.com/t/i2c-master-vhdl/12797

The I2C_M master code (driver I2C) say how we can change state and when it is possible. We thus know when we have to reset, when the bus is ready to write information on sda, when the machine is able to receive or send datas etc. We can see a part of the I2C driver given in Code VHDL Folder and called "I2C_M" just below.

![image](https://user-images.githubusercontent.com/82948794/121969260-30967800-cd74-11eb-952c-9be7ef9bdd36.png)

## I2C_M_Test_Bench ##

To test the I2C_M we found, we will work like in the previous code. That means simulate the information we could find in registries of the sensor withour link physically the sensor. We thus have to put adresses of registries of humidity sensor that are in the datasheet you can find in the documentation like that :

![image](https://user-images.githubusercontent.com/82948794/122187905-c3780500-ce8f-11eb-88fe-90cdfa60f49d.png)

And our code computes these adress :

```

	constant DEVICE	: std_logic_vector(6 downto 0):= "0000001";		-- the eeprom physical address     
	constant ADDR		: std_logic_vector(7 downto 0):= "00000001";	
	constant REGCONF : std_logic_vector(7 downto 0):= "01000010";	
	constant REGRD : std_logic_vector(7 downto 0):= "01110010";

```

## codeC ##

To end, we have put together all the previous important datas :
- Counter
- Offset
- Sensitivity

And implement it into the "codeC.c" that will return us the value of humidity rate.
 
It will first have to read information in the registries of I2C_M :

```

//-------------Lecture  I2C------------------
signed byte lec_i2c(byte device, byte address, byte del) {
   signed BYTE data;

   i2c_start();
   i2c_write(device);
   i2c_write(address);
   if (del!=0) delay_ms(del);
   i2c_start();
   i2c_write(device | 1);
   data=i2c_read(0);
   i2c_stop();
   return(data);
}

//-------------Lecture  I2C  2 bytes -----------------
signed int16 lecdb_i2c(byte device, byte address, byte del) {
   BYTE dataM,dataL;
   int16 data;

   i2c_start();
   i2c_write(device);
   i2c_write(address);
   if (del!=0) delay_ms(del);
   i2c_start();
   i2c_write(device | 1);
   dataM = i2c_read(1);				// Read MSB
   dataL = i2c_read(0);				// Read LSB
   i2c_stop();
   data=((dataM*256)+dataL);		// True value
   return(data);
}

```

If you cannot extract "offset" and "sensitivity" you can use it like parametres in the codeC.c 
- offset = 7500 (around max frequency of 7.5 kHz)
- sens = 600


All these variables are used to calculate the humidity rate (RH%) we search. 

You can see a picture of our installation below and the presentation of it in the YouTube link present in the "readme".

![image](https://user-images.githubusercontent.com/82948794/122190344-033fec00-ce92-11eb-8d00-6229ecf7350d.png)


# How to use these previous code with my FPGA and my board ? #

You can find an explanation of that in documentation [Tuto Quartus-ModelSim-Putty](Documentation/Tuto Quartus-ModelSim-Putty.md)



