library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.cam_pkg.all;

entity hist_y is
  generic (
    ID     : integer range 0 to 63   := 0;
    WIDTH  : natural range 1 to 2048 := 2048;
    HEIGHT : natural range 1 to 2048 := 2048
    );
  port (
    pipe_in  : in  pipe_t;
    pipe_out : out pipe_t);
end hist_y;

architecture impl of hist_y is

-------------------------------------------------------------------------------
-- Pipe
-------------------------------------------------------------------------------
  
  signal clk        : std_logic;
  signal rst        : std_logic;
  signal stage      : stage_t;
  signal stage_next : stage_t;

-------------------------------------------------------------------------------
-- Register
-------------------------------------------------------------------------------
  constant PHASES : natural := 4;
  subtype  counter_t is natural range 0 to 2047;
  type     reg_t is record
    cols   : natural range 0 to WIDTH;
    rows   : natural range 0 to HEIGHT;
    val    : counter_t;
    cur    : counter_t;
    rd_adr : natural range 0 to WIDTH-1;
    wr_adr : natural range 0 to WIDTH-1;
    phase  : natural range 0 to 3;
  end record;

  signal r      : reg_t;
  signal r_next : reg_t;

  procedure init (variable v : inout reg_t) is
  begin
    v.cols := 0;
    v.rows := 0;
    v.cur  := 0;
    v.val  := 0;
    v.rd_adr := 1;
    v.wr_adr := 0;
    v.phase := 0;
  end init;

  signal ram2_wen  : std_logic_vector(0 downto 0);
  signal ram2_adr  : std_logic_vector(10 downto 0);
  signal ram2_din  : std_logic_vector(9 downto 0);
  signal ram2_dout : std_logic_vector(9 downto 0);

  signal ram0_wen  : std_logic_vector(0 downto 0);
  signal ram0_adr  : std_logic_vector(10 downto 0);
  signal ram0_din  : std_logic_vector(9 downto 0);
  signal ram0_dout : std_logic_vector(9 downto 0);

  signal ram1_wen  : std_logic_vector(0 downto 0);
  signal ram1_adr  : std_logic_vector(10 downto 0);
  signal ram1_din  : std_logic_vector(9 downto 0);
  signal ram1_dout : std_logic_vector(9 downto 0);
begin
  
  clk <= pipe_in.ctrl.clk;
  rst <= pipe_in.ctrl.rst;

  pipe_out.ctrl  <= pipe_in.ctrl;
  pipe_out.cfg   <= pipe_in.cfg;
  pipe_out.stage <= stage;

  swap_ram : entity work.bit_ram
    generic map (
      ADDR_BITS  => 11,
      WIDTH_BITS => 10)
    port map (
      clka  => clk,                     -- [IN]
      wea   => ram2_wen,                -- [IN]
      addra => ram2_adr,                -- [IN]
      dina  => ram2_din,                -- [IN]
      douta => ram2_dout);              -- [OUT]

  ram0_ram : entity work.bit_ram
    generic map (
      ADDR_BITS  => 11,
      WIDTH_BITS => 10)
    port map (
      clka  => clk,                     -- [IN]
      wea   => ram0_wen,                -- [IN]
      addra => ram0_adr,                -- [IN]
      dina  => ram0_din,                -- [IN]
      douta => ram0_dout);              -- [OUT]

  ram1_ram : entity work.bit_ram
    generic map (
      ADDR_BITS  => 11,
      WIDTH_BITS => 10)
    port map (
      clka  => clk,                     -- [IN]
      wea   => ram1_wen,                -- [IN]
      addra => ram1_adr,                -- [IN]
      dina  => ram1_din,                -- [IN]
      douta => ram1_dout);              -- [OUT]  


  ram0_adr <= std_logic_vector(to_unsigned(r.wr_adr, 11)) when r.phase = 0 or r.phase = 2 else
              std_logic_vector(to_unsigned(r.rd_adr, 11));

  ram1_adr <= std_logic_vector(to_unsigned(r.wr_adr, 11)) when r.phase = 1 else
              std_logic_vector(to_unsigned(r.rd_adr, 11));
  
  ram2_adr <= std_logic_vector(to_unsigned(r.wr_adr, 11)) when r.phase = 3 else
              std_logic_vector(to_unsigned(r.rd_adr, 11));

  ram0_wen <= "1" when (r.phase = 0 or r.phase = 2) and pipe_in.stage.valid = '1' else
              "0";

  ram1_wen <= "1" when r.phase = 1 and pipe_in.stage.valid = '1' else
              "0";

  ram2_wen <= "1" when r.phase = 3 and pipe_in.stage.valid = '1' else
              "0";
  
  process (pipe_in)
    variable v   : reg_t;
    variable cur : natural range 0 to (HEIGHT-1);
  begin
    stage_next <= pipe_in.stage;
    v          := r;
