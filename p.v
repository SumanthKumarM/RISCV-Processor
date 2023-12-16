module RISC_Processor(clk);
input clk;
wire [4:0]q,sout,m_out;
wire [31:0]RD,ar,br,aluout,dmout,eout,M_out;
wire MemWrite,ResultScr,ALUScr,PCScr;
wire [1:0]ALUop;
wire [2:0]ALUcnt;
reg zero;
parameter p=5'd4;
parameter m_in=5'd0;
control_unit cu(MemWrite,PCScr,ResultScr,ALUScr,
ALUop,ALUcnt,zero,RD[30],RD[14:12],RD[6:0]);
Program_Counter pc(m_out,clk,rst,q);
Instruction_Memory im(RD,clk,q);
Register_File rf(ar,br,RD[19:15],RD[24:20],dmout,clk,RD[11:7]);
ALU alu(ar,M_out,aluout,ALUcnt);
Data_Memory dm(dmout,MemWrite,aluout);
add_5 add(q,p,sout);
mux_2_1 m1(m_in,sout,PCScr,m_out);
Mux_2_1 m2(br,eout,ALUScr,M_out);
Extender ext(eout,RD[31:20]);
endmodule

/* 32-Bit ALU */
module ALU(in1,in2,op,cnt);
input [31:0]in1,in2;
input [2:0]cnt;   // Control Signal
output [63:0]op;
wire [31:0]v1,v2,v3,v4,v5,v6,r1;
wire [63:0]u;
wire [1:0]r2;
parameter cin1=1'b0;
parameter cin2=1'b1;
genvar lp;

assign r1[31:3]=29'd0;

add_32 block1(in1,in2,cin1,v1,r2[0]); // Adder
add_32 block2(in1,in2,cin2,v2,r2[1]); // Subtractor
mult_32 block3(in1,in2,u); // Multiplier
div_32 block4(in2,in1,v3,v4); // v3-->Quotient v4-->Remainder
for(lp=0;lp<=31;lp=lp+1) begin
    assign v5[lp]=~(in1[lp]&in2[lp]); // Nand logic operation
    assign v6[lp]=~(in1[lp]|in2[lp]); // Nor logic operation
    assign r1[lp]=~(in1[lp]^in2[lp]); // XNOR logic operation
end
mux multiplexer(v1,v2,u,v3,v4,r1,v5,v6,cnt,op);
endmodule

