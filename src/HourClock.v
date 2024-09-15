// `timescale 1ns / 1ps      // 不知道干什么用的……
//////////////////////////////////////////////////////////////////////////////////
//  针对数电设计核心板内部逻辑所准备的程序
//  在新的学期会转交调试，焊接实现等
/* 备注：本时钟模块的链接：
module HourClock(
input clk,                              // 时钟信号
input en, sel, pause, in,               // 开关的信号
input btn1, btn2, btn3, btn4, rstn,     // 按钮的信号（为了方便写always分开）
output [7:0]seg,                        // 显示数码管输出
output [3:0]dis,                        // 显示位数输出
output led                              // led输出
}
*/
//////////////////////////////////////////////////////////////////////////////////
// 更新日志
// 8.14：添加新的功能，但是情况还是比较模糊（主要是数据类型没想好）
//       尝试添加testbench，但是有个问题就是：增加的数字没有真的增加到对应的位置

// 8.16：所有问题基本解决，但是需要testbench想法以及实际的上机调试

// 9.7：严重问题
// 1，如果将HourClock钟有关于按钮的代码保留，那么会导致“在Implementation中报错“（很特殊）
// 2，写入板子后，目前显示的内容纹丝不动（仅有00：00，不增加或者减少，切换开关没用）
// 可能要留到之后解决了……

// 9.8：经过一整个白天的研究解决掉一些问题了，但是严格意义上来说还是有些问题
// 1，rstn按钮功能不对：目前按下按钮最多只有1位数字改变
// 2，BTN所有按钮均失效（其实我也不太清楚……）
// 3，时钟分频不明确，实际时间比1s快
// 今天就到这里吧

// 9.13 将整个工程移动到高云软件上备用

//////////////////////////////////////////////////////////////////////////////////


// 辅助实现核心功能的其他模块（如译码器等）

// 七段译码器
module SevenSegDecoder(q_num, q_out);  
    input[3:0] q_num;  
    output[7:0] q_out;  
    reg[7:0] q_out;  
      
    always @(q_num) 
        begin  
        case(q_num)       
            4'b0000: q_out=8'b11000000;
            4'b0001: q_out=8'b11111001;
            4'b0010: q_out=8'b10100100;
            4'b0011: q_out=8'b10110000;
            4'b0100: q_out=8'b10011001;
            4'b0101: q_out=8'b10010010;
            4'b0110: q_out=8'b10000010;
            4'b0111: q_out=8'b11111000;
            4'b1000: q_out=8'b10000000;
            4'b1001: q_out=8'b10010000;
            default: q_out=8'b11111111;
        endcase  
        end  
endmodule

// 选择位数输出
module dtsm(MCLK9, d_num1, d_num2, d_num3, d_num4, d1_wx, d1_out);
    input MCLK9;
    input[3:0] d_num1;
    input[3:0] d_num2;
    input[3:0] d_num3;
    input[3:0] d_num4;
    output[3:0] d1_wx;
    output[7:0] d1_out;
    reg[3:0] d1_wx = 4'b1110;
    wire[7:0] d1_out;
    reg[3:0] d_tmp_num;
    
    always @(posedge MCLK9) begin        
        case(d1_wx)
            4'b1110:begin
                            d_tmp_num = d_num2;
                            d1_wx = 4'b1101;
                        end
            4'b1101:begin
                            d_tmp_num = d_num3;
                            d1_wx = 4'b1011;
                        end
            4'b1011:begin
                            d_tmp_num = d_num4;
                            d1_wx = 4'b0111;
                        end
            4'b0111:begin
                            d_tmp_num = d_num1;
                            d1_wx = 4'b1110;
                        end
            default: d1_wx = 4'b1110;
            endcase        
    end    
    SevenSegDecoder SSDec(d_tmp_num, d1_out);
endmodule

// 时钟分频器（用于减缓钟速）
// 用于屏幕刷新的分频
module div(
input clk,
output clk_div
);
    parameter div_num = 16;
    reg [31:0] clk_cnt;
    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1'b1;
    end
    assign clk_div = clk_cnt[div_num];