-------------------------------------------------------------------------------
-- Logic
-------------------------------------------------------------------------------

    if v.phase = 0 then
      if pipe_in.stage.data_1 = "1" then
        ram0_din <= std_logic_vector(unsigned(ram1_dout)+1);
      else
        ram0_din <= std_logic_vector(unsigned(ram1_dout)+0);
      end if;
      if v.rows = 0 then
        ram0_din <= std_logic_vector(to_unsigned(0, 10));
      end if;
      ram1_din <= (others => '0');
      ram2_din <= (others => '0');
      cur      := to_integer(unsigned(ram2_dout));
    elsif v.phase = 1 then
      if pipe_in.stage.data_1 = "1" then
        ram1_din <= std_logic_vector(unsigned(ram0_dout)+1);
      else
        ram1_din <= std_logic_vector(unsigned(ram0_dout)+0);
      end if;
      if v.rows = 0 then
        ram1_din <= std_logic_vector(to_unsigned(0, 10));
      end if;
      ram0_din <= (others => '0');
      ram2_din <= (others => '0');
      cur      := to_integer(unsigned(ram2_dout));
    elsif v.phase = 2 then
      if pipe_in.stage.data_1 = "1" then
        ram0_din <= std_logic_vector(unsigned(ram2_dout)+1);
      else
        ram0_din <= std_logic_vector(unsigned(ram2_dout)+0);
      end if;
      if v.rows = 0 then
        ram0_din <= std_logic_vector(to_unsigned(0, 10));
      end if;
      ram2_din <= (others => '0');
      ram1_din <= (others => '0');
      cur      := to_integer(unsigned(ram1_dout));
    else
      if pipe_in.stage.data_1 = "1" then
        ram2_din <= std_logic_vector(unsigned(ram0_dout)+1);
      else
        ram2_din <= std_logic_vector(unsigned(ram0_dout)+0);
      end if;
      if v.rows = 0 then
        ram2_din <= std_logic_vector(to_unsigned(0, 10));
      end if;

      ram0_din <= (others => '0');
      ram1_din <= (others => '0');
      cur      := to_integer(unsigned(ram1_dout));
    end if;


    if pipe_in.stage.valid = '1' then

      if v.rd_adr = (WIDTH-1) then
        v.rd_adr := 0;
      else
        v.rd_adr := v.rd_adr + 1;
      end if;

      if v.wr_adr = (WIDTH-1) then
        v.wr_adr := 0;

        if v.rows = (HEIGHT-1) then
          if v.phase = 0 or v.phase = 1 then
            v.phase := 2;
          else
            v.phase := 0;
          end if;
        else
          if v.phase = 0 then
            v.phase := 1;
          elsif v.phase = 1 then
            v.phase := 0;
          elsif v.phase = 2 then
            v.phase := 3;
          elsif v.phase = 3 then
            v.phase := 2;
          end if;
        end if;

      else
        v.wr_adr := v.wr_adr + 1;
      end if;
      
    end if;
-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------
    if v.rows < cur then
      stage_next.data_1   <= (others => '1');
      stage_next.data_8   <= (others => '1');
      stage_next.data_565 <= (others => '1');
      stage_next.data_888 <= (others => '1');
    else
      stage_next.data_1   <= (others => '0');
      stage_next.data_8   <= (others => '0');
      stage_next.data_565 <= (others => '0');
      stage_next.data_888 <= (others => '0');
    end if;
-------------------------------------------------------------------------------
-- Counter
-------------------------------------------------------------------------------
    if pipe_in.stage.valid = '1' then
      if v.cols = (WIDTH-1) then
        v.cols := 0;
        if v.rows = (HEIGHT-1) then
          v.rows := 0;
        else
          v.rows := v.rows + 1;
        end if;
      else
        v.cols := v.cols + 1;
      end if;
    end if;
-------------------------------------------------------------------------------
-- Reset
-------------------------------------------------------------------------------
    if rst = '1' then
      stage_next <= NULL_STAGE;
      init(v);
    end if;
-------------------------------------------------------------------------------
-- Next
-------------------------------------------------------------------------------    
    r_next <= v;
  end process;

  proc_clk : process(pipe_in)
  begin
    if rising_edge(clk) then
      if (pipe_in.cfg(ID).enable = '1') then
        stage <= stage_next;
      else
        stage <= pipe_in.stage;
      end if;
      r <= r_next;
    end if;
  end process;

end impl;