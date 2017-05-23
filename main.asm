*=$4000
incbin "grtest.l.o",2 ;has 2 byte load address
*=$c000
incbin "grlib.r.o",2 ;has 2 byte load address
