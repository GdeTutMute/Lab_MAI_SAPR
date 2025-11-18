module apb_slave(apb_interface apb_if);

    logic [31:0] max_value_reg;    // Максимальное значение
    logic [1:0]  control_reg;      // Контрольный регистр
    logic [31:0] current_value_reg; // Текущее значение счетчика
    logic counting;                // Флаг активности счетчика
    
    logic trans_done;
    logic ready_set;

    // Логика обратного счетчика
    always_ff @(posedge apb_if.PCLK or negedge apb_if.PRESETn) begin
        if (!apb_if.PRESETn) begin
            current_value_reg <= 32'b0;
            counting <= 1'b0;
        end else if (counting && current_value_reg > 0) begin
            current_value_reg <= current_value_reg - 1;
            // Автоматическая остановка при достижении 0
            if (current_value_reg == 1) begin
                counting <= 1'b0;
                $display("[APB_SLAVE] Counter reached zero, auto-stopped");
            end
        end
    end

    // APB логика
    always_ff @(posedge apb_if.PCLK or negedge apb_if.PRESETn) begin
        if (!apb_if.PRESETn) begin
            apb_if.PREADY  <= 1'b0;
            apb_if.PSLVERR <= 1'b0;
            max_value_reg  <= 32'b0;
            control_reg    <= 2'b0;
            current_value_reg <= 32'b0;
            counting       <= 1'b0;
            apb_if.PRDATA  <= 32'b0;
            trans_done     <= 1'b0;
            ready_set      <= 1'b0;
        end else begin
            // Сброс сигналов ошибки и готовности только когда транзакция завершена
            if (apb_if.PREADY && apb_if.PSEL && apb_if.PENABLE) begin
                apb_if.PREADY <= 1'b0;
                apb_if.PSLVERR <= 1'b0;
                ready_set <= 1'b0;
            end

            // WRITE операция
            if (apb_if.PSEL && apb_if.PENABLE && apb_if.PWRITE && !ready_set) begin
                case (apb_if.PADDR)
                    32'h0: begin // Запись максимального значения
                        max_value_reg <= apb_if.PWDATA;
                        $display("[APB_SLAVE] Write max_value: %0d (0x%08h)", apb_if.PWDATA, apb_if.PWDATA);
                        apb_if.PREADY <= 1'b1;
                        ready_set <= 1'b1;
                    end
                    32'h4: begin // Запись контрольного регистра
                        control_reg <= apb_if.PWDATA[1:0];
                        $display("[APB_SLAVE] Write control: 0x%0h", apb_if.PWDATA[1:0]);
                        
                        // Выполнение операции на основе control_reg
                        case (apb_if.PWDATA[1:0])
                            2'b01: begin // Запуск обратного счета
                                current_value_reg <= max_value_reg;
                                counting <= 1'b1;
                                $display("[APB_SLAVE] Start counting down from: %0d", max_value_reg);
                            end
                            2'b10: begin // Остановка счета
                                counting <= 1'b0;
                                $display("[APB_SLAVE] Counter stopped at: %0d", current_value_reg);
                            end
                            2'b11: begin // Сброс текущего значения
                                current_value_reg <= 32'b0;
                                counting <= 1'b0;
                                $display("[APB_SLAVE] Current value reset to 0");
                            end
                            default: begin // 2'b00 - ничего не делать
                                $display("[APB_SLAVE] No operation");
                            end
                        endcase
                        apb_if.PREADY <= 1'b1;
                        ready_set <= 1'b1;
                    end
                    32'h8: begin // Ошибка: попытка записи в регистр текущего значения (только для чтения)
                        $display("[APB_SLAVE] ERROR: WRITE to read-only current_value register (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PREADY  <= 1'b1;
                        ready_set <= 1'b1;
                    end 
                    default: begin // Неверный адрес
                        $display("[APB_SLAVE] ERROR: addr isn't in range (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PREADY  <= 1'b1;
                        ready_set <= 1'b1;
                    end
                endcase
                trans_done <= 1'b1;
            end 
            // READ операция
            else if (apb_if.PSEL && apb_if.PENABLE && !apb_if.PWRITE && !ready_set) begin
                case (apb_if.PADDR)
                    32'h0: begin // Чтение максимального значения
                        apb_if.PRDATA <= max_value_reg;
                        $display("[APB_SLAVE] Read max_value: %0d (0x%08h)", max_value_reg, max_value_reg);
                    end
                    32'h4: begin // Чтение контрольного регистра
                        apb_if.PRDATA <= {30'd0, control_reg};
                        $display("[APB_SLAVE] Read control: 0x%0h", control_reg);
                    end
                    32'h8: begin // Чтение текущего значения счетчика
                        apb_if.PRDATA <= current_value_reg;
                        $display("[APB_SLAVE] Read current_value: %0d (0x%08h)", current_value_reg, current_value_reg);
                    end
                    default: begin // Неверный адрес
                        $display("[APB_SLAVE] ERROR: addr isn't in range (0x%08h)", apb_if.PADDR);
                        apb_if.PSLVERR <= 1'b1;
                        apb_if.PRDATA  <= 32'hDEAD_BEEF;
                    end
                endcase
                apb_if.PREADY <= 1'b1;
                ready_set <= 1'b1;
                trans_done <= 1'b1;
            end

        end // else not reset
    end // always_ff

endmodule