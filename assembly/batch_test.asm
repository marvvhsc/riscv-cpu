.text
.globl main

main:
loop:
    li gp, 0x4000
    lw t0, 0(gp)      
    lw t1, 4(gp)      
    lw t2, 8(gp)      
    beq t0, zero, case0
    li t3, 1
    beq t0, t3, case1
    li t3, 2
    beq t0, t3, case2
    li t3, 3
    beq t0, t3, case3
    li t3, 4
    beq t0, t3, case4
    li t3, 5
    beq t0, t3, case5
    li t3, 6
    beq t0, t3, case6
    li t3, 7
    beq t0, t3, case7
    li t3, 8
    beq t0, t3, case8
    li t3, 9
    beq t0, t3, case9
    li t3, 10
    beq t0, t3, case10
    li t3, 11
    beq t0, t3, case11
    li t3, 12
    beq t0, t3, case12
    
    li   t3, 15
    beq  t0, t3, pipelinecase15
    li   t3, 16
    beq  t0, t3, pipelinecase16
    li   t3, 17
    beq  t0, t3, pipelinecase17
    li   t3, 18
    beq  t0, t3, pipelinecase18
    li t3, 19
    beq t0, t3, pipelinecase19
    j loop   
case0:
    and t4, t1, t2
    j write
case1:
    sll t4, t1, t2
    j write
case2:
    sra t4, t1, t2
    j write
case3:
    lui t5, 0x12345
    add t4, t1, t5
    j write
case4:
    jal t5, target4      # t5 = return address
target4:
    auipc t6, 0x12345
    sub t4, t6, t5
    add t4, t4, t1
    j write
case5:
    jal ra, func5
    add t4, t1, t2
    j write
func5:
    jr ra
case6:
    mv t0, t1         # n
    li t1, 0          # f(0)
    li t2, 1          # f(1)
    beq t0, zero, fib0
    li t3, 1
    beq t0, t3, fib1
    li t3, 2          # i = 2
fib_loop:
    add t4, t1, t2
    mv t1, t2
    mv t2, t4
    addi t3, t3, 1
    ble t3, t0, fib_loop
    j write
fib0:
    li t4, 0
    j write
fib1:
    li t4, 1
    j write
 
case7:
    li  t4, 0       
    andi t1, t1, 0xFF  
popcount_loop:
    beq t1, zero, write
    andi t3, t1, 1
    add  t4, t4, t3
    srli t1, t1, 1
    j popcount_loop
case8:
    mv t0, t1
    srli t1, t0, 10
    andi t1, t1, 0x1F
   
    andi t2, t0, 0x3FF
    li t3, 31
    beq t1, t3, exponent_fullones
    beq t1, zero, exponent_zero
    li t4, 3
    j write
exponent_zero:
    beq t2, zero, zero_case
    li t4, 4
    j write
zero_case:
    li t4, 0
    j write
exponent_fullones:
    beq t2, zero, inf_case
    li t4, 2
    j write
inf_case:
    li t4, 1
    j write
case9:
    mv t0, t1
    #sign b
    srli t1, t0, 15
    andi t1, t1, 1
    # exp
    srli t2, t0, 10
    andi t2, t2, 0x1F
    # mantissa
    andi t3, t0, 0x3FF
    # exp=0
    beq t2, zero, subnormal
    # normalize
    li t4, 1024
    add t3, t3, t4
    addi t2, t2, -21
    j convert
subnormal:
    li t2, -20
convert:
    blt t2, zero, shift_right
shift_left:
    sll t5, t3, t2
    j apply_sign
shift_right:
    sub t6, zero, t2
    srl t5, t3, t6
apply_sign:
    beq t1, zero, print_ans
    sub t5, zero, t5
print_ans:
    andi t4, t5, 0xFF   
    j write
case10: 
    mv a0, t1              
    li a7, 1               
    sw a0, 16(gp)          
    ecall                  
    li t4, 0xEC            
    sw t4, 20(gp)          
    j write                
case11: 
    # lower 16 of t1 jdi upper 16 of result
    slli t4, t1, 16    
    slli t3, t2, 16    
    srli t3, t3, 16    
    
    or t4, t4, t3       # nge combine
    j write

case12: 
    blt t1, t2, use_t2
    mv t4, t1
    j write
use_t2:
    mv t4, t2
    j write
pipelinecase15:
    addi t4, t1, 1       
    addi t4, t4, 2       
    addi t4, t4, 3       
    j    write
pipelinecase16:
    sw   t1, 28(gp)      
    lw   t4, 28(gp)      
    add  t4, t4, t2      
    j    write
pipelinecase17:
    bltu t2, t1, c22_a_bigger   
    sub  t4, t2, t1              
    j    write             
c22_a_bigger:
    sub  t4, t1, t2              
    j   write
 

pipelinecase18:
    add  t4, t1, t2      
    sub  t4, t4, t1      
    add  t4, t4, t2      
    j    write
pipelinecase19:
    add  t4, t1, t2      
    addi t5, t4, 1       
    add  t4, t5, t4      
    j    write
write:
    sw t4, 12(gp)     
    j loop
