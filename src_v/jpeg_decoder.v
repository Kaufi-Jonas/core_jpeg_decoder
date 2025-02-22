//-----------------------------------------------------------------
//                       AXI-4 JPEG Decoder
//                             V0.2
//                       Ultra-Embedded.com
//                        Copyright 2020
//
//                   admin@ultra-embedded.com
//-----------------------------------------------------------------
//                      License: Apache 2.0
// This IP can be freely used in commercial projects, however you may
// want access to unreleased materials such as verification environments,
// or test vectors, as well as changes to the IP for integration purposes.
// If this is the case, contact the above address.
// I am interested to hear how and where this IP is used, so please get
// in touch!
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

`include "jpeg_decoder_defs.v"

//-----------------------------------------------------------------
// Module:  JPEG Decoder Peripheral
//-----------------------------------------------------------------
module jpeg_decoder
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter AXI_ID           = 0,
     parameter SUPPORT_WRITABLE_DHT = 0,
     parameter NUM_DECODERS = 1
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input          clk,
     input          rst
    ,input          s_axil_awvalid
    ,input  [31:0]  s_axil_awaddr
    ,input          s_axil_wvalid
    ,input  [31:0]  s_axil_wdata
    ,input  [3:0]   s_axil_wstrb
    ,input          s_axil_bready
    ,input          s_axil_arvalid
    ,input  [31:0]  s_axil_araddr
    ,input          s_axil_rready
    ,input          m_axi_awready
    ,input          m_axi_wready
    ,input          m_axi_bvalid
    ,input  [1:0]   m_axi_bresp
    ,input  [3:0]   m_axi_bid
    ,input          m_axi_arready
    ,input          m_axi_rvalid
    ,input  [31:0]  m_axi_rdata
    ,input  [1:0]   m_axi_rresp
    ,input  [3:0]   m_axi_rid
    ,input          m_axi_rlast

    ,input  [3:0]   output_mux

    // Outputs
    ,output         s_axil_awready
    ,output         s_axil_wready
    ,output         s_axil_bvalid
    ,output [1:0]   s_axil_bresp
    ,output         s_axil_arready
    ,output         s_axil_rvalid
    ,output [31:0]  s_axil_rdata
    ,output [1:0]   s_axil_rresp
    ,output         m_axi_awvalid
    ,output [31:0]  m_axi_awaddr
    ,output [3:0]   m_axi_awid
    ,output [7:0]   m_axi_awlen
    ,output [1:0]   m_axi_awburst
    ,output         m_axi_wvalid
    ,output [31:0]  m_axi_wdata
    ,output [3:0]   m_axi_wstrb
    ,output         m_axi_wlast
    ,output         m_axi_bready
    ,output         m_axi_arvalid
    ,output [31:0]  m_axi_araddr
    ,output [3:0]   m_axi_arid
    ,output [7:0]   m_axi_arlen
    ,output [1:0]   m_axi_arburst
    ,output         m_axi_rready
);

//-----------------------------------------------------------------
// Write address / data split
//-----------------------------------------------------------------
// Address but no data ready
reg awvalid_q;

// Data but no data ready
reg wvalid_q;

wire wr_cmd_accepted_w  = (s_axil_awvalid && s_axil_awready) || awvalid_q;
wire wr_data_accepted_w = (s_axil_wvalid  && s_axil_wready)  || wvalid_q;

always @ (posedge clk or posedge rst)
if (rst)
    awvalid_q <= 1'b0;
else if (s_axil_awvalid && s_axil_awready && !wr_data_accepted_w)
    awvalid_q <= 1'b1;
else if (wr_data_accepted_w)
    awvalid_q <= 1'b0;

always @ (posedge clk or posedge rst)
if (rst)
    wvalid_q <= 1'b0;
else if (s_axil_wvalid && s_axil_wready && !wr_cmd_accepted_w)
    wvalid_q <= 1'b1;
else if (wr_cmd_accepted_w)
    wvalid_q <= 1'b0;

//-----------------------------------------------------------------
// Capture address (for delayed data)
//-----------------------------------------------------------------
reg [7:0] wr_addr_q;

always @ (posedge clk or posedge rst)
if (rst)
    wr_addr_q <= 8'b0;
else if (s_axil_awvalid && s_axil_awready)
    wr_addr_q <= s_axil_awaddr[7:0];

wire [7:0] wr_addr_w = awvalid_q ? wr_addr_q : s_axil_awaddr[7:0];

//-----------------------------------------------------------------
// Retime write data
//-----------------------------------------------------------------
reg [31:0] wr_data_q;

always @ (posedge clk or posedge rst)
if (rst)
    wr_data_q <= 32'b0;
else if (s_axil_wvalid && s_axil_wready)
    wr_data_q <= s_axil_wdata;

//-----------------------------------------------------------------
// Request Logic
//-----------------------------------------------------------------
wire read_en_w  = s_axil_arvalid & s_axil_arready;
wire write_en_w = wr_cmd_accepted_w && wr_data_accepted_w;

//-----------------------------------------------------------------
// Accept Logic
//-----------------------------------------------------------------
assign s_axil_arready = ~s_axil_rvalid;
assign s_axil_awready = ~s_axil_bvalid && ~s_axil_arvalid && ~awvalid_q;
assign s_axil_wready  = ~s_axil_bvalid && ~s_axil_arvalid && ~wvalid_q;


//-----------------------------------------------------------------
// Register jpeg_ctrl
//-----------------------------------------------------------------
reg jpeg_ctrl_wr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_ctrl_wr_q <= 1'b0;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_CTRL))
    jpeg_ctrl_wr_q <= 1'b1;
else
    jpeg_ctrl_wr_q <= 1'b0;

// jpeg_ctrl_start [auto_clr]
reg        jpeg_ctrl_start_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_ctrl_start_q <= 1'd`JPEG_CTRL_START_DEFAULT;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_CTRL))
    jpeg_ctrl_start_q <= s_axil_wdata[`JPEG_CTRL_START_R];
else
    jpeg_ctrl_start_q <= 1'd`JPEG_CTRL_START_DEFAULT;

wire        jpeg_ctrl_start_out_w = jpeg_ctrl_start_q;


// jpeg_ctrl_abort [auto_clr]
reg        jpeg_ctrl_abort_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_ctrl_abort_q <= 1'd`JPEG_CTRL_ABORT_DEFAULT;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_CTRL))
    jpeg_ctrl_abort_q <= s_axil_wdata[`JPEG_CTRL_ABORT_R];
else
    jpeg_ctrl_abort_q <= 1'd`JPEG_CTRL_ABORT_DEFAULT;

wire        jpeg_ctrl_abort_out_w = jpeg_ctrl_abort_q;


// jpeg_ctrl_length [internal]
reg [23:0]  jpeg_ctrl_length_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_ctrl_length_q <= 24'd`JPEG_CTRL_LENGTH_DEFAULT;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_CTRL))
    jpeg_ctrl_length_q <= s_axil_wdata[`JPEG_CTRL_LENGTH_R];

wire [23:0]  jpeg_ctrl_length_out_w = jpeg_ctrl_length_q;


//-----------------------------------------------------------------
// Register jpeg_status
//-----------------------------------------------------------------
reg jpeg_status_wr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_status_wr_q <= 1'b0;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_STATUS))
    jpeg_status_wr_q <= 1'b1;
else
    jpeg_status_wr_q <= 1'b0;


//-----------------------------------------------------------------
// Register jpeg_src
//-----------------------------------------------------------------
reg jpeg_src_wr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_src_wr_q <= 1'b0;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_SRC))
    jpeg_src_wr_q <= 1'b1;
else
    jpeg_src_wr_q <= 1'b0;

// jpeg_src_addr [internal]
reg [31:0]  jpeg_src_addr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_src_addr_q <= 32'd`JPEG_SRC_ADDR_DEFAULT;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_SRC))
    jpeg_src_addr_q <= s_axil_wdata[`JPEG_SRC_ADDR_R];

wire [31:0]  jpeg_src_addr_out_w = jpeg_src_addr_q;


//-----------------------------------------------------------------
// Register jpeg_dst
//-----------------------------------------------------------------
reg jpeg_dst_wr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_dst_wr_q <= 1'b0;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_DST))
    jpeg_dst_wr_q <= 1'b1;
else
    jpeg_dst_wr_q <= 1'b0;

// jpeg_dst_addr [internal]
reg [31:0]  jpeg_dst_addr_q;

always @ (posedge clk or posedge rst)
if (rst)
    jpeg_dst_addr_q <= 32'd`JPEG_DST_ADDR_DEFAULT;
else if (write_en_w && (wr_addr_w[7:0] == `JPEG_DST))
    jpeg_dst_addr_q <= s_axil_wdata[`JPEG_DST_ADDR_R];

wire [31:0]  jpeg_dst_addr_out_w = jpeg_dst_addr_q;


wire        jpeg_status_busy_in_w;


//-----------------------------------------------------------------
// Read mux
//-----------------------------------------------------------------
reg [31:0] data_r;

always @ *
begin
    data_r = 32'b0;

    case (s_axil_araddr[7:0])

    `JPEG_CTRL:
    begin
        data_r[`JPEG_CTRL_LENGTH_R] = jpeg_ctrl_length_q;
    end
    `JPEG_STATUS:
    begin
        data_r[`JPEG_STATUS_BUSY_R] = jpeg_status_busy_in_w;
    end
    `JPEG_SRC:
    begin
        data_r[`JPEG_SRC_ADDR_R] = jpeg_src_addr_q;
    end
    `JPEG_DST:
    begin
        data_r[`JPEG_DST_ADDR_R] = jpeg_dst_addr_q;
    end
    default :
        data_r = 32'b0;
    endcase
