// `define LOGENABLE
`ifdef LOGENABLE
    `define wdisplay $display
`else
    `define wdisplay(a=1,b=1,c=1,d=1,e=1,f=1) ;
`endif