endmodule

// 用于显示时间增加的1s分频
module div2(
input clk,
output clk_div
);
    parameter div_num = 24;
    reg [31:0] clk_cnt;
    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1'b1;
    end
    assign clk_div = clk_cnt[div_num];
endmodule

// 作为主要核心模块HourClock
// 所有核心板需要实现的功能（计时等）
// 不接受外来接口，通过Main模块实现接口的连接
module HourClock(
input clk,                              // 时钟信号
input en, sel, pause, in,               // 开关的信号
input btn1, btn2, btn3, btn4, rstn,     // 按钮的信号（为了方便写always分开）
output [7:0]seg,                        // 显示数码管输出
output [3:0]dis,                        // 显示位数输出
output led                              // led输出
);
    // 将时钟分频以缓速
    // 一个用于每秒的计时，一个用于更新屏幕状态
    wire slow_clk1, sec_clk;
    div div_1(clk, slow_clk1);
    div2 div_2(clk, sec_clk);

    // 使用这种存储每一位的方式存储状态
    // 别忘了初始状态设为00：00
    reg[3:0]num1;
    reg[3:0]num2;
    reg[3:0]num3;
    reg[3:0]num4;
    initial begin
        {num4, num3, num2, num1} = {4'd0,4'd0,4'd0,4'd0} ;
    end
    
    // 这边得写always块来执行任意的操作
    
    // 备注：由于always块的不可重合性，可能得重写整个always逻辑
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        num1 <= 4'd0; num2 <= 4'd0; num3 <= 4'd0; num4 <= 4'd0;
    end else if (en) begin
        if (!pause) begin
            if (!sel) begin
                num1 <= num1 + 4'd1;
                if (num1 >= 4'd9) begin
                    num1 <= 4'd0; num2 <= num2 + 4'd1;
                    if (num2 >= 4'd5) begin
                        num2 <= 4'd0; num3 <= num3 + 4'd1;
                        if (num3 >= 4'd9) begin
                            num3 <= 4'd0; num4 <= num4 + 4'd1;
                            if (num4 >= 4'd5) begin
                                num4 <= 4'd0;
                            end
                        end
                    end
                end
            end else begin
                num1 <= num1 - 4'd1;
                if (num1 <= 4'd0) begin
                    num1 <= 4'd9; num2 <= num2 - 4'd1;
                    if (num2 <= 4'd0) begin
                        num2 <= 4'd5; num3 <= num3 - 4'd1;
                        if (num3 <= 4'd0) begin
                            num3 <= 4'd9; num4 <= num4 - 4'd1;
                            if (num4 <= 4'd0) begin
                                num4 <= 4'd5;
                            end
                        end
                    end
                end
            end
        end else begin
            if(in) begin
                if(!btn1) begin
                    if(num1 >= 4'd9) 
                        num1 <= 4'd0;
                    else
                        num1 <= num1 + 4'd1;
                end
                if(!btn2) begin
                     if(num2 >= 4'd5) 
                        num2 <= 4'd0;
                    else
                        num2 <= num2 + 4'd1;
                end
                if(!btn3) begin
                    if(num3 >= 4'd9) 
                        num3 <= 4'd0;
                    else
                        num3 <= num3 + 4'd1;
                end
                if(!btn4) begin
                    if(num4 >= 4'd5) 
                        num4 <= 4'd0;
                    else
                        num4 <= num4 + 4'd1;
                end        
            end
        end
    end
end
    
    
    
    
    
    // 这边连接数码管以实现，用en控制输出
    wire [7:0]seg0;
    wire [3:0]dis0; 
    dtsm dtsm1(.MCLK9(slow_clk1), .d_num1(num1), .d_num2(num2), .d_num3(num3), .d_num4(num4), .d1_wx(dis0), .d1_out(seg0));
    assign seg = en ? seg0 : 8'b1111_1111;
    assign dis = en ? dis0 : 4'b1111;
    assign led = en;
    
endmodule