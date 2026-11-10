module fifo_v3 #(
  parameter bit FALL_THROUGH = 1'b0,
  parameter int unsigned DEPTH = 2,
  parameter type dtype = logic [31:0]
) (
  input logic clk_i,
  input logic rst_ni,
  input logic flush_i,
  input logic testmode_i,
  output logic full_o,
  output logic empty_o,
  output logic [$clog2(DEPTH+1)-1:0] usage_o,
  input dtype data_i,
  input logic push_i,
  output dtype data_o,
  input logic pop_i
);
  dtype storage [DEPTH];
  int unsigned read_ptr;
  int unsigned write_ptr;
  int unsigned count;

  assign full_o = count == DEPTH;
  assign empty_o = count == 0;
  assign usage_o = $clog2(DEPTH+1)'(count);
  assign data_o = empty_o ? '0 : storage[read_ptr];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      read_ptr <= 0;
      write_ptr <= 0;
      count <= 0;
    end else if (flush_i) begin
      read_ptr <= 0;
      write_ptr <= 0;
      count <= 0;
    end else begin
      case ({push_i && !full_o, pop_i && !empty_o})
        2'b10: begin
          storage[write_ptr] <= data_i;
          write_ptr <= (write_ptr + 1) % DEPTH;
          count <= count + 1;
        end
        2'b01: begin
          read_ptr <= (read_ptr + 1) % DEPTH;
          count <= count - 1;
        end
        2'b11: begin
          storage[write_ptr] <= data_i;
          write_ptr <= (write_ptr + 1) % DEPTH;
          read_ptr <= (read_ptr + 1) % DEPTH;
        end
        default: begin
        end
      endcase
    end
  end
endmodule
