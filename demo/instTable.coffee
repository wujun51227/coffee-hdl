  ###
  imm[31:12] rd 0110111 U lui
  imm[31:12] rd 0010111 U auipc
  imm[20|10:1|11|19:12] rd 1101111 J jal
  imm[11:0] rs1 000 rd 1100111 I jalr
  imm[12|10:5] rs2 rs1 000 imm[4:1|11] 1100011 B beq
  imm[12|10:5] rs2 rs1 001 imm[4:1|11] 1100011 B bne
  imm[12|10:5] rs2 rs1 100 imm[4:1|11] 1100011 B blt
  imm[12|10:5] rs2 rs1 101 imm[4:1|11] 1100011 B bge
  imm[12|10:5] rs2 rs1 110 imm[4:1|11] 1100011 B bltu
  imm[12|10:5] rs2 rs1 111 imm[4:1|11] 1100011 B bgeu
  imm[11:0] rs1 000 rd 0000011 I lb
  imm[11:0] rs1 001 rd 0000011 I lh
  imm[11:0] rs1 010 rd 0000011 I lw
  imm[11:0] rs1 100 rd 0000011 I lbu
  imm[11:0] rs1 101 rd 0000011 I lhu
  imm[11:5] rs2 rs1 000 imm[4:0] 0100011 S sb
  imm[11:5] rs2 rs1 001 imm[4:0] 0100011 S sh
  imm[11:5] rs2 rs1 010 imm[4:0] 0100011 S sw
  imm[11:0] rs1 000 rd 0010011 I addi
  imm[11:0] rs1 010 rd 0010011 I slti
  imm[11:0] rs1 011 rd 0010011 I sltiu
  imm[11:0] rs1 100 rd 0010011 I xori
  imm[11:0] rs1 110 rd 0010011 I ori
  imm[11:0] rs1 111 rd 0010011 I andi
  0000000 shamt rs1 001 rd 0010011 I slli
  0000000 shamt rs1 101 rd 0010011 I srli
  0100000 shamt rs1 101 rd 0010011 I srai
  0000000 rs2 rs1 000 rd 0110011 R add
  0100000 rs2 rs1 000 rd 0110011 R sub
  0000000 rs2 rs1 001 rd 0110011 R sll
  0000000 rs2 rs1 010 rd 0110011 R slt
  0000000 rs2 rs1 011 rd 0110011 R sltu
  0000000 rs2 rs1 100 rd 0110011 R xor
  0000000 rs2 rs1 101 rd 0110011 R srl
  0100000 rs2 rs1 101 rd 0110011 R sra
  0000000 rs2 rs1 110 rd 0110011 R or
  0000000 rs2 rs1 111 rd 0110011 R and
  0000 pred succ 00000 000 00000 0001111 I fence
  0000 0000 0000 00000 001 00000 0001111 I fence.i
  000000000000 00000 000 00000 1110011 I ecall
  000000000001 00000 000 00000 1110011 I ebreak
  csr rs1 001 rd 1110011 I csrrw
  csr rs1 010 rd 1110011 I csrrs
  csr rs1 011 rd 1110011 I csrrc
  csr zimm 101 rd 1110011 I csrrwi
  csr zimm 110 rd 1110011 I csrrsi
  csr zimm 111 rd 1110011 I csrrci
  ###

rFormat=[
  {name:'add', funct3:0b000,funct7:0b0000000}
  {name:'sub', funct3:0b000,funct7:0b1000000}
  {name:'sll', funct3:0b001,funct7:0b0000000}
  {name:'slt', funct3:0b010,funct7:0b0000000}
  {name:'sltu',funct3:0b011,funct7:0b0000000}
  {name:'xor', funct3:0b100,funct7:0b0000000}
  {name:'srl', funct3:0b101,funct7:0b0000000}
  {name:'sra', funct3:0b101,funct7:0b0100000}
  {name:'or',  funct3:0b110,funct7:0b0000000}
  {name:'and', funct3:0b111,funct7:0b0000000}
  ]
  
iFormat_4=[
  {name:'fence',  funct3:0b000}
  {name:'fence_i',funct3:0b001}
  ]
  
iFormat_5=[
  {name:'ecall', funct3:0b000,immI:0b0}
  {name:'ebreak',funct3:0b000,immI:0b1}
  {name:'csrrw', funct3:0b001}
  {name:'csrrs', funct3:0b010}
  {name:'csrrc', funct3:0b011}
  {name:'csrrwi',funct3:0b101}
  {name:'csrrsi',funct3:0b110}
  {name:'csrrci',funct3:0b111}
  ]
  
iFormat_2=[
  {name:'lb'   ,funct3:0b000}
  {name:'lh'   ,funct3:0b001}
  {name:'lw'   ,funct3:0b010}
  {name:'lbu'  ,funct3:0b100}
  {name:'lhu'  ,funct3:0b101}
  ]
  
iFormat_3=[
  {name:  'addi'  ,funct3:0b000}
  {name:  'slti'  ,funct3:0b010}
  {name:  'sltiu' ,funct3:0b011}
  {name:  'xori'  ,funct3:0b100}
  {name:  'ori'   ,funct3:0b110}
  {name:  'andi'  ,funct3:0b111}
  {name: 'slli',   funct3:0b001,funct7:0b0}
  {name: 'srli',   funct3:0b101,funct7:0b0}
  {name: 'srai',   funct3:0b101,funct7:0b0100000}
  ]
  
iFormat_1=[
  {name:'jalr',funct3:0b000}
  ]
  
bFormat=[
  {name:'beq', funct3:0b000}
  {name:'bne', funct3:0b001}
  {name:'blt', funct3:0b100}
  {name:'bge', funct3:0b101}
  {name:'bltu',funct3:0b110}
  {name:'bgeu',funct3:0b111}
  ]
  
sFormat=[
  {name:'sb',funct3:0b000}
  {name:'sh',funct3:0b001}
  {name:'sw',funct3:0b010}
  ]

uFormat_1=[
  {name:'lui'}
  {name:'auipc'}
]
  
allFormat=[
  ['utype',0b0110111,[{name:'lui'}]]
  ['utype',0b0010111,[{name:'auipc'}]]
  ['jtype',0b1101111,[{name:'jal'}]]
  ['itype',0b1100111,iFormat_1]
  ['btype',0b1100011,bFormat]
  ['itype',0b0000011,iFormat_2]
  ['stype',0b0100011,sFormat]
  ['itype',0b0010011,iFormat_3]
  ['rtype',0b0110011,rFormat]
  ['itype',0b0001111,iFormat_4]
  ['itype',0b1110011,iFormat_5]
  ]
  
allInst = []
for item in allFormat
  allInst.push(i.name) for i in item[2]

module.exports.table=allFormat
module.exports.instList=allInst
module.exports.checkList=['funct3','funct7','immI']
module.exports.fieldProperty={
  funct3: {
    width: 3
    lsb: 12
  }
  funct7: {
    width: 7
    lsb: 25
  }
  immI: {
    width: 12
    lsb: 20
  }
  opcode: {
    width: 7
    lsb: 0
  }
  rs1Index: {
    width: 5
    lsb: 15
  }
  rs2Index: {
    width: 5
    lsb: 20
  }
}

