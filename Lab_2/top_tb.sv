`timescale 1ns/1ps
`include "apb_interface.sv"
`include "apb_master.sv"
`include "apb_slave.sv"

module tb_apb();
    logic clk, reset;
    apb_interface apb_if();

    initial begin
        clk = 0;
        reset = 0;
        #20 reset = 1;
        forever #5 clk = ~clk;
    end

    assign apb_if.PCLK = clk;
    assign apb_if.PRESETn = reset;

    apb_slave slave (apb_if.slave_mp);
    apb_master master (apb_if.master_mp);
    
    initial begin
        // Ждем сброса
        wait(reset === 1'b1);
        $display("Reset released, starting tests...");
        
        // Небольшая задержка после сброса
        repeat(2) @(posedge clk);

        $display("\n=====[TEST 1] Initial values after reset=====");
        master.read('h0); // max_value
        master.read('h4); // control
        master.read('h8); // current_value

        $display("\n=====[TEST 2] Basic counting operations=====");
        master.write('h0, 32'h0000000A); // max_value = 10
        master.write('h4, 32'd1); // start counting
        repeat(3) @(posedge clk);
        master.read('h8);
        repeat(3) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 3] Control operations=====");
        master.write('h4, 32'd2); // stop counting
        master.read('h8);
        master.write('h4, 32'd3); // reset current value
        master.read('h8);
        master.write('h4, 32'd0); // no operation
        master.read('h4);

        $display("\n=====[TEST 4] HIGH BIT COVERAGE - Specific bit patterns=====");
        // Тестируем конкретные непокрытые биты из отчета
        master.write('h0, 32'h00020000); // бит 17
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h00100000); // бит 20
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h00400000); // бит 22
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h01000000); // бит 24
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h20000000); // бит 29
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 5] FULL 32-BIT RANGE COVERAGE =====");
        // Тестируем все диапазоны битов
        master.write('h0, 32'h0000FFFF); // биты 0-15
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'hFFFF0000); // биты 16-31
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h12345678); // смешанный паттерн
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'hAAAAAAAA); // чередующиеся биты
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h55555555); // инверсный паттерн
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 6] BOUNDARY VALUES AND EDGE CASES =====");
        // Граничные значения
        master.write('h0, 32'h00000001); // минимальное ненулевое значение
        master.write('h4, 32'd1);
        repeat(5) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'h7FFFFFFF); // максимальное положительное
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        master.write('h0, 32'hFFFFFFFF); // все биты установлены
        master.write('h4, 32'd1);
        repeat(3) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 7] COMPLEX SEQUENCES FOR CONDITION COVERAGE =====");
        // Сложные последовательности для покрытия условий
        master.write('h0, 32'h00000005);
        master.write('h4, 32'd1); // start
        repeat(1) @(posedge clk);
        master.write('h4, 32'd2); // stop immediately
        master.read('h8);
        
        master.write('h4, 32'd1); // restart
        repeat(1) @(posedge clk);
        master.write('h4, 32'd3); // reset while counting
        master.read('h8);

        $display("\n=====[TEST 8] RAPID OPERATIONS =====");
        // Быстрые последовательные операции
        master.write('h0, 32'h00000008);
        master.write('h4, 32'd1);
        master.write('h0, 32'h00000004);
        master.write('h4, 32'd1);
        master.write('h0, 32'h00000002);
        master.write('h4, 32'd1);
        repeat(2) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 9] ERROR CONDITIONS AND INVALID OPS =====");
        // Ошибочные условия
        master.write('h8, 32'hDEADBEEF); // write to read-only
        master.write('hFFFFFFFF, 32'h12345678); // invalid address
        master.read('h10000000);
        master.write('h10, 32'h11111111);
        master.read('h14);

        $display("\n=====[TEST 10] POST-RESET BEHAVIOR =====");
        reset = 0; 
        #10; 
        reset = 1;
        repeat(2) @(posedge clk);
        master.read('h0);
        master.read('h4);
        master.read('h8);

        $display("\n=====[TEST 11] FINAL COMPREHENSIVE TEST =====");
        // Финальный всесторонний тест
        master.write('h0, 32'h00000020);
        master.write('h4, 32'd1);
        
        // Множественные чтения во время счета
        repeat(2) @(posedge clk);
        master.read('h8);
        repeat(2) @(posedge clk);
        master.read('h8);
        repeat(2) @(posedge clk);
        master.read('h8);
        
        master.write('h4, 32'd2); // stop
        master.read('h8);
        
        master.write('h4, 32'd1); // continue
        repeat(2) @(posedge clk);
        master.read('h8);
        
        // Дождаться завершения
        repeat(30) @(posedge clk);
        master.read('h8);

        $display("\n====[MAXIMUM COVERAGE TESTS COMPLETED]====\n");
        #100;
        $finish;
    end

endmodule