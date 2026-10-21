`timescale 1ns / 1ps

// 1. وحدة العقدة الفردية (Node) مع دعم قنوات العبور والتحول الوظيفي
module Morphing_Node (
    input wire clk,
    input wire reset,
    input wire [7:0] inst_bus,
    input wire is_target,
    
    // قنوات العبور للإشارات من العقد المجاورة (Bypass Channels)
    input wire in_west, in_east, in_north, in_south,
    output reg out_west, out_east, out_north, out_south,
    
    output reg [1:0] node_role // 00: IDLE, 01: RAM, 10: GPU, 11: CPU
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            node_role <= 2'b00; // IDLE
            out_west  <= 1'b0;
            out_east  <= 1'b0;
            out_north <= 1'b0;
            out_south <= 1'b0;
        end else begin
            // إعادة التشكيل عند استهداف هذه العقدة تحديداً
            if (is_target) begin
                case (inst_bus)
                    8'b10110001: node_role <= 2'b11; // CPU
                    8'b10110000: node_role <= 2'b01; // RAM
                    8'b10110010: node_role <= 2'b10; // GPU
                    8'b11111111: node_role <= 2'b00; // RELEASE / IDLE
                    default:     node_role <= node_role;
                endcase
            end

            // منطق قنوات العبور (Bypass Routing)
            // عند انشغال الخلية بوظيفة (RAM/GPU/CPU)، تمر الإشارات عبر القنوات المحيطة
            out_east  <= in_west;  // تمرير التيار أفقياً من الغرب للشرق
            out_west  <= in_east;
            out_south <= in_north; // تمرير التيار رأسياً من الشمال للجنوب
            out_north <= in_south;
        end
    end

endmodule


// 2. وحدة الاختبار (Testbench) لمحاكاة سلوك العقدة وقنوات العبور
module tb_Morphing_Node();

    // إشارات التحكم والمداخل
    reg clk;
    reg reset;
    reg [7:0] inst_bus;
    reg is_target;
    reg in_west, in_east, in_north, in_south;

    // المخارج
    wire out_west, out_east, out_north, out_south;
    wire [1:0] node_role;

    // ربط وحدة العقدة (Instantiation)
    Morphing_Node uut (
        .clk(clk),
        .reset(reset),
        .inst_bus(inst_bus),
        .is_target(is_target),
        .in_west(in_west),
        .in_east(in_east),
        .in_north(in_north),
        .in_south(in_south),
        .out_west(out_west),
        .out_east(out_east),
        .out_north(out_north),
        .out_south(out_south),
        .node_role(node_role)
    );

    // توليد نبضات الساعة (Clock Generator: فترة النبضة 10 نانو ثانية)
    always #5 clk = ~clk;

    initial begin
        // التهيئة الأولية
        clk = 0;
        reset = 1;
        inst_bus = 8'b00000000;
        is_target = 0;
        in_west = 0; in_east = 0; in_north = 0; in_south = 0;

        // إيقاف التصفير بعد 20 نانو ثانية
        #20;
        reset = 0;

        // 1. اختبار تمرير التيار عبر قنوات العبور (Bypass) بدون استهداف العقدة
        #10;
        in_west = 1'b1;  // إرسال إشارة من الغرب
        in_north = 1'b1; // إرسال إشارة من الشمال
        #10; // ننتظر نبضة ساعية لنرى انتقالها للمخارج (out_east و out_south)

        // 2. اختبار تحويل العقدة بالكامل إلى RAM
        #10;
        is_target = 1;               // تحديد هذه العقدة هدفاً
        inst_bus = 8'b10110000;      // أمر التحويل إلى RAM
        #10;
        is_target = 0;               // إلغاء الاستهداف مع بقاء الخلية محجوزة كـ RAM

        // 3. اختبار بقاء قنوات العبور تعمل حتى والخلية مشغولة كـ RAM
        #10;
        in_east = 1'b1; // إرسال إشارة عكسية من الشرق

        // 4. اختبار تحويل العقدة إلى GPU
        #20;
        is_target = 1;
        inst_bus = 8'b10110010;      // أمر التحويل إلى GPU
        #10;
        is_target = 0;

        // 5. اختبار تحرير العقدة وإعادتها للخمول (Garbage Collection / Release)
        #20;
        is_target = 1;
        inst_bus = 8'b11111111;      // أمر التحرير (RELEASE)
        #10;
        is_target = 0;

        // إنهاء المحاكاة
        #30;
        $finish;
    end

    // مراقبة المتغيرات وطباعتها في سجل المحاكاة (Console)
    initial begin
        $monitor("Time=%0t ns | Reset=%b | Target=%b | Inst=%b | Role=%b | Out_East=%b | Out_South=%b", 
                 $time, reset, is_target, inst_bus, node_role, out_east, out_south);
    end

endmodule