/* Control Unit */
module control_unit(
    output MemWrite,PCScr,
    output ResultScr,ALUScr,
    output [1:0]ALUop,
    output [2:0]ALUcnt,
    input zero,func7_5,
    input [2:0]func3,
    input [6:0]op // operation code
);
wire branch;
assign MemWrite=(op == 7'b0100011) ? 1'b1 : 1'b0;
assign ResultScr=(op == 7'b0000011) ? 1'b1 : 1'b0;
assign ALUScr=((op == 7'b0000011) | (op == 7'b0100011)) ? 1'b1 : 1'b0;
assign branch=(op == 7'b1100011) ? 1'b1 : 1'b0;
assign ALUop=(op == 7'b0110011) ? 2'b10 : (op == 7'b1100011) ? 2'b01 : 2'b00;
assign PCScr=zero & branch;
ALUdecoder dec(ALUcnt,op[5],func7_5,func3,ALUop);
endmodule

module ALUdecoder(
    output [2:0]ALUcnt,
    input op5,
    input func7_5,
    input [2:0]func3,
    input [1:0]ALUop
);
wire [1:0]x;
assign x={op5,func7_5};
assign ALUcnt=(ALUop == 2'b00) ? 3'b000 :
              (ALUop == 2'b01) ? 3'b001 :
              ((ALUop == 2'b10) & (func3 == 3'b010)) ? 3'b101 :
              ((ALUop == 2'b10) & (func3 == 3'b110)) ? 3'b011 :
              ((ALUop == 2'b10) & (func3 == 3'b111)) ? 3'b010 :
              ((ALUop == 2'b10) & (func3 == 3'b111) & (x == 2'b11)) ? 3'b001 :
              ((ALUop == 2'b10) & (func3 == 3'b110) & (x != 2'b11)) ? 3'b000 : 3'b000;
endmodule

/* Program Counter */
module Program_Counter(
    input [4:0]pc_nxt,
    input clk,
    input clr,
    output reg [4:0]q
);
always@ (posedge clk) begin
    case (clr)
        1'b1:q=0; 
        1'b0:q<=q+pc_nxt+1;
    endcase
end
endmodule

/* Instruction Memory */
module Instruction_Memory(
    output [31:0]RD, // Read Port
    input clk,
    input [4:0]ad // Address bits
);
wire [31:0]cp;
wire [31:0]mem[31:0];
reg [31:0]Mem[31:0];
genvar i;

demux_1_32 g1(cp,clk,ad);

for(i=0;i<=31;i=i+1)
dff ffi(mem[i],cp[i],Mem[i]);

mux_32_1 g2(RD,ad,mem[0],mem[1],mem[2],mem[3],mem[4],mem[5],mem[6],mem[7],mem[8],
mem[9],mem[10],mem[11],mem[12],mem[13],mem[14],mem[15],
mem[16],mem[17],mem[18],mem[19],mem[20],mem[21],mem[22],mem[23],
mem[24],mem[25],mem[26],mem[27],mem[28],mem[29],mem[30],mem[31]);

initial begin
    Mem[0]=32'h0062E233;
    //Mem[1]=32'hFFFFF6D3;
    //Mem[2]=32'hFFFFD8D2;
    //Mem[3]=32'hFFDDC8C2;
    //Mem[4]=32'hFFFFF8D4;
    //Mem[5]=32'hFFFFF4D5;
    //Mem[6]=32'hFFCFF8D2;
    //Mem[7]=32'hFFFFFDD2;
    //Mem[8]=32'hFFABF9D2;
    //Mem[9]=32'hFFFFF8A2;
end
endmodule

/* Register File */
module Register_File(
    output [31:0]ar,br, // 2 Read ports
    input [4:0]aa,ba, // Address bits for Read ports(a,b)
    input [31:0]wd, // Write port
    input we, // Enable signal i.e clk pulse
    input [4:0]wa // Address bits for Write port
);
wire [31:0]m;
wire [31:0]n[31:0];
genvar i;

demux_1_32 g1(m,we,wa);

for(i=0;i<=31;i=i+1) begin
    dff fi(n[i],m[i],wd);
end

mux_32_1 g2(ar,aa,n[0],n[1],n[2],n[3],n[4],n[5],n[6],n[7],n[8],
n[9],n[10],n[11],n[12],n[13],n[14],n[15],
n[16],n[17],n[18],n[19],n[20],n[21],n[22],n[23],
n[24],n[25],n[26],n[27],n[28],n[29],n[30],n[31]);
mux_32_1 g3(br,ba,n[0],n[1],n[2],n[3],n[4],n[5],n[6],n[7],n[8],
n[9],n[10],n[11],n[12],n[13],n[14],n[15],
n[16],n[17],n[18],n[19],n[20],n[21],n[22],n[23],
n[24],n[25],n[26],n[27],n[28],n[29],n[30],n[31]);
endmodule

/* Data Memory */
module Data_Memory(
    output [31:0]rp,
    input RW,
    input [31:0]wp
);
parameter sel=1'b1;
genvar i;
for(i=0;i<=31;i=i+1) begin
    bc gi(rp[i],wp[i],RW,sel);
end
endmodule

/* Binary Cell */
module bc(
    output op,
    input in,RW,sel // RW--> Read/Write port, sel--> Used to select a particular Binary Cell
);
wire [1:0]a;
wire x,p;
and(a[0],sel,~in,~RW),(a[1],sel,in,~RW); // if RW=1--> BC is in Read mode else in Write mode
srff ff(x,p,a[1],a[0],sel);
and(op,sel,RW,x);
endmodule

/* SR Flip Flop (used in binary cell) */
module srff(
    output q,qb,
    input s,r,clk
);
wire [1:0]k;
nand(k[0],s,clk),(k[1],r,clk);
nand(q,k[0],qb),(qb,k[1],q);
endmodule

/* Extender */
module Extender(
    output [31:0]ImmExt,
    input [11:0]in
);
genvar i;
assign ImmExt[11:0]=in;
for(i=12;i<=31;i=i+1) begin
    assign ImmExt[i]=in[11];
end
endmodule

/* 32-Bit Adder and Subtractor */
module add_32(a,b,Cin,s,Co);
input [31:0]a,b;
input Cin; // if Cin=0--> addition. if Cin=1--> subtraction
output [31:0]s;
output Co;
wire [31:0]k;
wire [30:0]h;

genvar i,j;

for(i=0;i<=31;i=i+1) begin
    assign k[i]=b[i]^Cin;
end

fa g31(a[0],k[0],Cin,s[0],h[0]);

for(j=1;j<=30;j=j+1) begin
    fa gj(a[j],k[j],h[j-1],s[j],h[j]);
end

fa g32(a[31],k[31],h[30],s[31],Co);
endmodule

/* Full Adder */
module fa(x,y,z,l,m);
input x,y,z;
output l,m;
assign l=x^y^z;
assign m=(x&y)|(y&z)|(x&z);
endmodule

/*32-Bit Multiplier*/
module  mult_32(A,B,M);
input [31:0]A,B;
output [63:0]M; // o/p is 64-bit

wire [31:0]w[31:0];
wire [31:0]z;
wire [30:0]q;
wire [31:0]g[30:0];  // g is array of output sum bits of 32-bit adders
wire [31:0]h[29:0]; 

parameter c=0;
parameter cin=1'b0;

genvar m,n,x,y,i,j;

for(i=0;i<=31;i=i+1) begin
    for(j=0;j<=31;j=j+1) begin
        if(j<=31) begin
           assign w[i][j]=B[i]&A[j];
        end
    end
end

for(y=0;y<=30;y=y+1) begin
    assign M[y+1]=g[y][0];
    assign M[y+32]=g[30][y+1];
    assign z[y]=w[0][y+1];
end

for(m=0;m<=29;m=m+1) begin
    for(n=0;n<=30;n=n+1) begin
        if(n<=30) begin
            assign h[m][n]=g[m][n+1];
            assign h[m][31]=q[m];
        end
    end
end

add_32 block0(z[31:0],w[1],cin,g[0],q[0]);

for(x=1;x<=29;x=x+1) begin
    add_32 blockx(h[x-1],w[x+1],cin,g[x],q[x]);
end

add_32 block31(h[29],w[31],cin,g[30],q[30]); // q[30] is Cout of 31st adder

assign z[31]=c;
assign M[0]=w[0][0];
assign M[63]=q[30];
endmodule

/* 32-Bit Binary Dividor */
module div_32(d,D,Q,R);
output [31:0]Q,R;    // Q-->quotient   R-->remainder
input [31:0]d,D;    // d--> divisor   D-->dividend
wire [31:0]c[31:0];
wire [31:0]z[31:0];
parameter C=1'b1;
parameter dup=1'b0;
genvar i,j,m,n;

for(i=0;i<=31;i=i+1) begin
    pu hi(d[0],D[31-i],C,c[i][31],z[i][0],c[i][0]);
    assign R[i]=z[31][i];
    assign Q[i]=c[31-i][31];
end

for(j=1;j<=31;j=j+1) begin
    pu gj(d[j],dup,c[0][j-1],c[0][31],z[0][j],c[0][j]);
end

for(m=1;m<=31;m=m+1) begin
    for(n=1;n<=31;n=n+1) begin
        if(n<=31) begin
            pu fmn(d[m],z[n-1][m-1],c[n][m-1],c[n][31],z[n][m],c[n][m]);
        end
    end
end
endmodule

/* Processing Unit */
module pu(b,a,Cin,sel,z,Co);
output z,Co;
input a,b,sel,Cin;
wire x;
assign x=a^(~b)^Cin;
assign Co=(a&(~b))|((~b)&Cin)|(a&Cin);
assign z=(a&(~sel))|(x&sel);
endmodule

/* 64-Bus and 32-Bus input 8:1 Mux */
module mux(In1,In2,In3,In4,In5,In6,In7,In8,s1,Z1);
output [63:0]Z1;
input [31:0]In1,In2,In4,In5,In6,In7,In8;
input [63:0]In3;
input [2:0]s1;
wire [7:0]s2;
wire [31:0]X[7:0];
wire [31:0]Y[7:0];
wire [31:0]Y1;
reg [31:0]Z;
integer pj,qj;

assign X[0]=In1;
assign X[1]=In2;
assign X[2]=In3[31:0];
assign X[3]=In4;
assign X[4]=In5;
assign X[5]=In6;
assign X[6]=In7;
assign X[7]=In8;

and(s2[0],~s1[2],~s1[1],~s1[0]);
and(s2[1],~s1[2],~s1[1],s1[0]);
and(s2[2],~s1[2],s1[1],~s1[0]);
and(s2[3],~s1[2],s1[1],s1[0]);
and(s2[4],s1[2],~s1[1],~s1[0]);
and(s2[5],s1[2],~s1[1],s1[0]);
and(s2[6],s1[2],s1[1],~s1[0]);
and(s2[7],s1[2],s1[1],s1[0]);

/* Bus Expander */
for(genvar jp=0;jp<=7;jp=jp+1) begin
    for(genvar jq=0;jq<=31;jq=jq+1) begin
        assign Y1[jq]=s2[2]&In3[jq+32];
        if(jq<=31) begin
            assign Y[jp][jq]=X[jp][jq]&s2[jp];
        end
    end
end

always@ * begin
    for(pj=0;pj<=31;pj=pj+1) begin
        Z[pj]=Y[0][pj];
        for(qj=0;qj<=7;qj=qj+1) begin
            Z[pj]=Z[pj]|Y[qj][pj];
        end
    end
end
assign Z1={Y1,Z};
endmodule

/* Demux for clk selection */
module demux_1_32(
    output [31:0]C,
    input en, // Rising edge clk pulse
    input [4:0]w_a // selection line is used as Write data address
);
and(C[0],en,~w_a[4],~w_a[3],~w_a[2],~w_a[1],~w_a[0]);
and(C[1],en,~w_a[4],~w_a[3],~w_a[2],~w_a[1],w_a[0]);
and(C[2],en,~w_a[4],~w_a[3],~w_a[2],w_a[1],~w_a[0]);
and(C[3],en,~w_a[4],~w_a[3],~w_a[2],w_a[1],w_a[0]);
and(C[4],en,~w_a[4],~w_a[3],w_a[2],~w_a[1],~w_a[0]);
and(C[5],en,~w_a[4],~w_a[3],w_a[2],~w_a[1],w_a[0]);
and(C[6],en,~w_a[4],~w_a[3],w_a[2],w_a[1],~w_a[0]);
and(C[7],en,~w_a[4],~w_a[3],w_a[2],w_a[1],w_a[0]);
and(C[8],en,~w_a[4],w_a[3],~w_a[2],~w_a[1],~w_a[0]);
and(C[9],en,~w_a[4],w_a[3],~w_a[2],~w_a[1],w_a[0]);
and(C[10],en,~w_a[4],w_a[3],~w_a[2],w_a[1],~w_a[0]);
and(C[11],en,~w_a[4],w_a[3],~w_a[2],w_a[1],w_a[0]);
and(C[12],en,~w_a[4],w_a[3],w_a[2],~w_a[1],~w_a[0]);
and(C[13],en,~w_a[4],w_a[3],w_a[2],~w_a[1],w_a[0]);
and(C[14],en,~w_a[4],w_a[3],w_a[2],w_a[1],~w_a[0]);
and(C[15],en,~w_a[4],w_a[3],w_a[2],w_a[1],w_a[0]);
and(C[16],en,w_a[4],~w_a[3],~w_a[2],~w_a[1],~w_a[0]);
and(C[17],en,w_a[4],~w_a[3],~w_a[2],~w_a[1],w_a[0]);
and(C[18],en,w_a[4],~w_a[3],~w_a[2],w_a[1],~w_a[0]);
and(C[19],en,w_a[4],~w_a[3],~w_a[2],w_a[1],w_a[0]);
and(C[20],en,w_a[4],~w_a[3],w_a[2],~w_a[1],~w_a[0]);
and(C[21],en,w_a[4],~w_a[3],w_a[2],~w_a[1],w_a[0]);
and(C[22],en,w_a[4],~w_a[3],w_a[2],w_a[1],~w_a[0]);
and(C[23],en,w_a[4],~w_a[3],w_a[2],w_a[1],w_a[0]);
and(C[24],en,w_a[4],w_a[3],~w_a[2],~w_a[1],~w_a[0]);
and(C[25],en,w_a[4],w_a[3],~w_a[2],~w_a[1],w_a[0]);
and(C[26],en,w_a[4],w_a[3],~w_a[2],w_a[1],~w_a[0]);
and(C[27],en,w_a[4],w_a[3],~w_a[2],w_a[1],w_a[0]);
and(C[28],en,w_a[4],w_a[3],w_a[2],~w_a[1],~w_a[0]);
and(C[29],en,w_a[4],w_a[3],w_a[2],~w_a[1],w_a[0]);
and(C[30],en,w_a[4],w_a[3],w_a[2],w_a[1],~w_a[0]);
and(C[31],en,w_a[4],w_a[3],w_a[2],w_a[1],w_a[0]);
endmodule

/* 32-bit bus 32:1 Mux */
module mux_32_1(
    output reg [31:0]o,
    input [4:0]sel,
    input [31:0]In1,In2,In3,In4,In5,In6,In7,In8,
    input [31:0]In9,In10,In11,In12,In13,In14,In15,In16,
    input [31:0]In17,In18,In19,In20,In21,In22,In23,In24,
    input [31:0]In25,In26,In27,In28,In29,In30,In31,In32
);
wire [31:0]sl;
wire [31:0]In[31:0];
wire [31:0]op[31:0];
genvar i,j;
integer ij,ji;

assign In[0]=In1;
assign In[1]=In2;
assign In[2]=In3;
assign In[3]=In4;
assign In[4]=In5;
assign In[5]=In6;
assign In[6]=In7;
assign In[7]=In8;
assign In[8]=In9;
assign In[9]=In10;
assign In[10]=In11;
assign In[11]=In12;
assign In[12]=In13;
assign In[13]=In14;
assign In[14]=In15;
assign In[15]=In16;
assign In[16]=In17;
assign In[17]=In18;
assign In[18]=In19;
assign In[19]=In20;
assign In[20]=In21;
assign In[21]=In22;
assign In[22]=In23;
assign In[23]=In24;
assign In[24]=In25;
assign In[25]=In26;
assign In[26]=In27;
assign In[27]=In28;
assign In[28]=In29;
assign In[29]=In30;
assign In[30]=In31;
assign In[31]=In32;

/* Bus expander */
and(sl[0],~sel[4],~sel[3],~sel[2],~sel[1],~sel[0]);
and(sl[1],~sel[4],~sel[3],~sel[2],~sel[1],sel[0]);
and(sl[2],~sel[4],~sel[3],~sel[2],sel[1],~sel[0]);
and(sl[3],~sel[4],~sel[3],~sel[2],sel[1],sel[0]);
and(sl[4],~sel[4],~sel[3],sel[2],~sel[1],~sel[0]);
and(sl[5],~sel[4],~sel[3],sel[2],~sel[1],sel[0]);
and(sl[6],~sel[4],~sel[3],sel[2],sel[1],~sel[0]);
and(sl[7],~sel[4],~sel[3],sel[2],sel[1],sel[0]);
and(sl[8],~sel[4],sel[3],~sel[2],~sel[1],~sel[0]);
and(sl[9],~sel[4],sel[3],~sel[2],~sel[1],sel[0]);
and(sl[10],~sel[4],sel[3],~sel[2],sel[1],~sel[0]);
and(sl[11],~sel[4],sel[3],~sel[2],sel[1],sel[0]);
and(sl[12],~sel[4],sel[3],sel[2],~sel[1],~sel[0]);
and(sl[13],~sel[4],sel[3],sel[2],~sel[1],sel[0]);
and(sl[14],~sel[4],sel[3],sel[2],sel[1],~sel[0]);
and(sl[15],~sel[4],sel[3],sel[2],sel[1],sel[0]);
and(sl[16],sel[4],~sel[3],~sel[2],~sel[1],~sel[0]);
and(sl[17],sel[4],~sel[3],~sel[2],~sel[1],sel[0]);
and(sl[18],sel[4],~sel[3],~sel[2],sel[1],~sel[0]);
and(sl[19],sel[4],~sel[3],~sel[2],sel[1],sel[0]);
and(sl[20],sel[4],~sel[3],sel[2],~sel[1],~sel[0]);
and(sl[21],sel[4],~sel[3],sel[2],~sel[1],sel[0]);
and(sl[22],sel[4],~sel[3],sel[2],sel[1],~sel[0]);
and(sl[23],sel[4],~sel[3],sel[2],sel[1],sel[0]);
and(sl[24],sel[4],sel[3],~sel[2],~sel[1],~sel[0]);
and(sl[25],sel[4],sel[3],~sel[2],~sel[1],sel[0]);
and(sl[26],sel[4],sel[3],~sel[2],sel[1],~sel[0]);
and(sl[27],sel[4],sel[3],~sel[2],sel[1],sel[0]);
and(sl[28],sel[4],sel[3],sel[2],~sel[1],~sel[0]);
and(sl[29],sel[4],sel[3],sel[2],~sel[1],sel[0]);
and(sl[30],sel[4],sel[3],sel[2],sel[1],~sel[0]);
and(sl[31],sel[4],sel[3],sel[2],sel[1],sel[0]);
for(i=0;i<=31;i=i+1) begin
    for(j=0;j<=31;j=j+1) begin
        if(j<=31) begin
            assign op[i][j]=sl[i]&In[i][j];
        end
    end
end 

always@ * begin
    for(ij=0;ij<=31;ij=ij+1) begin
        o[ij]=op[0][ij];
        for(ji=0;ji<=31;ji=ji+1) begin
            o[ij]=o[ij]|op[ji][ij];
        end
    end
end
endmodule

/* 32-Bus D Flip Flop*/
module dff(
    output reg [31:0]q,
    input c,
    input [31:0]d
);
wire [31:0]qb;
always@(posedge c) begin
    q=d; 
end
assign qb=~q;
endmodule

/* 5-Bit Adder */
module add_5(a,b,s);
input [4:0]a,b;
output [4:0]s;
wire [4:0]k;
wire [3:0]h;
wire Co;
parameter Cin=1'b0;
genvar i,j;

for(i=0;i<=4;i=i+1) begin
    assign k[i]=b[i]^Cin;
end

fa g31(a[0],k[0],Cin,s[0],h[0]);

for(j=1;j<=3;j=j+1) begin
    fa gj(a[j],k[j],h[j-1],s[j],h[j]);
end

fa g32(a[4],k[4],h[3],s[4],Co);
endmodule

/* 5-Bit Bus 2:1 Mux */
module mux_2_1(
    input [4:0]a,b,
    input sel,
    output reg [4:0]c
);
always@ * begin
    case (sel)
        1'b0:c=a; 
        1'b1:c=b;
    endcase
end
endmodule

/* 32-bit Bus 2:1 Mux */
module Mux_2_1(
    input [31:0]a,b,
    input sel,
    output reg [31:0]c
);
always@ * begin
    case (sel)
        1'b0:c=a; 
        1'b1:c=b;
    endcase
end
endmodule