end

//-----------------------------------------------------------------
// RVALID
//-----------------------------------------------------------------
reg rvalid_q;

always @ (posedge clk or posedge rst)
if (rst)
    rvalid_q <= 1'b0;
else if (read_en_w)
    rvalid_q <= 1'b1;
else if (s_axil_rready)
    rvalid_q <= 1'b0;

assign s_axil_rvalid = rvalid_q;

//-----------------------------------------------------------------
// Retime read response
//-----------------------------------------------------------------
reg [31:0] rd_data_q;

always @ (posedge clk or posedge rst)
if (rst)
    rd_data_q <= 32'b0;
else if (!s_axil_rvalid || s_axil_rready)
    rd_data_q <= data_r;

assign s_axil_rdata = rd_data_q;
assign s_axil_rresp = 2'b0;

//-----------------------------------------------------------------
// BVALID
//-----------------------------------------------------------------
reg bvalid_q;

always @ (posedge clk or posedge rst)
if (rst)
    bvalid_q <= 1'b0;
else if (write_en_w)
    bvalid_q <= 1'b1;
else if (s_axil_bready)
    bvalid_q <= 1'b0;

assign s_axil_bvalid = bvalid_q;
assign s_axil_bresp  = 2'b0;



localparam BUFFER_DEPTH   = 1024;
localparam BUFFER_DEPTH_W = 10;
localparam BURST_LEN      = 32 / 4;

