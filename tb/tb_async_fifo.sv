`timescale 1ns / 1ps

module tb_async_fifo;

	localparam int WIDTH = 8;
	localparam int DEPTH = 16;
	localparam int PRT_W = $clog2(DEPTH) + 1;
	
	logic             rst_n;
	logic             wr_clk;
	logic             wr_en;
	logic             full;
	logic [WIDTH-1:0] wr_data;
	
	logic             rd_clk;
	logic             rd_en;
	logic             empty;
	logic [WIDTH-1:0] rd_data;

	logic [WIDTH-1:0] q[$];
	logic [PRT_W -1:0] wr_ptr_before;
	logic [PRT_W -1:0] rd_ptr_before;
	

	async_fifo #(
	    .WIDTH(WIDTH),
	    .DEPTH(DEPTH)
	) u_dut (
		.rst_n(rst_n),
		.wr_clk(wr_clk),
		.wr_en(wr_en),
		.wr_data(wr_data),
		.rd_clk(rd_clk),
		.rd_en(rd_en),
		.rd_data(rd_data),
		.full(full),
		.empty(empty)
	);


	initial wr_clk = 0; always #5  wr_clk = ~wr_clk; //100Mhz
	initial rd_clk = 0; always #7 rd_clk = ~rd_clk; //71.4Mhz

	always @(posedge wr_clk) begin
		if(!rst_n) begin
			q.delete();
		end else if(wr_en && !full) begin
			q.push_back(wr_data);
		end
	end

	always @(posedge rd_clk) begin
		if(rst_n && rd_en && !empty) begin
			if(q.size() == 0)
			    $fatal(1, “Scoreboard underflow”);
			    
			if(rd_data !== q[0])
			    $fatal(1, "Data mismatch: got %h, expected %h", rd_data, q[0]);
			
			q.pop_front();
		end
	end

	task automatic do_write(
        input logic [WIDTH-1:0] data
    );
		@(negedge wr_clk);
	    wr_en = 1’b1;
    	wr_data = data;

	    @(negedge wr_clk);
	    wr_en = 1’b0;
	endtask

	task automatic do_read;
		@(negedge rd_clk);
	    rd_en = 1’b1;

		@(negedge rd_clk);
	    rd_en = 1’b0;

	endtask
	
	initial begin
		rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_data = '0;

        repeat(3) @(posedge wr_clk);
        rst_n = 1'b1;

		repeat (3) @(posedge wr_clk);
        repeat (3) @(posedge rd_clk);
		
		if(full !== 1’b0 || empty !== 1’b1)
			$fatal(1, "Reset state failure: full=%b empty=%b", full, empty);
		$display(“[PASS] Reset initialization”);

		for (int i = 1; i <= 5; i++) 
			do_write(i*8’h11);

		repeat(3) @(posedge rd_clk);
		if (empty !== 1'b0)
			$fatal(1, "Empty did not deassert after write");
		$display("[PASS] Empty flag deasserted after write synchronization"); 

		for (int i = 1; i <= 5; i++) 
			do_read();

		repeat (2) @(posedge rd_clk);
		if (empty !== 1'b1)
			$fatal(1, "Empty did not assert after drain");
		$display("[PASS] Empty flag assertion after FIFO drain");

		for (int i = 0; i < DEPTH; i++)
      		do_write(i[WIDTH-1:0]); 
    
    	@(posedge wr_clk);
        #1;
       	if (full !== 1'b1)
            $fatal(1, "Full did not assert");

        wr_ptr_before = u_dut.wr_ptr_bin;

        @(negedge wr_clk);
       	wr_en   = 1'b1;
        wr_data = 8'hFF;

       	@(posedge wr_clk);
        #1;
        if (u_dut.wr_ptr_bin !== wr_ptr_before)
           	$fatal(1, "Write pointer changed while full");

        @(negedge wr_clk);
        	wr_en = 1'b0;

        for (int i = 0; i < DEPTH; i++)
            do_read();

        repeat (3) @(posedge rd_clk);
        if (empty !== 1'b1)
            $fatal(1, "Empty did not assert after full drain");

    	rd_ptr_before = u_dut.rd_ptr_bin;

        @(negedge rd_clk);
        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;
        if (u_dut.rd_ptr_bin !== rd_ptr_before)
            $fatal(1, "Read pointer changed while empty");

        @(negedge rd_clk);
       	rd_en = 1'b0;

        $display("[PASS] All directed tests completed");
	end
endmodule

