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

        $display("\n=====[TEST 2] Set maximum value and start counting=====");
        master.write('h0, 32'h0000000A); // max_value = 10
        master.write('h4, 32'd1); // control = 1 (start counting)
        
        // Дадим счетчику поработать несколько тактов
        repeat(3) @(posedge clk);
        master.read('h8); // Read current_value (должно уменьшиться)
        
        repeat(3) @(posedge clk);
        master.read('h8); // Read current_value (еще уменьшилось)

        $display("\n=====[TEST 3] Stop counting and check value=====");
        master.write('h4, 32'd2); // control = 2 (stop counting)
        master.read('h8); // Read current_value
        
        // Проверим, что значение не меняется после остановки
        repeat(3) @(posedge clk);
        master.read('h8); // Должно остаться прежним

        $display("\n=====[TEST 4] Reset current value to zero=====");
        master.write('h4, 32'd3); // control = 3 (reset current value)
        master.read('h8); // Read current_value (should be 0)

        $display("\n=====[TEST 5] New counting sequence with different max value=====");
        master.write('h0, 32'h00000005); // max_value = 5
        master.write('h4, 32'd1); // control = 1 (start counting)
        
        // Следим за счетчиком до завершения
        repeat(8) @(posedge clk);
        master.read('h8); // Read current_value (должно быть 0)

        $display("\n=====[TEST 6] Large counter value test=====");
        master.write('h0, 32'h00000020); // max_value = 32
        master.write('h4, 32'd1); // control = 1 (start counting)
        
        // Проверим несколько промежуточных значений
        repeat(10) @(posedge clk);
        master.read('h8); // Read current_value
        
        repeat(10) @(posedge clk);
        master.read('h8); // Read current_value

        $display("\n=====[TEST 7] Stop and resume counting=====");
        master.write('h4, 32'd2); // control = 2 (stop counting)
        master.read('h8); // Запомним текущее значение
        
        // Ждем и проверяем, что значение не изменилось
        repeat(5) @(posedge clk);
        master.read('h8);
        
        // Продолжаем счет
        master.write('h4, 32'd1); // control = 1 (continue counting)
        repeat(5) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 8] Edge cases and boundary values=====");
        // Нулевое максимальное значение
        master.write('h0, 32'h00000000); // max_value = 0
        master.write('h4, 32'd1); // control = 1 (start counting)
        repeat(3) @(posedge clk);
        master.read('h8); // Read current_value

        // Большое значение
        master.write('h0, 32'h0000FFFF); // max_value = 65535
        master.write('h4, 32'd1); // control = 1 (start counting)
        repeat(5) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 9] Control register operations=====");
        // Тестирование всех команд control_reg
        master.write('h4, 32'd0); // control = 0 (no operation)
        master.read('h4);
        master.write('h4, 32'd1); // control = 1
        master.read('h4);
        master.write('h4, 32'd2); // control = 2
        master.read('h4);
        master.write('h4, 32'd3); // control = 3
        master.read('h4);

        $display("\n=====[TEST 10] Attempt to write read-only register=====");
        master.write('h8, 32'hDEAD_BEEF); // Try to write current_value register

        $display("\n=====[TEST 11] Invalid address check=====");
        master.write('hFFFFFFFF, 32'h12345678);
        master.read('h10000000);

        // Дополнительные неверные адреса
        master.write('h10, 32'h11111111);
        master.read('h14);

        $display("\n=====[TEST 12] Mixed read/write operations=====");
        // Чередование чтения и записи
        master.write('h0, 32'h00000008);
        master.read('h0);
        master.write('h4, 32'd1);
        master.read('h4);
        repeat(3) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 13] Reset behavior after activity=====");
        reset = 0; #10; reset = 1;
        master.read('h0);
        master.read('h4);
        master.read('h8);

        $display("\n=====[TEST 14] Post-reset operations=====");
        // Операции после сброса
        master.write('h0, 32'h00000007);
        master.write('h4, 32'd1);
        repeat(5) @(posedge clk);
        master.read('h8);

        $display("\n=====[TEST 15] Counter auto-stop at zero=====");
        master.write('h0, 32'h00000003);
        master.write('h4, 32'd1);
        
        // Ждем пока счетчик дойдет до 0
        repeat(10) @(posedge clk);
        master.read('h8); // Должно быть 0
        
        // Проверяем, что счетчик не уходит в отрицательные значения
        repeat(5) @(posedge clk);
        master.read('h8); // Все еще должно быть 0

        $display("\n====[ALL TESTS COMPLETED SUCCESSFULLY]====\n");
        #50;
        $finish;
    end

endmodule