wire        jpeg_valid_w;
wire [31:0] jpeg_data_w;
wire        jpeg_accept_w;

wire [10:0] fifo_in_level_w;
wire [10:0] fifo_addr_level_w;
wire [10:0] fifo_data_level_w;

reg         core_busy_q;
wire [NUM_DECODERS-1:0] core_idle_w;
reg [31:0]  remaining_q;
reg [15:0]  allocated_q;

//-----------------------------------------------------------------
// FSM
//-----------------------------------------------------------------
localparam STATE_W          = 2;

// Current state
localparam STATE_IDLE       = 2'd0;
localparam STATE_FILL       = 2'd1;
localparam STATE_ACTIVE     = 2'd2;
localparam STATE_DRAIN      = 2'd3;
reg [STATE_W-1:0] state_q;
reg [STATE_W-1:0] next_state_r;

always @ *
begin
    next_state_r = state_q;

    case (state_q)
    STATE_IDLE :
    begin
        if (jpeg_ctrl_start_out_w)
            next_state_r  = STATE_FILL;
    end
    STATE_FILL:
    begin
        if ((fifo_in_level_w > (BUFFER_DEPTH/2)) || (remaining_q == 32'b0))
            next_state_r  = STATE_ACTIVE;
    end
    STATE_ACTIVE:
    begin
        if (core_busy_q && core_idle_w[output_mux])
            next_state_r  = STATE_DRAIN;
    end
    STATE_DRAIN:
    begin
        if (fifo_addr_level_w == 11'b0 && fifo_data_level_w == 11'b0)
            next_state_r = STATE_IDLE;
    end
    default:
        ;
    endcase

    if (jpeg_ctrl_abort_out_w)
        next_state_r = STATE_IDLE;
end

always @ (posedge clk or posedge rst)
if (rst)
    state_q <= STATE_IDLE;
else
    state_q <= next_state_r;

assign jpeg_status_busy_in_w = (state_q != STATE_IDLE);    

//-----------------------------------------------------------------
// Core active
//-----------------------------------------------------------------
reg  core_active_q;

always @ (posedge clk or posedge rst)
if (rst)
    core_active_q  <= 1'b0;
else if (state_q == STATE_IDLE && next_state_r == STATE_FILL)
    core_active_q  <= 1'b1;
else if (state_q == STATE_ACTIVE && next_state_r == STATE_DRAIN)
    core_active_q  <= 1'b0;

//-----------------------------------------------------------------
// Core busy
//-----------------------------------------------------------------
always @ (posedge clk or posedge rst)
if (rst)
    core_busy_q  <= 1'b0;
else if (state_q == STATE_ACTIVE && !core_idle_w[output_mux])
    core_busy_q  <= 1'b1;
else if (state_q == STATE_ACTIVE && core_idle_w[output_mux])
    core_busy_q  <= 1'b0;

//-----------------------------------------------------------------
// FIFO allocation
//-----------------------------------------------------------------
always @ (posedge clk or posedge rst)
if (rst)
    allocated_q  <= 16'b0;
else if (jpeg_ctrl_abort_out_w || (state_q == STATE_DRAIN))
    allocated_q  <= 16'b0;
else if (m_axi_arvalid && m_axi_arready)
begin
    if (jpeg_valid_w && jpeg_accept_w)
        allocated_q  <= allocated_q + {8'b0, m_axi_arlen};
    else
        allocated_q  <= allocated_q + {8'b0, m_axi_arlen} + 16'd1;
end
else if (jpeg_valid_w && jpeg_accept_w)
    allocated_q  <= allocated_q - 16'd1;

//-----------------------------------------------------------------
// AXI Fetch
//-----------------------------------------------------------------
// Calculate number of bytes being fetch
wire [31:0] fetch_bytes_w = {22'b0, (m_axi_arlen + 8'd1), 2'b0};

reg         arvalid_q;
reg [31:0]  araddr_q;

wire [31:0] remain_rounded_w = remaining_q + 32'd3;
wire [31:0] remain_words_w   = {2'b0, remain_rounded_w[31:2]};
wire [31:0] max_words_w      = (remain_words_w > BURST_LEN && (araddr_q & ((BURST_LEN*4)-1)) == 32'd0) ? BURST_LEN : 1;
wire        fifo_space_w     = (BUFFER_DEPTH - allocated_q) > BURST_LEN;

always @ (posedge clk or posedge rst)
if (rst)
    remaining_q <= 32'b0;
else if (jpeg_ctrl_start_out_w)
    remaining_q <= {8'b0, jpeg_ctrl_length_out_w};
else if (jpeg_ctrl_abort_out_w)
    remaining_q <= 32'b0;
else if (m_axi_arvalid && m_axi_arready)
begin
    if (remaining_q > fetch_bytes_w)
        remaining_q <= remaining_q - fetch_bytes_w;
    else
        remaining_q <= 32'b0;
end

always @ (posedge clk or posedge rst)
if (rst)
    arvalid_q <= 1'b0;
else if (m_axi_arvalid && m_axi_arready)
    arvalid_q <= 1'b0;
else if (!m_axi_arvalid && fifo_space_w && remaining_q != 32'b0)
    arvalid_q <= 1'b1;

assign m_axi_arvalid = arvalid_q;

always @ (posedge clk or posedge rst)
if (rst)
    araddr_q <= 32'b0;
else if (m_axi_arvalid && m_axi_arready)
    araddr_q  <= araddr_q + fetch_bytes_w;
else if (jpeg_ctrl_start_out_w)
    araddr_q <= jpeg_src_addr_out_w;

reg [7:0] arlen_q;

always @ (posedge clk or posedge rst)
if (rst)
    arlen_q <= 8'b0;
else
    arlen_q <= max_words_w - 1;

assign m_axi_araddr  = araddr_q;
assign m_axi_arburst = 2'b01;
assign m_axi_arid    = AXI_ID;
assign m_axi_arlen   = arlen_q;

assign m_axi_rready  = 1'b1;

//-----------------------------------------------------------------
// JPEG fetch FIFO
//-----------------------------------------------------------------
wire fifo_jpeg_valid_w;

jpeg_decoder_input_fifo
u_fifo_in
(
     .clk_i(clk)
    ,.rst_i(rst)

    ,.flush_i(jpeg_ctrl_abort_out_w || (state_q == STATE_DRAIN))

    ,.push_i(m_axi_rvalid)
    ,.data_in_i(m_axi_rdata)
    ,.accept_o()

    ,.valid_o(fifo_jpeg_valid_w)
    ,.data_out_o(jpeg_data_w)
    ,.pop_i(jpeg_accept_w)

    ,.level_o(fifo_in_level_w)
);

assign jpeg_valid_w = fifo_jpeg_valid_w & (state_q == STATE_ACTIVE);

//-----------------------------------------------------------------
// Decoder core
//-----------------------------------------------------------------
wire [15:0] pixel_x_w [NUM_DECODERS-1:0];
wire [15:0] pixel_y_w [NUM_DECODERS-1:0];
wire [15:0] pixel_w_w [NUM_DECODERS-1:0];
wire [15:0] pixel_h_w [NUM_DECODERS-1:0];

wire        pixel_valid_w [NUM_DECODERS-1:0];
wire [7:0]  pixel_r_w [NUM_DECODERS-1:0];
wire [7:0]  pixel_g_w [NUM_DECODERS-1:0];
wire [7:0]  pixel_b_w [NUM_DECODERS-1:0];
wire        fifo_accept_in_w;

wire        core_accept_w [NUM_DECODERS-1:0];

generate
    for (genvar i = 0; i < NUM_DECODERS; i = i + 1) begin
        (* KEEP_HIERARCHY = "TRUE" *)  // prevent this from being optimized out
        jpeg_core #( .SUPPORT_WRITABLE_DHT(SUPPORT_WRITABLE_DHT) )
            u_core
            (
                .clk_i(clk)
                ,.rst_i(~core_active_q)

                ,.inport_valid_i(jpeg_valid_w)
                ,.inport_data_i(jpeg_data_w)
                ,.inport_strb_i(4'hF)
                ,.inport_last_i(1'b0)
                ,.inport_accept_o(core_accept_w[i])

                ,.outport_valid_o(pixel_valid_w[i])
                ,.outport_width_o(pixel_w_w[i])
                ,.outport_height_o(pixel_h_w[i])
                ,.outport_pixel_x_o(pixel_x_w[i])
                ,.outport_pixel_y_o(pixel_y_w[i])
                ,.outport_pixel_r_o(pixel_r_w[i])
                ,.outport_pixel_g_o(pixel_g_w[i])
                ,.outport_pixel_b_o(pixel_b_w[i])
                ,.outport_accept_i(fifo_accept_in_w)

                ,.idle_o(core_idle_w[i])
            );

    end
endgenerate

assign jpeg_accept_w = core_accept_w[output_mux] & (state_q == STATE_ACTIVE);

wire [15:0] rgb565_w = {pixel_r_w[output_mux][7:3], pixel_g_w[output_mux][7:2], pixel_b_w[output_mux][7:3]};

//-----------------------------------------------------------------
// Write Combine
//-----------------------------------------------------------------
reg [15:0] pixel_q;
always @ (posedge clk or posedge rst)
if (rst)
    pixel_q  <= 16'b0;
else if (pixel_valid_w[output_mux])
    pixel_q  <= rgb565_w;

reg pixel_idx_q;
always @ (posedge clk or posedge rst)
if (rst)
    pixel_idx_q  <= 1'b0;
else if (pixel_valid_w[output_mux])
    pixel_idx_q  <= ~pixel_x_w[output_mux][0];

reg [31:0] pixel_offset_q;

always @ (posedge clk or posedge rst)
if (rst)
    pixel_offset_q  <= 32'b0;
else
    pixel_offset_q  <= {15'b0, pixel_w_w[output_mux], 1'b0} * {16'b0,pixel_y_w[output_mux]};

wire [31:0] pixel_addr_w  = jpeg_dst_addr_out_w + pixel_offset_q + {15'b0, pixel_x_w[output_mux][15:1], 2'b0};
wire        pixel_ready_w = pixel_idx_q && pixel_valid_w[output_mux];
wire [31:0] pixel_data_w  = {rgb565_w, pixel_q};

//-----------------------------------------------------------------
// Output FIFO
//-----------------------------------------------------------------
wire        fifo_accept_addr_in_w;
wire        fifo_accept_data_in_w;
wire        fifo_addr_push_w = pixel_ready_w & (state_q == STATE_ACTIVE) & fifo_accept_data_in_w;
wire        fifo_data_push_w = pixel_ready_w & (state_q == STATE_ACTIVE) & fifo_accept_addr_in_w;

jpeg_decoder_output_fifo
u_fifo_addr_out
(
     .clk_i(clk)
    ,.rst_i(rst)

    ,.push_i(fifo_addr_push_w)
    ,.data_in_i(pixel_addr_w)
    ,.accept_o(fifo_accept_addr_in_w)

    ,.valid_o(m_axi_awvalid)
    ,.data_out_o(m_axi_awaddr)
    ,.pop_i(m_axi_awready)

    ,.level_o(fifo_addr_level_w)
);

jpeg_decoder_output_fifo
u_fifo_data_out
(
     .clk_i(clk)
    ,.rst_i(rst)

    ,.push_i(fifo_data_push_w)
    ,.data_in_i(pixel_data_w)
    ,.accept_o(fifo_accept_data_in_w)

    ,.valid_o(m_axi_wvalid)
    ,.data_out_o(m_axi_wdata)
    ,.pop_i(m_axi_wready)

    ,.level_o(fifo_data_level_w)
);

assign fifo_accept_in_w = fifo_accept_addr_in_w & fifo_accept_data_in_w;

//-----------------------------------------------------------------
// Constants
//-----------------------------------------------------------------
assign m_axi_awlen   = 8'd0;  // Singles (not efficient!)
assign m_axi_awburst = 2'b01; // INCR
assign m_axi_awid    = AXI_ID;
assign m_axi_wstrb   = 4'hF;
assign m_axi_wlast   = 1'b1;

assign m_axi_bready  = 1'b1;


endmodule
