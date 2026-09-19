module async_fifo #(
	parameter int WIDTH = 8,
	parameter int DEPTH = 16
)(
	input logic rst_n,
	input logic wr_clk,
	input logic wr_en,
	input logic [WIDTH-1:0] wr_data,
	input logic rd_clk,
	input logic rd_en,
	output logic [WIDTH-1:0] rd_data,
	output logic full,
	output logic empty
);

localparam int PTR_WIDTH = $clog2(DEPTH);
logic [WIDTH-1:0] mem[DEPTH];
logic [PTR_WIDTH:0] wr_ptr_bin, wr_ptr_gray, wr_ptr_gray_n;
logic [PTR_WIDTH:0] rd_ptr_bin, rd_ptr_gray, rd_ptr_gray_n;
logic [PTR_WIDTH:0] wr_ptr_sync1, wr_ptr_sync2;
logic [PTR_WIDTH:0] rd_ptr_sync1, rd_ptr_sync2;
logic wr_rst_sync1, wr_rst_sync2;
logic rd_rst_sync1, rd_rst_sync2;

always_ff @(posedge wr_clk or negedge rst_n) begin
	if(!rst_n) begin
		wr_rst_sync1 <= 1'b0;
		wr_rst_sync2 <= 1'b0;
	end else begin
		wr_rst_sync1 <= 1'b1;
		wr_rst_sync2 <= wr_rst_sync1;
	end
end

always_ff @(posedge rd_clk or negedge rst_n) begin
	if(!rst_n) begin
		rd_rst_sync1 <= 1'b0;
		rd_rst_sync2 <= 1'b0;
	end else begin
		rd_rst_sync1 <= 1'b1;
		rd_rst_sync2 <= rd_rst_sync1;
	end
end

assign wr_ptr_gray_n = (wr_ptr_bin + (wr_en && !full)) ^ ((wr_ptr_bin + (wr_en && !full)) >> 1);
always_ff @(posedge wr_clk or negedge wr_rst_sync2) begin
	if(!wr_rst_sync2) begin
		wr_ptr_bin <= '0;
		wr_ptr_gray	<= '0;
	end else if(wr_en && !full) begin
		mem[wr_ptr_bin[PTR_WIDTH-1:0]] <= wr_data;
		wr_ptr_bin <= wr_ptr_bin + 1'b1;
		wr_ptr_gray	<= wr_ptr_gray_n;
	end
end

assign rd_ptr_gray_n = (rd_ptr_bin + (rd_en && !empty)) ^ ((rd_ptr_bin + (rd_en && !empty)) >> 1);
always_ff @(posedge rd_clk or negedge rd_rst_sync2) begin
	if(!rd_rst_sync2) begin
		rd_ptr_bin <= '0;
		rd_ptr_gray	<= '0;
	end else if(rd_en && !empty) begin
		rd_ptr_bin <= rd_ptr_bin + 1'b1;
		rd_ptr_gray	<= rd_ptr_gray_n;
	end
end


always_ff @(posedge wr_clk or negedge wr_rst_sync2) begin
	if(!wr_rst_sync2) begin
		rd_ptr_sync1 <= '0;
		rd_ptr_sync2 <= '0;
	end else begin
		rd_ptr_sync1 <= rd_ptr_gray;
		rd_ptr_sync2 <= rd_ptr_sync1;
	end
end

always_ff @(posedge rd_clk or negedge rd_rst_sync2) begin
	if(!rd_rst_sync2) begin
		wr_ptr_sync1 <= '0;
		wr_ptr_sync2 <= '0;
	end else begin
		wr_ptr_sync1 <= wr_ptr_gray;
		wr_ptr_sync2 <= wr_ptr_sync1;
	end
end

assign rd_data = empty ? '0 : mem[rd_ptr_bin[PTR_WIDTH-1:0]];
assign empty = (wr_ptr_sync2 == rd_ptr_gray);
assign full = (wr_ptr_gray == {~rd_ptr_sync2[PTR_WIDTH:PTR_WIDTH-1],
										rd_ptr_sync2[PTR_WIDTH-2:0]});

endmodule

